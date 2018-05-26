// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import Cocoa


/// Controller for the AudioSwitch preferences window.
final class PrefsWindowController: NSWindowController {
    static let ownNib = NSNib.Name("AudioSwitchPrefs")
    
    /// Create a preferences window controller with its associated window
    static func create() -> PrefsWindowController {
        // Static factory to avoid messing with NSWindowController's initializers
        let controller = PrefsWindowController(windowNibName: ownNib)
        
        controller.showWindow(nil)
        
        return controller
    }
}


/// Controller for the device list
final class AudioDeviceListController: NSObject, NSTableViewDataSource {
    let enabledIdentifier = NSUserInterfaceItemIdentifier("enabled")
    let nameIdentifier = NSUserInterfaceItemIdentifier("name")
    let movedRowIdentifier = NSPasteboard.PasteboardType("net.duvert.audioswitch.row")
    
    let systemInterface: AudioDeviceSystemInterfaceCoreAudio
    let listManager: AudioDeviceListManager
    @IBOutlet weak var tableView: NSTableView!
    
    /// Indices of the connected devices in the manager's table
    var displayedIndices : [Int] {
        if displayedIndicesCache.isEmpty {
            displayedIndicesCache = listManager.devices.lazy.indices.filter { listManager.devices[$0].connected }
        }
        
        return displayedIndicesCache
    }
    
    /// Cache of indices of the connected devices in the manager's table
    var displayedIndicesCache = [Int]()
    
    override init() {
        listManager = AudioDeviceListManager()
        systemInterface = AudioDeviceSystemInterfaceCoreAudio(observer: listManager, queue: DispatchQueue.main)
        
        super.init()
        
        listManager.changeCallback = self.handleListChange
    }
    
    deinit {
        listManager.changeCallback = nil
        systemInterface.deactivate()
    }
    
    /// Called when the tableView outlet is ready; enables drag/drop on the table view
    override func awakeFromNib() {
        tableView.registerForDraggedTypes([movedRowIdentifier])
    }
    
    /// Called when the device list changes. Prepares the refresh of the list view.
    func handleListChange() {
        // Invalidate the indices list
        displayedIndicesCache.removeAll()
        
        tableView.reloadData()
    }
    
    /// Table view data source implementation; returns the number of connected devices
    func numberOfRows(in tableView: NSTableView) -> Int {
        return displayedIndices.count
    }
    
    /// Table view data source implementation; returns the name or enable status of the specified connected device
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let device = listManager.devices[displayedIndices[row]]
        
        if let identifier = tableColumn?.identifier {
            switch identifier {
            case enabledIdentifier:
                return device.enabled
                
            case nameIdentifier:
                return device.title.isEmpty ? device.name : device.title
                
            default:
                fatalError("Unknown identifier \(identifier)")
            }
        }
        
        return nil
    }
    
    /// Table view data source implementation; set the name or enable status of the specified connected device
    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        let index = displayedIndices[row]
        
        if let identifier = tableColumn?.identifier, let value = object {
            switch identifier {
            case enabledIdentifier:
                listManager.devices[index].enabled = value as! Bool
                
            case nameIdentifier:
                listManager.devices[index].title = value as! String
                
            default:
                fatalError("Unknown identifier \(identifier)")
            }
        }
    }
    
    /// Table view data source implementation; allow dragging rows
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        
        item.setString(String(row), forType: movedRowIdentifier)
        
        return item
    }
    
    /// Table view data source implementation; allow dropping dragged rows between other rows
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        
        // Only allow dropping between rows, not on the rows themselves
        if dropOperation == .above {
            return [.move]
        }
        
        return []
    }
    
    /// Table view data source implementation; finalize the drag/drop operation
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        
        var draggedRowIndex = -1
        
        info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) { (dragItem, _, _) in
            // We can only get NSPasteboardItem's here
            let pbItem = dragItem.item as! NSPasteboardItem
            if let stringValue = pbItem.string(forType: self.movedRowIdentifier), let value = Int(stringValue) {
                draggedRowIndex = value
            }
        }
        
        if draggedRowIndex < 0 || draggedRowIndex >= displayedIndices.count || draggedRowIndex == row || draggedRowIndex + 1 == row {
            // Nothing to do; the dragged index is invalid, or we tried to move a row between itself
            // and the next (or previous) one; it should not move
            return false
        }
        
        let sourceIndex = displayedIndices[draggedRowIndex]
        let destIndex = row >= displayedIndices.count ? listManager.devices.endIndex : displayedIndices[row]
        
        let device = listManager.devices.remove(at: sourceIndex)
        
        if sourceIndex < destIndex {
            listManager.devices.insert(device, at: destIndex - 1)
        } else {
            listManager.devices.insert(device, at: destIndex)
        }
        
        // Invalidate the indices list
        displayedIndicesCache.removeAll()

        return true
    }
    
}
