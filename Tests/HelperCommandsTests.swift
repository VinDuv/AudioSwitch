// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import XCTest

final class ServerLogger: HelperCommandsServerDelegate {
    enum Command: Equatable {
        case ungrab
        case regrab
    }
    
    var commands = [Command]()
    
    func ungrabShortcutKey() {
        commands.append(.ungrab)
    }
    
    func regrabShortcutKey() {
        commands.append(.regrab)
    }
}

final class ClientLogger: HelperCommandClientDelegate {
    var statuses = [HelperCommandClient.ServerStatus]()
    
    func statusChanged(to newStatus: HelperCommandClient.ServerStatus) {
        statuses.append(newStatus)
    }
}

final class HelperCommandsTests: XCTestCase {
    let serverLogger = ServerLogger()
    let client1Logger = ClientLogger()
    let client2Logger = ClientLogger()
    
    override func setUp() {
        serverLogger.commands.removeAll()
        client1Logger.statuses.removeAll()
        client2Logger.statuses.removeAll()
    }
    
    func testStartServerThenClients() {
        let server = setUpServer()
        
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 1, false)
        
        let client1 = setUpClient(using: client1Logger)
        defer { client1.deactivate() }
        
        let client2 = setUpClient(using: client2Logger)
        defer { client2.deactivate() }
        
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 2, false)
        
        XCTAssertEqual(serverLogger.commands, [])
        XCTAssertEqual(client1Logger.statuses, [.available])
        XCTAssertEqual(client2Logger.statuses, [.available])
        
        server.deactivate()
        
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 1, false)
        
        XCTAssertEqual(serverLogger.commands, [])
        XCTAssertEqual(client1Logger.statuses, [.available, .unavailable])
        XCTAssertEqual(client2Logger.statuses, [.available, .unavailable])
    }
    
    func testStartClientsThenServer() {
        let client1 = setUpClient(using: client1Logger)
        defer { client1.deactivate() }
        
        let client2 = setUpClient(using: client2Logger)
        defer { client2.deactivate() }
        
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 1, false)
        
        XCTAssertEqual(serverLogger.commands, [])
        XCTAssertEqual(client1Logger.statuses, [])
        XCTAssertEqual(client2Logger.statuses, [])
        
        let server = setUpServer()
        
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 1, false)

        XCTAssertEqual(serverLogger.commands, [])
        XCTAssertEqual(client1Logger.statuses, [.available])
        XCTAssertEqual(client2Logger.statuses, [.available])
        
        server.deactivate()
        
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 1, false)
        
        XCTAssertEqual(serverLogger.commands, [])
        XCTAssertEqual(client1Logger.statuses, [.available, .unavailable])
        XCTAssertEqual(client2Logger.statuses, [.available, .unavailable])
    }
    
    func testClientConnectError() {
        let server = setUpServer()
        
        XCTAssertNoThrow(
            try HelperCommandsShared.withCommandSocketPath { path in
                try checkNoError(chmod(path, mode_t(0)))
            }
        )
        
        let client1 = setUpClient(using: client1Logger)
        defer { client1.deactivate() }
        
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 1, false)
        
        XCTAssertEqual(serverLogger.commands, [])
        XCTAssertEqual(client1Logger.statuses, [.error("Connect error: Permission denied")])
        
        server.deactivate()
        
        let server2 = setUpServer()
        defer { server2.deactivate() }
        
        let client2 = setUpClient(using: client2Logger)
        defer { client2.deactivate() }
        
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 1, false)
        
        XCTAssertEqual(serverLogger.commands, [])
        XCTAssertEqual(client1Logger.statuses, [.error("Connect error: Permission denied")])
        XCTAssertEqual(client2Logger.statuses, [.available])
    }
    
    func testCommandSending() {
        let server = setUpServer()
        defer { server.deactivate() }
        
        let client1 = setUpClient(using: client1Logger)
        defer { client1.deactivate() }
        
        let client2 = setUpClient(using: client2Logger)
        
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 1, false)
        
        XCTAssertEqual(serverLogger.commands, [])
        XCTAssertEqual(client1Logger.statuses, [.available])
        XCTAssertEqual(client2Logger.statuses, [.available])
        
        XCTAssertTrue(try client1.askUngrabShortcutKey())
        XCTAssertEqual(serverLogger.commands, [.ungrab])
        
        XCTAssertFalse(try client1.askUngrabShortcutKey())
        XCTAssertEqual(serverLogger.commands, [.ungrab])
        
        XCTAssertFalse(try client2.askUngrabShortcutKey())
        XCTAssertEqual(serverLogger.commands, [.ungrab])
        
        XCTAssertNoThrow(try client1.askRegrabShortcutKey())
        XCTAssertEqual(serverLogger.commands, [.ungrab, .regrab])
        
        XCTAssertTrue(try client2.askUngrabShortcutKey())
        XCTAssertEqual(serverLogger.commands, [.ungrab, .regrab, .ungrab])
        
        client2.deactivate()
        
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 1, false)
        XCTAssertEqual(serverLogger.commands, [.ungrab, .regrab, .ungrab, .regrab])
    }
    
    private func setUpServer() -> HelperCommandsServer {
        let server = HelperCommandsServer(delegateQueue: .main)
        server.delegate = serverLogger
        XCTAssertNoThrow(try server.activate())
        return server
    }
    
    private func setUpClient(using logger: ClientLogger) -> HelperCommandClient {
        let client: HelperCommandClient
        do {
            client = try HelperCommandClient(delegateQueue: .main)
        } catch {
            XCTFail("Error thrown: \(error)")
            fatalError()
        }
        client.delegate = logger
        client.activate()
        return client
    }
}
