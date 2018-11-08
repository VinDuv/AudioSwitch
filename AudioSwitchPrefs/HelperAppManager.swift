// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import AppKit

/// Delegate protocol for the helper watcher
protocol HelperAppManagerDelegate: AnyObject {
    /// Called when the helper application is started or stopped
    func helperApp(started: Bool)
}

/// Manages the helper application
final class HelperAppManager {
    /// Bundle ID of the helper application
    private let helperAppId: String
    
    /// Indicates if the helper is currently launched (nil if unknown)
    private(set) var helperLaunched: Bool?
    
    /// Launched applications observer
    private var launchedObserver: NSKeyValueObservation?
    
    /// Delegate called when the state changes. The delegate will be called on initialization
    weak var delegate: HelperAppManagerDelegate? {
        didSet {
            launchedObserver?.invalidate()
            helperLaunched = nil
            if delegate == nil {
                return
            }
            
            launchedObserver = NSWorkspace.shared.observe(\.runningApplications, options: [.old, .new, .initial]) { [unowned self] (_, change) in
                if let launchedApps = change.newValue, self.helperLaunched != true && launchedApps.contains { $0.bundleIdentifier == self.helperAppId } {
                    self.helperLaunched = true
                    self.delegate?.helperApp(started: true)
                    return
                }
                
                if let quittedApps = change.oldValue, self.helperLaunched != false && quittedApps.contains { $0.bundleIdentifier == self.helperAppId } {
                    self.helperLaunched = false
                    self.delegate?.helperApp(started: false)
                    return
                }
                
                if self.helperLaunched == nil {
                    self.helperLaunched = false
                    self.delegate?.helperApp(started: false)
                }
            }
        }
    }
    
    init() {
        guard let appId = Bundle.main.object(forInfoDictionaryKey: "HelperApp") as? String else {
            fatalError("HelperApp missing in info plist")
        }
        
        helperAppId = appId
    }
}
