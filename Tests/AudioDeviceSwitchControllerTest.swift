// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import XCTest
import Foundation

final class SwitchControllerLogger: SwitchUserInterfaceProtocol, AudioDeviceSystemInterface {
    var uids = [String]()
    var displayed = [String]()

    init() { }
    init(observer: AudioDeviceObserver, queue: DispatchQueue) { }
    func deactivate() { fatalError("deactivate called during test") }
    func currentOutputUid() -> String { fatalError("currentOutputUid called during test") }
    
    func display(text: String) {
        displayed.append(text)
    }

    func switchTo(uid: String) {
        uids.append(uid)
    }
}

class AudioDeviceSwitchControllerTest: XCTestCase {
    typealias DInfo = AudioDeviceListManager.DeviceInfo
    
    func testSwitchNoDevices() {
        let logger = SwitchControllerLogger()
        let controller = AudioDeviceSwitchController(systemInterface: logger, userInterface: logger)
        
        controller.switchToNextDevice(in: [])
        XCTAssertEqual(logger.displayed, ["<No Output>"])
        XCTAssertEqual(logger.uids, [])
    }
    
    func testSwitchAllDevicesUnavailable() {
        let devices = [
            DInfo(uid: "a", connected: false, name: "", title: "Device A", enabled: true),
            DInfo(uid: "b", connected: true, name: "B", title: "", enabled: false),
            DInfo(uid: "c", connected: false, name: "", title: "Device C", enabled: true),
            DInfo(uid: "d", connected: true, name: "D", title: "", enabled: false),
        ]
        
        let logger = SwitchControllerLogger()
        let controller = AudioDeviceSwitchController(systemInterface: logger, userInterface: logger)
        
        controller.switchToNextDevice(in: devices)
        XCTAssertEqual(logger.displayed, ["<No Output>"])
        XCTAssertEqual(logger.uids, [])
    }
    
    func testSwitchOneDeviceNoInitialDevice() {
        let devices = [
            DInfo(uid: "a", connected: true, name: "A", title: "Device A", enabled: true),
            DInfo(uid: "b", connected: true, name: "B", title: "", enabled: false),
            DInfo(uid: "c", connected: false, name: "", title: "Device C", enabled: true),
            DInfo(uid: "d", connected: true, name: "D", title: "", enabled: false),
        ]
        
        let logger = SwitchControllerLogger()
        let controller = AudioDeviceSwitchController(systemInterface: logger, userInterface: logger)
        
        controller.switchToNextDevice(in: devices)
        XCTAssertEqual(logger.displayed, ["Device A"])
        XCTAssertEqual(logger.uids, ["a"])

        controller.switchToNextDevice(in: devices)
        XCTAssertEqual(logger.displayed, ["Device A", "Device A"])
        XCTAssertEqual(logger.uids, ["a", "a"])
    }
    
    func testSwitchOneDeviceDisabledInitialDevice() {
        let devices = [
            DInfo(uid: "a", connected: true, name: "A", title: "Device A", enabled: true),
            DInfo(uid: "b", connected: true, name: "B", title: "", enabled: false),
            DInfo(uid: "c", connected: false, name: "", title: "Device C", enabled: true),
            DInfo(uid: "d", connected: true, name: "D", title: "", enabled: false),
        ]
        
        let logger = SwitchControllerLogger()
        let controller = AudioDeviceSwitchController(systemInterface: logger, userInterface: logger, currentDeviceUid: "b")
        
        controller.switchToNextDevice(in: devices)
        XCTAssertEqual(logger.displayed, ["Device A"])
        XCTAssertEqual(logger.uids, ["a"])
        
        controller.switchToNextDevice(in: devices)
        XCTAssertEqual(logger.displayed, ["Device A", "Device A"])
        XCTAssertEqual(logger.uids, ["a", "a"])
    }
    
    func testSwitchTwoDevices() {
        let devices = [
            DInfo(uid: "a", connected: true, name: "A", title: "Device A", enabled: true),
            DInfo(uid: "b", connected: true, name: "B", title: "", enabled: false),
            DInfo(uid: "c", connected: false, name: "", title: "Device C", enabled: true),
            DInfo(uid: "d", connected: true, name: "D", title: "", enabled: true), // No title so the name should be used when switching
        ]
        
        let logger = SwitchControllerLogger()
        let controller = AudioDeviceSwitchController(systemInterface: logger, userInterface: logger, currentDeviceUid: "d")
        
        controller.switchToNextDevice(in: devices)
        XCTAssertEqual(logger.displayed, ["Device A"])
        XCTAssertEqual(logger.uids, ["a"])
        
        controller.switchToNextDevice(in: devices)
        XCTAssertEqual(logger.displayed, ["Device A", "D"])
        XCTAssertEqual(logger.uids, ["a", "d"])
    }
    
