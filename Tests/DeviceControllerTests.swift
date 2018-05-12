//
//  DeviceControllerTests.swift
//  test_dev_manager
//
//  Created by Vincent Duvert on 08/05/2018.
//

import XCTest

class DeviceControllerTests: XCTestCase {
    let deviceInfoA = AudioDeviceInfo(uid: "a", name:"a")
    let deviceInfoB = AudioDeviceInfo(uid: "b", name:"b")
    let persistentInfoA = AudioDeviceController.PersistentDeviceInfo(uid: "a", title: "Device A", enabled: true)
    let persistentInfoB = AudioDeviceController.PersistentDeviceInfo(uid: "b", title: "", enabled: false)

    func testEmptyLoadAndAddAB() {
        let controller = AudioDeviceController()
        controller.load(state: [])
        controller.deviceAdded(info: deviceInfoA)
        controller.deviceAdded(info: deviceInfoB)
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceController.DeviceInfo(uid: "a", connected: true, name: "a", title: "", enabled: false),
            AudioDeviceController.DeviceInfo(uid: "b", connected: true, name: "b", title: "", enabled: false),
        ])
        
        controller.deviceRemoved(info: deviceInfoB)
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceController.DeviceInfo(uid: "a", connected: true, name: "a", title: "", enabled: false),
            AudioDeviceController.DeviceInfo(uid: "b", connected: false, name: "b", title: "", enabled: false),
        ])
    }
    
    func testEmptyLoadAndAddBA() {
        let controller = AudioDeviceController()
        controller.load(state: [])
        controller.deviceAdded(info: deviceInfoB)
        controller.deviceAdded(info: deviceInfoA)
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceController.DeviceInfo(uid: "b", connected: true, name: "b", title: "", enabled: false),
            AudioDeviceController.DeviceInfo(uid: "a", connected: true, name: "a", title: "", enabled: false),
        ])
        
        controller.deviceRemoved(info: deviceInfoB)
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceController.DeviceInfo(uid: "b", connected: false, name: "b", title: "", enabled: false),
            AudioDeviceController.DeviceInfo(uid: "a", connected: true, name: "a", title: "", enabled: false),
        ])
    }

    func testAddABAndEmptyLoad() {
        let controller = AudioDeviceController()
        controller.deviceAdded(info: deviceInfoA)
        controller.deviceAdded(info: deviceInfoB)
        controller.load(state: [])

        XCTAssertEqual(controller.devices, [
            AudioDeviceController.DeviceInfo(uid: "a", connected: true, name: "a", title: "", enabled: false),
            AudioDeviceController.DeviceInfo(uid: "b", connected: true, name: "b", title: "", enabled: false),
        ])
        
        controller.deviceRemoved(info: deviceInfoB)
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceController.DeviceInfo(uid: "a", connected: true, name: "a", title: "", enabled: false),
            AudioDeviceController.DeviceInfo(uid: "b", connected: false, name: "b", title: "", enabled: false),
        ])
    }
    
    func testAddBAAndEmptyLoad() {
        let controller = AudioDeviceController()
        controller.deviceAdded(info: deviceInfoB)
        controller.deviceAdded(info: deviceInfoA)
        controller.load(state: [])
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceController.DeviceInfo(uid: "b", connected: true, name: "b", title: "", enabled: false),
            AudioDeviceController.DeviceInfo(uid: "a", connected: true, name: "a", title: "", enabled: false),
        ])
        
        controller.deviceRemoved(info: deviceInfoB)
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceController.DeviceInfo(uid: "b", connected: false, name: "b", title: "", enabled: false),
            AudioDeviceController.DeviceInfo(uid: "a", connected: true, name: "a", title: "", enabled: false),
        ])
    }
    
    func testChangeAddAndUnknownRemove() {
        let controller = AudioDeviceController()
        let alternativeDeviceInfoA = AudioDeviceInfo(uid: "a", name: "x")
        controller.deviceAdded(info: deviceInfoA)
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceController.DeviceInfo(uid: "a", connected: true, name: "a", title: "", enabled: false),
        ])
        
        controller.deviceRemoved(info: deviceInfoA)
        controller.deviceRemoved(info: deviceInfoB)
        controller.deviceAdded(info: alternativeDeviceInfoA)
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceController.DeviceInfo(uid: "a", connected: true, name: "x", title: "", enabled: false),
        ])
    }
    
    func testSavedLoadAndAddAB() {
        let controller = AudioDeviceController()
        controller.load(state: [persistentInfoB, persistentInfoA])
        controller.deviceAdded(info: deviceInfoA)
        controller.deviceAdded(info: deviceInfoB)
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceController.DeviceInfo(uid: "b", connected: true, name: "b", title: "", enabled: false),
            AudioDeviceController.DeviceInfo(uid: "a", connected: true, name: "a", title: "Device A", enabled: true),
        ])
        
        controller.deviceRemoved(info: deviceInfoA)
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceController.DeviceInfo(uid: "b", connected: true, name: "b", title: "", enabled: false),
            AudioDeviceController.DeviceInfo(uid: "a", connected: false, name: "a", title: "Device A", enabled: true),
        ])
    }
    
    func testAddABSavedLoadAnd() {
        let controller = AudioDeviceController()
        controller.deviceAdded(info: deviceInfoA)
        controller.deviceAdded(info: deviceInfoB)
        controller.load(state: [persistentInfoB, persistentInfoA])
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceController.DeviceInfo(uid: "b", connected: true, name: "b", title: "", enabled: false),
            AudioDeviceController.DeviceInfo(uid: "a", connected: true, name: "a", title: "Device A", enabled: true),
            ])
        
        controller.deviceRemoved(info: deviceInfoA)
        
        XCTAssertEqual(controller.devices, [
            AudioDeviceController.DeviceInfo(uid: "b", connected: true, name: "b", title: "", enabled: false),
            AudioDeviceController.DeviceInfo(uid: "a", connected: false, name: "a", title: "Device A", enabled: true),
            ])
    }
}

