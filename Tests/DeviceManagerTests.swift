// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import XCTest

class LoggerObserver: AudioDeviceObserver {
    enum Event: Equatable {
        case add(uid: String, name: String)
        case remove(uid: String, name: String)
    }
    
    var events = [Event]()
    
    func deviceAdded(info: AudioDeviceInfo) {
        events.append(.add(uid: info.uid, name: info.name))
        print("Device added: \(info) (\(info.debugDescription))")
    }
    
    func deviceRemoved(info: AudioDeviceInfo) {
        events.append(.remove(uid: info.uid, name: info.name))
    }

}

class DeviceManagerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        
        reset_current_mock_status()
    }
    
    func testInitNoDevices() {
        let logger = LoggerObserver()
        let manager = AudioDeviceSystemInterfaceCoreAudio(observer: logger, queue: DispatchQueue.main)
        
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0, false)
        
        manager.deactivate()
        
        XCTAssert(logger.events.isEmpty)
        XCTAssertEqual(get_current_mock_status(), [.ADD_LISTENER_CALLED, .REMOVE_LISTENER_CALLED])
    }
    
    func testInitTwoInitialDevicesThenRemoved() {
        add_fake_device(10, 2, 1, "a", "name a")
        add_fake_device(11, 1, 0, "b", "name b")
        
        let logger = LoggerObserver()
        let manager = AudioDeviceSystemInterfaceCoreAudio(observer: logger, queue: DispatchQueue.main)
        
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0, false)
        
        // b has no outputs so is not logged
        XCTAssertEqual(logger.events, [.add(uid: "a", name: "name a")])
        logger.events.removeAll()
        
        manager.switchTo(uid: "z")
        XCTAssertEqual(get_current_mock_status(), [.ADD_LISTENER_CALLED])
        
        manager.switchTo(uid: "a")
        XCTAssertEqual(get_current_mock_status(), [.ADD_LISTENER_CALLED, .SYSTEM_OUTPUT_SET, .DEFAULT_OUTPUT_SET])
        
        remove_fake_device(11)
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0, false)
        XCTAssertEqual(logger.events, [])
        
        remove_fake_device(10)
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0, false)
        XCTAssertEqual(logger.events, [.remove(uid: "a", name: "name a")])
        
        manager.deactivate()
        
        XCTAssertEqual(get_current_mock_status(), [.ADD_LISTENER_CALLED, .REMOVE_LISTENER_CALLED, .SYSTEM_OUTPUT_SET, .DEFAULT_OUTPUT_SET])
    }
}
