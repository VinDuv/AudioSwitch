// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import XCTest

private struct ListItem: Equatable {
    let enabled: Bool
    let name: String
}

final class FakeDraggingInfo: NSObject, NSDraggingInfo {
    let pasteboardItem: NSPasteboardWriting
    
    init(pasteboardItem: NSPasteboardWriting) {
        self.pasteboardItem = pasteboardItem
        self.draggingFormation = .default
        self.animatesToDestination = false
        self.numberOfValidItemsForDrop = 1
        self.springLoadingHighlight = .standard
        
        super.init()
    }
    
    func draggingDestinationWindow() -> NSWindow? {
        return nil
    }
    
    func draggingSourceOperationMask() -> NSDragOperation {
        return []
    }
    
    func draggingLocation() -> NSPoint {
        return .zero
    }
    
    func draggedImageLocation() -> NSPoint {
        return .zero
    }
    
    func draggedImage() -> NSImage? {
        return nil
    }
    
    func draggingPasteboard() -> NSPasteboard {
        return NSPasteboard.general
    }
    
    func draggingSource() -> Any? {
        return nil
    }
    
    func draggingSequenceNumber() -> Int {
        return 0
    }
    
    func slideDraggedImage(to screenPoint: NSPoint) {
    }
    
    var draggingFormation: NSDraggingFormation
    
    var animatesToDestination: Bool
    
    var numberOfValidItemsForDrop: Int
    
    func enumerateDraggingItems(options enumOpts: NSDraggingItemEnumerationOptions = [], for view: NSView?, classes classArray: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey : Any] = [:], using block: @escaping (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {
        
        guard classArray.contains(where: { $0 == type(of:pasteboardItem) }) else {
            return
        }
        
        var cont: ObjCBool = true
        block(NSDraggingItem(pasteboardWriter: pasteboardItem), 0, &cont)
    }
    
    var springLoadingHighlight: NSSpringLoadingHighlight
    
    func resetSpringLoading() {
    }
    
}

final class FakeTableView: NSTableView {
    let enabledColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("enabled"))
    let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    fileprivate var currentState = [ListItem]()
    
    override func reloadData() {
        guard let dataSource = self.dataSource else {
            fatalError("No dataSource")
        }
        
        let rows = dataSource.numberOfRows!(in: self)
        
        currentState.removeAll(keepingCapacity: true)
        
        for row in 0 ..< rows {
            let enabled = dataSource.tableView!(self, objectValueFor: enabledColumn, row: row) as! Bool
            let name = dataSource.tableView!(self, objectValueFor: nameColumn, row: row)! as! String
            
            currentState.append(ListItem(enabled: enabled, name: name))
        }
    }
    
    func setEnabled(row: Int, to value: Bool) {
        guard let dataSource = self.dataSource else {
            fatalError("No dataSource")
        }
        
        dataSource.tableView!(self, setObjectValue: value, for: enabledColumn, row: row)
    }
    
    func setName(row: Int, to value: String) {
        guard let dataSource = self.dataSource else {
            fatalError("No dataSource")
        }
        
        dataSource.tableView!(self, setObjectValue: value, for: nameColumn, row: row)
    }
    
    func move(rowIndex: Int, aboveIndex: Int) -> Bool {
        guard let dataSource = self.dataSource else {
            fatalError("No dataSource")
        }
        
        guard let pbItem = dataSource.tableView!(self, pasteboardWriterForRow: rowIndex) else {
            fatalError("No pasteboard item got for row \(rowIndex)")
        }
        
        let draggingInfo = FakeDraggingInfo(pasteboardItem: pbItem)
        
        let operations = dataSource.tableView!(self, validateDrop: draggingInfo, proposedRow: aboveIndex, proposedDropOperation: .above)
        
        if !operations.contains(.move) {
            return false
        }
        
        return dataSource.tableView!(self, acceptDrop: draggingInfo, row: aboveIndex, dropOperation: .above)
    }
    
}


class AudioDeviceListControllerTest: XCTestCase {
    typealias PInfo = AudioDeviceListManager.PersistentDeviceInfo
    typealias MInfo = AudioDeviceListManager.DeviceInfo
    
    let persistentDevices = [
        PInfo(uid: "a", title: "Device A", enabled: true),
        PInfo(uid: "b", title: "", enabled: false),
        PInfo(uid: "c", title: "Device C", enabled: true),
        PInfo(uid: "d", title: "", enabled: false),
    ]
    
    var deviceListController: AudioDeviceListController!
    var fakeTableView: FakeTableView!
    var listManager: AudioDeviceListManager!
    
