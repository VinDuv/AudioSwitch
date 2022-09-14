// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import Cocoa
import os


class AppDelegate: NSObject, NSApplicationDelegate {
    let shortcutMonitor: MASShortcutMonitor = .shared()
    let listManager: AudioDeviceListManager
    let systemInterface: AudioDeviceSystemInterfaceCoreAudio
    let userInterface: SwitchUserInterfaceController
    let switchController: AudioDeviceSwitchController
    var currentShortcut: MASShortcut? = nil
    
    override init() {
        os_log("AudioSwitch helper starting", type: .info)
        
        listManager = AudioDeviceListManager()
        systemInterface = AudioDeviceSystemInterfaceCoreAudio(observer: listManager, queue: .main)
        userInterface = SwitchUserInterfaceController()
        switchController = AudioDeviceSwitchController(systemInterface: systemInterface, userInterface: userInterface)
        
        super.init()
        
        Settings.instance.deviceListChangeCallback = { [unowned self] in self.listManager.load(state: $0) }
        Settings.instance.switchShortcutChangeCallback = { [unowned self] in self.setShortcutKey(to: $0) }
    }
    
    func setShortcutKey(to shortcut: MASShortcut?) {
        if let currentShortcut = currentShortcut {
            shortcutMonitor.unregisterShortcut(currentShortcut)
        }
        
        currentShortcut = shortcut
        
        if let currentShortcut = currentShortcut, let keyCodeString = currentShortcut.keyCodeString {
            if shortcutMonitor.register(currentShortcut, withAction: { [unowned self] in self.shortcutKeyPressed() }) {
                os_log("Switch shortcut changed to %s", type: .info, keyCodeString)
            } else {
                os_log("Failed to set switch shortcut to %s. It may be in use by another app", type: .error, keyCodeString)
            }
        } else {
            os_log("Switch shortcut was deactivated")
        }
    }
    
    /// Called when the shortcut key is pressed. Handles the switch process
    private func shortcutKeyPressed() {
        switchController.switchToNextDevice(in: listManager.devices, afterUid: systemInterface.currentOutputUid())
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        os_log("AudioSwitch helper started", type: .info)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        os_log("AudioSwitch helper quitting", type: .info)
    }
}

let app: NSApplication = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate
app.run()
