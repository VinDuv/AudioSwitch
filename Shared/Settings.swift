// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import Foundation


/// Protocol definition for easier testing
protocol SettingsProtocol: AnyObject {
    typealias DeviceInfo = AudioDeviceListManager.PersistentDeviceInfo
    
    var deviceList: [DeviceInfo] { get set }
}

/// UserDefaults extension to be able to use KVO on interesting properties
extension UserDefaults {
    @objc dynamic var Devices: [[String: Any]]? {
        return self.value(forKey: "Devices") as? [[String: Any]]
    }
    
    @objc dynamic var SwitchShortcut: [String: UInt]? {
        return self.value(forKey: "SwitchShortcut") as? [String: UInt]
    }
}

/// Manages the persistent settings shared between the preferences pane and the helper application
final class Settings: SettingsProtocol {
    /// Shared instance
    static let instance = Settings()
    
    /// UserDefaults instance
    private let defaults: UserDefaults
    
    /// Initialize the settings object
    private init() {
        guard let suiteName = Bundle.main.object(forInfoDictionaryKey: "SettingsSuite") as? String else {
            fatalError("SettingsSuite missing in info plist")
        }
        
        guard let userDefaults =  UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create UserDefaults with suite \(suiteName)")
        }
        
        self.defaults = userDefaults
        self.defaults.register(defaults: [:])
    }
    
    /// Device list
    var deviceList: [DeviceInfo] {
        get {
            var devices = [DeviceInfo]()
            
            if let savedDevices = defaults.Devices {
                for savedDevice in savedDevices {
                    guard let uid = savedDevice["UID"] as? String else { continue }
                    guard let title = savedDevice["Title"] as? String else { continue }
                    guard let enabled = savedDevice["Enabled"] as? Bool else { continue }
                    
                    devices.append(DeviceInfo(uid: uid, title: title, enabled: enabled))
                }
            }
            
            return devices
        }
        
        set {
            let savedDevices = newValue.map {
                ["UID": $0.uid, "Title": $0.title, "Enabled": $0.enabled]
            }
            
            defaults.set(savedDevices, forKey: "Devices")
        }
    }
    
    /// Device list change observer
    private var deviceListObserver: NSKeyValueObservation?
    
    /// Device list change callback
    var deviceListChangeCallback: (([DeviceInfo]) -> Void)? {
        didSet {
            deviceListObserver?.invalidate()
            
            if (deviceListChangeCallback != nil) {
                deviceListObserver = defaults.observe(\UserDefaults.Devices, changeHandler: { [unowned self] (_, _) in
                    self.deviceListChangeCallback?(self.deviceList)
                })
            }
        }
    }
    
    /// Switch shortcut
    var switchShortcut: MASShortcut? {
        get {
            if let shortcut = defaults.SwitchShortcut, let keyCode = shortcut["KeyCode"], let modifierFlags = shortcut["ModifierFlags"] {
                return MASShortcut(keyCode: keyCode, modifierFlags: modifierFlags)
            }
            
            return nil
        }
        
        set {
            let result: [String: UInt]?
            
            if let newValue = newValue {
                result = [
                    "KeyCode": newValue.keyCode,
                    "ModifierFlags": newValue.modifierFlags
                ]
            } else {
                result = nil
            }
            
            defaults.set(result, forKey: "SwitchShortcut")
        }
    }
    
    /// Switch shortcut change observer
    private var switchShortcutObserver: NSKeyValueObservation?
    
    /// Switch shortcut change callback
    var switchShortcutChangeCallback: ((MASShortcut?) -> Void)? {
        didSet {
            switchShortcutObserver?.invalidate()
            
            if (switchShortcutChangeCallback != nil) {
                switchShortcutObserver = defaults.observe(\UserDefaults.SwitchShortcut, changeHandler: { [unowned self] (_, _) in
                    self.switchShortcutChangeCallback?(self.switchShortcut)
                })
            }
        }
    }
    
}
