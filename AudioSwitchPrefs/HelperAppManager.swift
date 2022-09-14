// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import AppKit
import ServiceManagement


/// Manages the helper application installation as a service
final class HelperAppManager {
    /// Bundle ID of the helper application
    private let helperAppId: String
    
    init() {
        guard let appId = Bundle.main.object(forInfoDictionaryKey: "HelperApp") as? String else {
            fatalError("HelperApp missing in info plist")
        }
        
        helperAppId = appId
    }
    
    /// Indicates if the helper app is currently running
    var helperAppRunning: Bool {
        return NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == self.helperAppId }
    }
    
    /// Indicates if the helper app is enabled ; returns nil if an error occurred trying to get the information
    var helperAppEnabled: Bool? {
        var serviceDisabled: DarwinBoolean = false
        
        // FIXME: SMJobIsEnabled returns false when the service is enabled, for some reason
        if SMJobIsEnabled(kSMDomainUserLaunchd, helperAppId as CFString, &serviceDisabled) != 0 {
            return nil
        }
        
        return !serviceDisabled.boolValue
    }
    
    /// Enable or disable the helper auto-start property
    /// - Returns: true if change was successful, false if an error occurred
    func setHelperAutoStart(enabled: Bool) -> Bool {
        return SMLoginItemSetEnabled(helperAppId as CFString, enabled)
    }
}
