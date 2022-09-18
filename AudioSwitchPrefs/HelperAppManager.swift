// Copyright 2018-2022 Vincent Duvert.
// Distributed under the terms of the MIT License.

import AppKit
import ServiceManagement

/// Manages the helper application as a service.
protocol HelperAppManager: AnyObject {
    /// Checks the running status of the helper.
    /// Returns true iff the helper is running
    func getRunningStatus() -> Bool

    /// Sets the running status of the helper; calls the completion callback when it is done.
    /// getRunningStatus will be called afterwards to update the actual status.
    /// The call can display error messages, using the parent window parameter. The completion callback should be called when the error message is dismissed.
    func setRunningStatus(parentWindow: NSWindow, newStatus: Bool, completion: @escaping () -> Void)
}


/// Return either the classic helper manager (macOS 12-) or the new manager (macOS 13+)
func getHelperManager() -> HelperAppManager {
    if #available(macOS 13.0, *) {
        return HelperAppManagerModern()
    } else {
        return HelperAppManagerClassic()
    }
}


/// Manages the helper application installation as a service (classic manager)
final class HelperAppManagerClassic: HelperAppManager {
    /// Bundle ID of the helper application
    private let helperAppId: String
    
    init() {
        guard let appId = Bundle.main.object(forInfoDictionaryKey: "HelperApp") as? String else {
            fatalError("HelperApp missing in info plist")
        }
        
        helperAppId = appId
    }

    func getRunningStatus() -> Bool {
        var persistence: DarwinBoolean = false
        let loaded = SMJobIsEnabled(kSMDomainUserLaunchd, helperAppId as CFString, &persistence) != 0

        if persistence.boolValue != loaded {
            // Service disabled
            return false
        }

        // Service enabled and running
        return true
    }

    func setRunningStatus(parentWindow: NSWindow, newStatus: Bool, completion: @escaping () -> Void) {
        if (SMLoginItemSetEnabled(helperAppId as CFString, newStatus)) {
            completion()
            return
        }

        let alert = NSAlert()
        if newStatus {
            alert.messageText = NSLocalizedString("An error occurred enabling AudioSwitch.", comment: "Alert message")
        } else {
            alert.messageText = NSLocalizedString("An error occurred disabling AudioSwitch.", comment: "Alert message")
        }
        alert.addButton(withTitle: NSLocalizedString("OK", comment: "Alert button"))
        alert.beginSheetModal(for: parentWindow) {_ in
            completion()
        }
    }
}


/// Manages the helper application installation as a service (modern manager)
@available(macOS 13.0, *)
final class HelperAppManagerModern: HelperAppManager {
    /// Service manager of the helper application
    private let service: SMAppService

    init() {
        guard let appId = Bundle.main.object(forInfoDictionaryKey: "HelperApp") as? String else {
            fatalError("HelperApp missing in info plist")
        }

        service = SMAppService.loginItem(identifier: appId)
    }

    func getRunningStatus() -> Bool {
        return service.status == .enabled
    }

    func setRunningStatus(parentWindow: NSWindow, newStatus: Bool, completion: @escaping () -> Void) {
        if (newStatus) {
            switch service.status {
            case .enabled:
                // Nothing to do
                completion()
                break

            case .requiresApproval:
                let alert = NSAlert()
                alert.messageText = NSLocalizedString("AudioSwitch needs to be allowed to start.", comment:"Alert message")
                alert.informativeText = NSLocalizedString("Allow AudioSwitch in the Login Items Settings.", comment:"Alert message")
                alert.addButton(withTitle: NSLocalizedString("Open Login Items Settings", comment: "Alert button"))
                alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Alert button"))

                alert.beginSheetModal(for: parentWindow) { retCode in
                    if retCode == .alertFirstButtonReturn {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                    completion()
                }

            case .notFound:
                fallthrough
            case .notRegistered:
                fallthrough
            @unknown default:
                do {
                    try service.register()
                    completion()
                } catch {
                    let alert = NSAlert()
                    alert.messageText = NSLocalizedString("An error occurred enabling AudioSwitch.", comment: "Alert message")
                    alert.informativeText = error.localizedDescription
                    alert.addButton(withTitle: NSLocalizedString("OK", comment: "Alert button"))
                    alert.beginSheetModal(for: parentWindow) {_ in
                        completion()
                    }
                }
            }
        } else {
            if service.status == .enabled {
                do {
                    try service.unregister()
                    completion()
                } catch {
                    let alert = NSAlert()
                    alert.messageText = NSLocalizedString("An error occurred disabling AudioSwitch.", comment: "Alert message")
                    alert.informativeText = error.localizedDescription
                    alert.addButton(withTitle: NSLocalizedString("OK", comment: "Alert button"))
                    alert.beginSheetModal(for: parentWindow) {_ in
                        completion()
                    }
                }
            } else {
                // Nothing to do
                completion()
            }
        }
    }
}
