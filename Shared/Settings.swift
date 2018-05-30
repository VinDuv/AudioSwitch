// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import Foundation


/// Protocol definition for easier testing
protocol SettingsProtocol: AnyObject {
    typealias DeviceInfo = AudioDeviceListManager.PersistentDeviceInfo
    
    var deviceList: [DeviceInfo] { get set }
}

/// Manages the persistent settings shared between the preferences pane and the helper application
final class Settings: SettingsProtocol {
    /// Shared instance
    static let instance = Settings()
    
    /// UserDefaults instance
    private let defaults: UserDefaults
    
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
            
            if let savedDevices = defaults.value(forKey: "Devices") as? [[String: Any]] {
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
