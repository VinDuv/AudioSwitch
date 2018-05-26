// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import XCTest

class DeviceListManagerTests: XCTestCase {
    let deviceInfoA = AudioDeviceInfo(uid: "a", name:"a")
    let deviceInfoB = AudioDeviceInfo(uid: "b", name:"b")
    let persistentInfoA = AudioDeviceListManager.PersistentDeviceInfo(uid: "a", title: "Device A", enabled: true)
    let persistentInfoB = AudioDeviceListManager.PersistentDeviceInfo(uid: "b", title: "", enabled: false)

    func testEmptyLoadAndAddAB() {
        let controller = AudioDeviceListManager()
        controller.load(state: [])
        controller.deviceAdded(info: deviceInfoA)
        controller.deviceAdded(info: deviceInfoB)
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceListManager.DeviceInfo(uid: "a", connected: true, name: "a", title: "", enabled: false),
            AudioDeviceListManager.DeviceInfo(uid: "b", connected: true, name: "b", title: "", enabled: false),
        ])
        
        controller.deviceRemoved(info: deviceInfoB)
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceListManager.DeviceInfo(uid: "a", connected: true, name: "a", title: "", enabled: false),
            AudioDeviceListManager.DeviceInfo(uid: "b", connected: false, name: "b", title: "", enabled: false),
        ])
    }
    
    func testEmptyLoadAndAddBA() {
        let controller = AudioDeviceListManager()
        controller.load(state: [])
        controller.deviceAdded(info: deviceInfoB)
        controller.deviceAdded(info: deviceInfoA)
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceListManager.DeviceInfo(uid: "b", connected: true, name: "b", title: "", enabled: false),
            AudioDeviceListManager.DeviceInfo(uid: "a", connected: true, name: "a", title: "", enabled: false),
        ])
        
        controller.deviceRemoved(info: deviceInfoB)
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceListManager.DeviceInfo(uid: "b", connected: false, name: "b", title: "", enabled: false),
            AudioDeviceListManager.DeviceInfo(uid: "a", connected: true, name: "a", title: "", enabled: false),
        ])
    }

    func testAddABAndEmptyLoad() {
        let controller = AudioDeviceListManager()
        controller.deviceAdded(info: deviceInfoA)
        controller.deviceAdded(info: deviceInfoB)
        controller.load(state: [])

        XCTAssertEqual(controller.devices, [
            AudioDeviceListManager.DeviceInfo(uid: "a", connected: true, name: "a", title: "", enabled: false),
            AudioDeviceListManager.DeviceInfo(uid: "b", connected: true, name: "b", title: "", enabled: false),
        ])
        
        controller.deviceRemoved(info: deviceInfoB)
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceListManager.DeviceInfo(uid: "a", connected: true, name: "a", title: "", enabled: false),
            AudioDeviceListManager.DeviceInfo(uid: "b", connected: false, name: "b", title: "", enabled: false),
        ])
    }
    
    func testAddBAAndEmptyLoad() {
        let controller = AudioDeviceListManager()
        controller.deviceAdded(info: deviceInfoB)
        controller.deviceAdded(info: deviceInfoA)
        controller.load(state: [])
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceListManager.DeviceInfo(uid: "b", connected: true, name: "b", title: "", enabled: false),
            AudioDeviceListManager.DeviceInfo(uid: "a", connected: true, name: "a", title: "", enabled: false),
        ])
        
        controller.deviceRemoved(info: deviceInfoB)
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceListManager.DeviceInfo(uid: "b", connected: false, name: "b", title: "", enabled: false),
            AudioDeviceListManager.DeviceInfo(uid: "a", connected: true, name: "a", title: "", enabled: false),
        ])
    }
    
    func testChangeAddAndUnknownRemove() {
        let controller = AudioDeviceListManager()
        let alternativeDeviceInfoA = AudioDeviceInfo(uid: "a", name: "x")
        controller.deviceAdded(info: deviceInfoA)
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceListManager.DeviceInfo(uid: "a", connected: true, name: "a", title: "", enabled: false),
        ])
        
        controller.deviceRemoved(info: deviceInfoA)
        controller.deviceRemoved(info: deviceInfoB)
        controller.deviceAdded(info: alternativeDeviceInfoA)
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceListManager.DeviceInfo(uid: "a", connected: true, name: "x", title: "", enabled: false),
        ])
    }
    
    func testSavedLoadAndAddAB() {
        let controller = AudioDeviceListManager()
        controller.load(state: [persistentInfoB, persistentInfoA])
        controller.deviceAdded(info: deviceInfoA)
        controller.deviceAdded(info: deviceInfoB)
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceListManager.DeviceInfo(uid: "b", connected: true, name: "b", title: "", enabled: false),
            AudioDeviceListManager.DeviceInfo(uid: "a", connected: true, name: "a", title: "Device A", enabled: true),
        ])
        
        controller.deviceRemoved(info: deviceInfoA)
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceListManager.DeviceInfo(uid: "b", connected: true, name: "b", title: "", enabled: false),
            AudioDeviceListManager.DeviceInfo(uid: "a", connected: false, name: "a", title: "Device A", enabled: true),
        ])
    }
    
    func testAddABSavedLoadAnd() {
        let controller = AudioDeviceListManager()
        controller.deviceAdded(info: deviceInfoA)
        controller.deviceAdded(info: deviceInfoB)
        controller.load(state: [persistentInfoB, persistentInfoA])
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceListManager.DeviceInfo(uid: "b", connected: true, name: "b", title: "", enabled: false),
            AudioDeviceListManager.DeviceInfo(uid: "a", connected: true, name: "a", title: "Device A", enabled: true),
            ])
        
        controller.deviceRemoved(info: deviceInfoA)
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceListManager.DeviceInfo(uid: "b", connected: true, name: "b", title: "", enabled: false),
            AudioDeviceListManager.DeviceInfo(uid: "a", connected: false, name: "a", title: "Device A", enabled: true),
            ])
    }
}