    override func setUp() {
        super.setUp()
        reset_current_mock_status()
        
        deviceListController = AudioDeviceListController()
        fakeTableView = FakeTableView(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
        
        deviceListController.tableView = fakeTableView
        fakeTableView.dataSource = deviceListController
        
        listManager = deviceListController.listManager
        
        deviceListController.awakeFromNib()
    }
    
    override func tearDown() {
        deviceListController.tableView = nil
        deviceListController = nil
        fakeTableView = nil
        
        super.tearDown()
    }
    
    func testLoadingEditingAndReordering() {
        // No devices
        listManager.load(state: persistentDevices)
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0, false)
        XCTAssertEqual(fakeTableView.currentState, [ListItem]())
        
        var expectedDeviceList = [
            MInfo(uid: "a", connected: false, name: "", title: "Device A", enabled: true),
            MInfo(uid: "b", connected: false, name: "", title: "", enabled: false),
            MInfo(uid: "c", connected: false, name: "", title: "Device C", enabled: true),
            MInfo(uid: "d", connected: false, name: "", title: "", enabled: false),
        ]
        XCTAssertEqual(listManager.devices, expectedDeviceList)
        
        // Attach devices a and d
        add_fake_device(10, 2, 1, "a", "name a")
        add_fake_device(11, 1, 1, "d", "name d")
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0, false)
        XCTAssertEqual(fakeTableView.currentState, [
            ListItem(enabled: true, name: "Device A"),
            ListItem(enabled: false, name: "name d"),
        ])
        
        expectedDeviceList[0].connected = true
        expectedDeviceList[0].name = "name a"
        expectedDeviceList[3].connected = true
        expectedDeviceList[3].name = "name d"
        XCTAssertEqual(listManager.devices, expectedDeviceList)
        
        // Attach device b
        add_fake_device(12, 2, 1, "b", "name b")
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0, false)
        XCTAssertEqual(fakeTableView.currentState, [
            ListItem(enabled: true, name: "Device A"),
            ListItem(enabled: false, name: "name b"),
            ListItem(enabled: false, name: "name d"),
        ])
        
        expectedDeviceList[1].connected = true
        expectedDeviceList[1].name = "name b"
        XCTAssertEqual(listManager.devices, expectedDeviceList)
        
        // Set a name to device d and enable it
        fakeTableView.setEnabled(row: 2, to: true)
        fakeTableView.setName(row: 2, to: "Device D")
        fakeTableView.reloadData()
        
        XCTAssertEqual(fakeTableView.currentState, [
            ListItem(enabled: true, name: "Device A"),
            ListItem(enabled: false, name: "name b"),
            ListItem(enabled: true, name: "Device D"),
        ])
        
        expectedDeviceList[3].enabled = true
        expectedDeviceList[3].title = "Device D"
        XCTAssertEqual(listManager.devices, expectedDeviceList)
        
        // Remove name from device A
        fakeTableView.setName(row: 0, to: "")
        fakeTableView.reloadData()
        
        XCTAssertEqual(fakeTableView.currentState, [
            ListItem(enabled: true, name: "name a"),
            ListItem(enabled: false, name: "name b"),
            ListItem(enabled: true, name: "Device D"),
        ])
        
        expectedDeviceList[0].title = ""
        XCTAssertEqual(listManager.devices, expectedDeviceList)
        
        // Move device b above itself (should fail)
        XCTAssertFalse(fakeTableView.move(rowIndex: 1, aboveIndex: 1))
        
        // Move device b below itself (should fail)
        XCTAssertFalse(fakeTableView.move(rowIndex: 1, aboveIndex: 2))
        
        XCTAssertEqual(fakeTableView.currentState, [
            ListItem(enabled: true, name: "name a"),
            ListItem(enabled: false, name: "name b"),
            ListItem(enabled: true, name: "Device D"),
        ])
        XCTAssertEqual(listManager.devices, expectedDeviceList)
        
        // Move device a above device d (should end up below disabled device c)
        XCTAssertTrue(fakeTableView.move(rowIndex: 0, aboveIndex: 2))
        fakeTableView.reloadData()
        
        XCTAssertEqual(fakeTableView.currentState, [
            ListItem(enabled: false, name: "name b"),
            ListItem(enabled: true, name: "name a"),
            ListItem(enabled: true, name: "Device D"),
        ])
        
        expectedDeviceList = [
            MInfo(uid: "b", connected: true, name: "name b", title: "", enabled: false),
            MInfo(uid: "c", connected: false, name: "", title: "Device C", enabled: true),
            MInfo(uid: "a", connected: true, name: "name a", title: "", enabled: true),
            MInfo(uid: "d", connected: true, name: "name d", title: "Device D", enabled: true),
        ]
        XCTAssertEqual(listManager.devices, expectedDeviceList)
        
        // Remove device d, then move b to the end of the list (after device a)
        // Should get c, a, d, b
        remove_fake_device(11)
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0, false)
        
        XCTAssertTrue(fakeTableView.move(rowIndex: 0, aboveIndex: 2))
        fakeTableView.reloadData()
        
        XCTAssertEqual(fakeTableView.currentState, [
            ListItem(enabled: true, name: "name a"),
            ListItem(enabled: false, name: "name b"),
        ])
        
        expectedDeviceList = [
            MInfo(uid: "c", connected: false, name: "", title: "Device C", enabled: true),
            MInfo(uid: "a", connected: true, name: "name a", title: "", enabled: true),
            MInfo(uid: "d", connected: false, name: "name d", title: "Device D", enabled: true),
            MInfo(uid: "b", connected: true, name: "name b", title: "", enabled: false),
        ]
        XCTAssertEqual(listManager.devices, expectedDeviceList)
        
    }
}
