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
}

/// Manages the persistent settings shared between the preferences pane and the helper application
final class Settings: SettingsProtocol {
    /// Shared instance
    static let instance = Settings()
    
    /// UserDefaults instance
    private let defaults: UserDefaults
    
    private var observer: NSKeyValueObservation?
    
    /// Device list change callback
    var deviceListChangeCallback: (([DeviceInfo]) -> Void)? {
        didSet {
            observer?.invalidate()
            
            if (deviceListChangeCallback != nil) {
                observer = defaults.observe(\UserDefaults.Devices, changeHandler: { [unowned self] (_, _) in
                    self.deviceListChangeCallback?(self.deviceList)
                })
            }
        }
    }
    
    /// Initialize the settings object
    /// - Parameters:
    ///   - suiteName: Identifier of the share UserDefaults suite
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
    
}
