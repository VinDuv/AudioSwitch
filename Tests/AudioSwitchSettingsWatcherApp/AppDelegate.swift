// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import Cocoa


extension AudioDeviceListManager.DeviceInfo: CustomDebugStringConvertible {
    var debugDescription: String {
        let connected = self.connected ? "🔈" : "🔇"
        let enabled = self.enabled ? "🔘" : "⚪"
        let title: String
        
        if self.title.isEmpty {
            if self.name.isEmpty {
                title = "<No name>"
            } else {
                title = self.name
            }
        } else {
            if self.name.isEmpty {
                title = self.title
            } else {
                title = "\(self.title) (\(self.name))"
            }
        }

        return "\(connected)\(enabled) \(title) (\(self.uid))"
    }
}


extension AudioDeviceListManager.PersistentDeviceInfo : CustomDebugStringConvertible {
    var debugDescription: String {
        let enabled = self.enabled ? "🔘" : "⚪"
        let title = self.title.isEmpty ? "<No title>" : self.title
        
        return "\(enabled) \(title) (\(self.uid))"
    }
}


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var window: NSWindow!
    @IBOutlet var textView: NSTextView!
    var systemInterface: AudioDeviceSystemInterfaceCoreAudio!
    var listManager: AudioDeviceListManager!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {     
        listManager = AudioDeviceListManager()
        listManager.changeCallback = {
            self.insertText("New device list from manager:")
            for device in self.listManager.devices {
                self.insertText(" • \(device.debugDescription)")
            }
            
            self.insertText("")
        }
        systemInterface = AudioDeviceSystemInterfaceCoreAudio(observer: listManager, queue: .main)
        listManager.load(state: Settings.instance.deviceList)
        
        Settings.instance.deviceListChangeCallback = { devices in
            self.insertText("New device list from settings:")
            for device in devices {
                self.insertText(" • \(device.debugDescription)")
            }
            
            self.insertText("")
            
            self.listManager.load(state: devices)
        }

        Settings.instance.switchShortcutChangeCallback = { shortcut in
            self.insertText("Shortcut changed to \(shortcut.map(String.init) ?? "<none>")")
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Settings.instance.deviceListChangeCallback = nil
    }

    func insertText(_ text: String) {
        guard let textStorage = textView.textStorage else { return }
        if textStorage.length != 0 {
            textStorage.append(NSAttributedString(string: "\n"))
        }
        
        textStorage.append(NSAttributedString(string: text))
        textView.scrollToEndOfDocument(nil)
    }
}
