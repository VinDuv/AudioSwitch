// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import Foundation

/// Client delegate, notified when the connection status changes
protocol HelperCommandClientDelegate: AnyObject {
    /// The connection status changed
    func statusChanged(to newStatus: HelperCommandClient.ServerStatus)
}

/// Client sending commands to the server process and watching it
final class HelperCommandClient {
    private static var networkQueue = DispatchQueue(label: "net.duvert.AudioSwitch.networkClientQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .inherit, target: nil)
    private var clientSockFd: Int32 = -1
    private var clientSource: DispatchSourceRead?
    private let fsChangeSource: DispatchSourceFileSystemObject
    private let retryTimerSource: DispatchSourceTimer
    private var commandExecuted = false
    
    var delegate: HelperCommandClientDelegate?
    private var delegateQueue: DispatchQueue
    
    private var serverStatus = ServerStatus.unavailable {
        didSet {
            if let delegate = self.delegate {
                let currentStatus = serverStatus
                
                delegateQueue.async {
                    delegate.statusChanged(to: currentStatus)
                }
                
            }
        }
    }
    
    /// Status of the server
    enum ServerStatus: Equatable {
        /// The server does not seem to be running
        case unavailable
        /// The server is available and we are connected to it
        case available
        /// An error occurred trying to contact the server
        case error(String)
    }
    
    init(delegateQueue: DispatchQueue) throws {
        self.delegateQueue = delegateQueue
        
        fsChangeSource = try HelperCommandsShared.withCommandSocketPath { path in
            let dirPath : UnsafeMutablePointer<Int8> = UnsafeMutablePointer.allocate(capacity: Int(PATH_MAX))
            defer { dirPath.deallocate() }
            let result = dirname_r(path, dirPath)
            assert(result != nil)
            
            let fd = try checkSuccessValue(open(dirPath, O_EVTONLY))

            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write], queue: HelperCommandClient.networkQueue)
            source.setCancelHandler {
                close(fd)
            }
            
            return source
        }
        
        retryTimerSource = DispatchSource.makeTimerSource(flags: [], queue: HelperCommandClient.networkQueue)
        retryTimerSource.setEventHandler { [unowned self] in
            self.tryToConnect()
        }
        
        fsChangeSource.setEventHandler { [unowned self] in
            self.tryToConnect()
        }
    }
    
    /// Start the client; it will attempt to connect to the server
    func activate() {
        retryTimerSource.activate()
        fsChangeSource.activate()
        HelperCommandClient.networkQueue.async { [unowned self] in
            self.tryToConnect()
        }
    }
    
    /// Deactivate the client; it will disconnect from the server
    func deactivate() {
        HelperCommandClient.networkQueue.sync {
            retryTimerSource.cancel()
            clientSource?.cancel()
            clientSource = nil
            clientSockFd = -1
            fsChangeSource.cancel()
        }
    }
    
    /// Ask the server to ungrab the shortcut key
    /// This commands succeeds and does nothing if the server is not started
    /// Returns: true if successful, false if an the server is controlled by another client
    func askUngrabShortcutKey() throws -> Bool {
        guard let result = try send(command: .ungrabShortcut) else {
            return true
        }
        
        return result == .accept
    }
    
    /// Allow the server to regrab the shortcut key
    /// This commands succeeds and does nothing if the server is not started
    func askRegrabShortcutKey() throws {
        _ = try send(command: .regrabShortcut)
    }
    
    /// Attempt to connect to the server if not connected
    private func tryToConnect() {
        retryTimerSource.schedule(deadline: .distantFuture)
        
        guard self.serverStatus == .unavailable else { return }
        
        let sockFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sockFd != -1 else {
            serverStatus = .error("Unable to create socket")
            return
        }
        
        do {
            try HelperCommandsShared.withCommandSocketAddress {
                var result = connect(sockFd, $0, socklen_t(MemoryLayout<sockaddr_un>.stride))
                var connectErrno = errno
                var delay = timeval(tv_sec: 1, tv_usec: 0)
                
                if result == 0 {
                    result = setsockopt(sockFd, SOL_SOCKET, SO_RCVTIMEO, &delay, socklen_t(MemoryLayout.stride(ofValue: delay)))
                    connectErrno = errno
                }
                if result == 0 {
                    result = setsockopt(sockFd, SOL_SOCKET, SO_SNDTIMEO, &delay, socklen_t(MemoryLayout.stride(ofValue: delay)))
                    connectErrno = errno
                }
                
                if result == 0 {
                    let source = DispatchSource.makeReadSource(fileDescriptor: sockFd, queue: HelperCommandClient.networkQueue)
                    source.setCancelHandler { [weak self] in
                        if let strongSelf = self, strongSelf.serverStatus == .available {
                            strongSelf.serverStatus = .unavailable
                            strongSelf.clientSockFd = -1
                        }
                        close(sockFd)
                    }
                    source.setEventHandler { [weak self] in
                        if let commandSent = self?.commandExecuted, commandSent {
                            // The event handler is sometimes called after executing a command, because data was received on the socket
                            // In that case we do nothing; if the event was called because the connection was lost, il will be called
                            // immediately a second time
                            
                            self?.commandExecuted = false
                            return
                        }
                        
                        source.cancel()
                    }
                    
                    serverStatus = .available
                    clientSource = source
                    clientSockFd = sockFd
                    source.activate()
                    
                } else {
                    if connectErrno == ECONNREFUSED {
                        retryTimerSource.schedule(deadline: DispatchTime.now() + DispatchTimeInterval.seconds(1))
                    } else if connectErrno == ENOENT {
                        // No socket so the server is not launched yet
                    } else {
                        serverStatus = .error("Connect error: \(String(utf8String: strerror(connectErrno)) ?? "<errno \(connectErrno)>")")
                    }
                    
                    _ = close(sockFd)
                }
            }
            
        } catch {
            serverStatus = .error("Unable to get server path")
            _ = close(sockFd)
        }
    }
    
    /// Client communication errors
    private enum ClientCommError: String, Error, CustomStringConvertible {
        case badResponse = "Bad response from server"
        
        var description: String {
            return self.rawValue
        }
    }
    
    /// Send a command to the server
    /// - Parameter command: Command to send
    /// - Returns: The response from the server, nil if not connected, throws in case of communication error
    private func send(command: HelperCommandsShared.Command) throws -> HelperCommandsShared.Response? {
        return try HelperCommandClient.networkQueue.sync {
            if clientSockFd == -1 {
                return nil
            }
            
            commandExecuted = true
            
            clientSource?.suspend()
            defer { clientSource?.resume() }
            
            var value = command.rawValue
            try checkNoError(Darwin.send(clientSockFd, &value, 1, 0))

            try checkNoError(Darwin.recv(clientSockFd, &value, 1, 0))
            guard let response = HelperCommandsShared.Response(rawValue: value) else {
                throw ClientCommError.badResponse
            }
            
            return response
        }
    }
}
