// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import Foundation
import Darwin

/// Shared definitions between client and server
enum HelperCommandsShared {
    /// Socket name
    static private let socketName = "cmds.sock"
    
    /// Cached socket address (length == 0 iif uninitialized)
    static private var socketAddress = sockaddr_un()
    
    /// Socket address lock
    static private var socketAddressLock = os_unfair_lock()
    
    /// Client to server commands
    enum Command: Int8 {
        /// Ask the server to ungrab the shortcut key
        case ungrabShortcut
        /// Let the server regrab the shortcut key
        case regrabShortcut
    }
    
    /// Server to client responses
    enum Response: Int8 {
        /// The command was accepted
        case accept
        /// The command was rejected
        case reject
    }
    
    /// Error types for communication errors
    enum SocketAddressError: String, Error, CustomStringConvertible {
        case unableToGetPath = "Unable to retrieve or create shared path"
        case socketPathTooLong = "Socket path is too long"
        
        var description: String {
            return self.rawValue
        }
    }
    
    /// Call a function with the socket address to use for client-server communication.
    /// This may be the wrong address if the cwd changed since app startup
    /// - Parameter body: Function to call with a pointer to the socket address
    /// - Returns: The value returned by the function
    static public func withCommandSocketAddress<Result>(body: ((UnsafePointer<sockaddr>) throws -> Result)) throws -> Result {
        os_unfair_lock_lock(&socketAddressLock)
        defer { os_unfair_lock_unlock(&socketAddressLock)}
        
        if socketAddress.sun_len == 0 {
            try initializeSocketAddress()
        }
        
        return try withUnsafePointer(to: &socketAddress) {
            try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                try body($0)
            }
        }
    }
    
    /// Call a function with the socket path used for client-server communication.
    /// This may be the wrong path if the cwd changed since app startup
    /// - Parameter body: Function to call with a pointer to the path
    /// - Returns: The value returned by the function
    static public func withCommandSocketPath<Result>(body: ((UnsafePointer<Int8>) throws -> Result)) throws -> Result {
        os_unfair_lock_lock(&socketAddressLock)
        defer { os_unfair_lock_unlock(&socketAddressLock)}
        
        if socketAddress.sun_len == 0 {
            try initializeSocketAddress()
        }
        
        let capacity = MemoryLayout.stride(ofValue: socketAddress.sun_path)
        return try withUnsafePointer(to: &socketAddress.sun_path) {
            try $0.withMemoryRebound(to: Int8.self, capacity: capacity) {
                try body($0)
            }
        }
    }
    
    /// Initialize the socket address from the application’s App Group folder
    static private func initializeSocketAddress() throws {
        class UnusedClass {}
        
        guard let appGroup = Bundle(for: UnusedClass.self).object(forInfoDictionaryKey: "AppGroup") as? String else {
            throw SocketAddressError.unableToGetPath
        }
        
        guard let location = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            throw SocketAddressError.unableToGetPath
        }
        
        let directory = location.appendingPathComponent("Library").appendingPathComponent("Application Support")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [:])
        
        try setSocketDirPath(to: directory)
    }
    
    /// Set the directory path which will contain the socket.
    /// This is normally done automatically; this function is public for testing purposes.
    /// This function may throw if the specified path is too long.
    /// - Parameter to: URL to the directory
    static public func setSocketDirPath(to url: URL) throws {
        let fullPath = url.appendingPathComponent(socketName, isDirectory: false).path
        
        if setSocketAddress(to: fullPath) {
            return
        }
        
        let currentPath = FileManager.default.currentDirectoryPath + "/"
        if fullPath.hasPrefix(currentPath) && setSocketAddress(to: String(fullPath.dropFirst(currentPath.count))){
            return
        }
        
        throw SocketAddressError.socketPathTooLong
    }
    
    /// Set the socket address to the specified path.
    /// - Parameter to: Absolute or relative socket path
    /// - Returns: true if setting the address was successful, false if the path was too long
    static private func setSocketAddress(to path: String) -> Bool {
        let capacity = MemoryLayout.stride(ofValue: socketAddress.sun_path)
        
        return path.withCString {
            let length = strlcpy(&socketAddress.sun_path.0, $0, capacity)
            precondition(length > 0)
            
            if length >= capacity { // The path was truncated
                socketAddress.sun_len = 0
                return false
            }
            
            socketAddress.sun_family = sa_family_t(AF_UNIX)
            socketAddress.sun_len = numericCast(length)
            
            return true
        }
    }
}

/// Checks that the return value from a POSIX function is not -1. Throws an error in this case.
/// - Parameter retVal: The return value
/// - Parameter allowError: Allowed errno value (optional)
/// - Returns: The value passed in
func checkSuccessValue<Value: BinaryInteger>(_ retVal: Value, allowErrno errnoValue: Int32 = 0) throws -> Value {
    if retVal == -1 && errno != errnoValue {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
    }
    return retVal
}


/// Checks that the return value from a POSIX function is 0 or greater. Throws an error if it is not the case.
/// - Parameter retVal: The return value
/// - Parameter allowError: Allowed errno value (optional)
func checkNoError<Value: BinaryInteger>(_ retVal: Value, allowErrno errnoValue: Int32 = 0) throws {
    if retVal < 0 && errno != errnoValue {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
    }
}
