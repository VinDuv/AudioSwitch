// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import Foundation
import Darwin

/// Delegate handling commands received by the server
protocol HelperCommandsServerDelegate: AnyObject {
    /// Called when one client wants the server to ungrab the shortcut key
    func ungrabShortcutKey()
    
    /// Called when the client no longer needs the server to ungrab the shortcut key
    func regrabShortcutKey()
}

/// Socket server receving commands in the helper process
final class HelperCommandsServer {
    public weak var delegate: HelperCommandsServerDelegate?
    private var delegateQueue: DispatchQueue
    
    private static var networkQueue = DispatchQueue(label: "net.duvert.AudioSwitch.networkServerQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .inherit, target: nil)
    private var serverSource: DispatchSourceRead?
    private var handlingUngrabRequestFromClient = false
    
    /// Class handling a client socket.
    private class Client: Hashable {
        private static var clients = Set<Client>()
        private let source: DispatchSourceRead
        private let server: HelperCommandsServer
        private var handlingUngrabRequest = false
        
        init(fd: Int32, server: HelperCommandsServer) {
            self.server = server
            source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: HelperCommandsServer.networkQueue)
            source.setCancelHandler { [weak self] in
                if let strongSelf = self {
                    if strongSelf.handlingUngrabRequest {
                        _ = strongSelf.server.handleRegrabRequest()
                    }
                    
                    Client.clients.remove(strongSelf)
                }
                _ = shutdown(fd, SHUT_RDWR)
                _ = close(fd)
            }
            source.setEventHandler { [unowned self] in
                var value: Int8 = 0
                let result = recv(fd, &value, 1, 0)
                if result < 1 {
                    self.source.cancel()
                    return
                }
                
                var commandReturn = self.handleCommand(value: value)
                _ = send(fd, &commandReturn, 1, 0)
            }
            Client.clients.insert(self)
            source.activate()
        }
        
        /// Handle a command and provide the response
        /// - Parameter value: Command byte
        /// - Returns: The response byte
        private func handleCommand(value: Int8) -> Int8 {
            let response: HelperCommandsShared.Response
            if let command = HelperCommandsShared.Command(rawValue: value) {
                switch command {
                case .ungrabShortcut:
                    response = handleUngrab()
                case .regrabShortcut:
                    response = handleRegrab()
                }
                
            } else {
                response = .reject
            }
            
            return response.rawValue
        }
        
        /// Handle a ungrab command
        /// - Returns: the command result
        func handleUngrab() -> HelperCommandsShared.Response {
            if !handlingUngrabRequest && server.handleUngrabRequest() {
                handlingUngrabRequest = true
                return .accept
            }
            
            return .reject
        }
        
        /// Handle a regrab command
        /// - Returns: the command result
        func handleRegrab() -> HelperCommandsShared.Response {
            if handlingUngrabRequest {
                server.handleRegrabRequest()
                handlingUngrabRequest = false
                return .accept
            }
            
            return .reject
        }
        
        /// Deactivate all running clients
        static func deactivateAll() {
            HelperCommandsServer.networkQueue.sync {
                let prevClients = clients
                clients.removeAll()
                
                for client in prevClients {
                    client.source.cancel()
                }
            }
        }
        
        var hashValue: Int { return source.hash }
        
        static func == (lhs: HelperCommandsServer.Client, rhs: HelperCommandsServer.Client) -> Bool {
            return lhs.source.handle == rhs.source.handle
        }
    }
    
    init(delegateQueue: DispatchQueue) {
        self.delegateQueue = delegateQueue
    }
    
    /// Start the socket server
    func activate() throws {
        precondition(serverSource == nil)
        
        let sockFD = try checkSuccessValue(socket(AF_UNIX, SOCK_STREAM, 0))
        
        try HelperCommandsShared.withCommandSocketPath {
            try checkNoError(unlink($0), allowErrno: ENOENT)
        }
        
        try HelperCommandsShared.withCommandSocketAddress {
            try checkNoError(bind(sockFD, $0, socklen_t(MemoryLayout<sockaddr_un>.stride)))
        }
        
        try! checkNoError(fcntl(sockFD, F_SETFL, O_NONBLOCK))
        
        try checkNoError(listen(sockFD, 1))
        
        let source = DispatchSource.makeReadSource(fileDescriptor: sockFD, queue: HelperCommandsServer.networkQueue)
        source.setCancelHandler {
            close(sockFD)
        }
        source.setEventHandler {
            let connection = accept(sockFD, nil, nil)
            
            try! checkNoError(fcntl(sockFD, F_SETFL, O_NONBLOCK))
            
            if connection == -1 {
                return
            }
            
            _ = Client(fd: connection, server: self)
        }
        
        serverSource = source
        
        source.activate()
    }
    
    /// Handle ungrab request from client
    /// - Returns: true iif the request was accepted
    func handleUngrabRequest() -> Bool {
        if handlingUngrabRequestFromClient {
            return false
        }
        
        delegate?.ungrabShortcutKey()
        
        handlingUngrabRequestFromClient = true
        return true
    }
    
    /// Handle regrab request from client
    func handleRegrabRequest() {
        if handlingUngrabRequestFromClient {
            delegate?.regrabShortcutKey()
            handlingUngrabRequestFromClient = false
        }
    }
    
    /// Stop the socket server if it’s activated
    func deactivate() {
        if let source = serverSource {
            try! HelperCommandsShared.withCommandSocketPath {
                try checkNoError(unlink($0), allowErrno: ENOENT)
            }
            
            source.cancel()
            serverSource = nil
            Client.deactivateAll()
        }
    }
}
