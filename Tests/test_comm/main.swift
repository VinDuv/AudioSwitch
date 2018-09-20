// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import Foundation

do {
    try HelperCommandsShared.setSocketDirPath(to: URL(fileURLWithPath: "/tmp", isDirectory: true))
} catch {
    print("Path setting error: \(error)")
}

let runLoop = CFRunLoopGetCurrent()!
var server: HelperCommandsServer?

class ServerManager: HelperCommandsServerDelegate {
    static private var instance: ServerManager?
    let server: HelperCommandsServer
    
    private init() {
        self.server = HelperCommandsServer(delegateQueue: .main)
        self.server.delegate = self
        try! self.server.activate()
    }
    
    func deactivate() {
        self.server.deactivate()
    }
    
    static func handle(command: String) -> Bool {
        if command == "s" {
            if let currentInstance = instance {
                print("Quitting server")
                currentInstance.deactivate()
                instance = nil
            } else {
                print("Creating server")
                instance = ServerManager()
            }
            
            return true
        }
        
        return false
    }
    
    func ungrabShortcutKey() {
        print("The server was asked to ungrab the shortcut key")
    }
    
    func regrabShortcutKey() {
        print("The server was asked to regrab the shortcut key")
    }
}


class ClientManager: HelperCommandClientDelegate {
    static private var instances = [ClientManager?](repeating: nil, count: 10)
    let client: HelperCommandClient
    let id: Int
    
    private init(id: Int) {
        self.client = try! HelperCommandClient(delegateQueue: .main)
        self.id = id
        self.client.delegate = self
        self.client.activate()
    }
    
    func deactivate() {
        self.client.deactivate()
    }
    
    static func handle(command: String) -> Bool {
        if let clientId = Int(command), clientId < 10 {
            if instances[clientId] == nil {
                print("Creating client \(clientId)")
                instances[clientId] = ClientManager(id: clientId)
            } else {
                print("Quitting client \(clientId)")
                instances[clientId]?.deactivate()
                instances[clientId] = nil
            }
            
            return true
        }
        
        if let clientId = Int(command.dropLast()), let clientCommand = command.last, clientId < 10 {
            guard let client = instances[clientId] else {
                print("Client \(clientId) is not started")
                return true
            }
            
            return client.handle(clientCommand: clientCommand)
        }
        
        return false
    }
    
    func handle(clientCommand: Character) -> Bool {
        if clientCommand == "u" {
            do {
                let result = try self.client.askUngrabShortcutKey()
                print("Client \(id) ask ungrab result: \(result)")
            } catch {
                print("Client \(id) ask ungrab error: \(error)")
            }
            
            return true
        }
        
        if clientCommand == "r" {
            do {
                try self.client.askRegrabShortcutKey()
                print("Client \(id) asked regrab without error")
            } catch {
                print("Client \(id) ask regrab error: \(error)")
            }
            
            return true
        }
        
        return false
    }
    
    func statusChanged(to newStatus: HelperCommandClient.ServerStatus) {
        print("Client \(id) server status changed to \(newStatus)")
    }
}


let stdinSource = DispatchSource.makeReadSource(fileDescriptor: 0, queue: DispatchQueue.main)
stdinSource.setEventHandler {
    guard let line = readLine(strippingNewline: true) else {
        stdinSource.cancel()
        return
    }
    
    if line.isEmpty {
        CFRunLoopStop(runLoop)
    
    } else if !ServerManager.handle(command: line) && !ClientManager.handle(command: line) {
        print("Invalid command")
    }
}

let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT)
sigintSource.setEventHandler {
    CFRunLoopStop(runLoop)
}

signal(SIGINT, {_ in })

print("""
    Press Enter or ^C to quit.
    Type s to create or quit the server.
    Type 0 ... 9 to create/quit a client.
    Type 0 ... 9 followed by u to make a client send an ungrab request
    Type 0 ... 9 followed by r to make a client send a regrab request
    """)
stdinSource.activate()
sigintSource.activate()

CFRunLoopRun()

print("Done")

stdinSource.cancel()
sigintSource.cancel()