    func testSwitchDisablingCurrentDevice() {
        let devicesInit = [
            DInfo(uid: "a", connected: true, name: "A", title: "Device A", enabled: true),
            DInfo(uid: "b", connected: true, name: "B", title: "Device B", enabled: true),
            DInfo(uid: "c", connected: true, name: "C", title: "Device C", enabled: true),
            DInfo(uid: "d", connected: true, name: "D", title: "Device D", enabled: true),
        ]
        
        let devicesBDisabled = [
            DInfo(uid: "a", connected: true, name: "A", title: "Device A", enabled: true),
            DInfo(uid: "b", connected: true, name: "B", title: "Device B", enabled: false),
            DInfo(uid: "c", connected: true, name: "C", title: "Device C", enabled: true),
            DInfo(uid: "d", connected: true, name: "D", title: "Device D", enabled: true),
        ]
        
        let logger = SwitchControllerLogger()
        let controller = AudioDeviceSwitchController(systemInterface: logger, userInterface: logger, currentDeviceUid: "a")
        
        controller.switchToNextDevice(in: devicesInit)
        XCTAssertEqual(logger.displayed, ["Device B"])
        XCTAssertEqual(logger.uids, ["b"])
        
        controller.switchToNextDevice(in: devicesBDisabled)
        XCTAssertEqual(logger.displayed, ["Device B", "Device C"])
        XCTAssertEqual(logger.uids, ["b", "c"])
    }
    
    func testSwitchDisconnectingCurrentDevice() {
        let devicesInit = [
            DInfo(uid: "a", connected: true, name: "A", title: "Device A", enabled: true),
            DInfo(uid: "b", connected: true, name: "B", title: "Device B", enabled: true),
            DInfo(uid: "c", connected: true, name: "C", title: "Device C", enabled: true),
            DInfo(uid: "d", connected: true, name: "D", title: "Device D", enabled: true),
        ]
        
        let devicesBDisconnected = [
            DInfo(uid: "a", connected: true, name: "A", title: "Device A", enabled: true),
            DInfo(uid: "b", connected: false, name: "B", title: "Device B", enabled: true),
            DInfo(uid: "c", connected: true, name: "C", title: "Device C", enabled: true),
            DInfo(uid: "d", connected: true, name: "D", title: "Device D", enabled: true),
        ]
        
        let logger = SwitchControllerLogger()
        let controller = AudioDeviceSwitchController(systemInterface: logger, userInterface: logger, currentDeviceUid: "a")
        
        controller.switchToNextDevice(in: devicesInit)
        XCTAssertEqual(logger.displayed, ["Device B"])
        XCTAssertEqual(logger.uids, ["b"])
        
        controller.switchToNextDevice(in: devicesBDisconnected)
        XCTAssertEqual(logger.displayed, ["Device B", "Device C"])
        XCTAssertEqual(logger.uids, ["b", "c"])
    }
    
    func testSwitchRemovingCurrentDevice() {
        // This should not happen, but the controller should not crash/infinite loop in that case
        
        let devicesInit = [
            DInfo(uid: "a", connected: true, name: "A", title: "Device A", enabled: true),
            DInfo(uid: "b", connected: true, name: "B", title: "Device B", enabled: true),
            DInfo(uid: "c", connected: true, name: "C", title: "Device C", enabled: true),
            DInfo(uid: "d", connected: true, name: "D", title: "Device D", enabled: true),
        ]
        
        let devicesBRemoved = [
            DInfo(uid: "a", connected: true, name: "A", title: "Device A", enabled: true),
            DInfo(uid: "c", connected: true, name: "C", title: "Device C", enabled: true),
            DInfo(uid: "d", connected: true, name: "D", title: "Device D", enabled: true),
        ]
        
        let logger = SwitchControllerLogger()
        let controller = AudioDeviceSwitchController(systemInterface: logger, userInterface: logger, currentDeviceUid: "a")
        
        controller.switchToNextDevice(in: devicesInit)
        XCTAssertEqual(logger.displayed, ["Device B"])
        XCTAssertEqual(logger.uids, ["b"])
        
        controller.switchToNextDevice(in: devicesBRemoved)
        XCTAssertEqual(logger.displayed, ["Device B", "Device A"])
        XCTAssertEqual(logger.uids, ["b", "a"])
    }
}
