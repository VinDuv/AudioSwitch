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
    
    /// Handle of the helper if it is launched (nil if it is not)
    private var helperAppHandle: NSRunningApplication?
    
    /// Launched applications observer
    private var launchedObserver: NSKeyValueObservation?
    
    /// Delegate called when the state changes. The delegate will be called on initialization
    weak var delegate: HelperAppManagerDelegate? {
        didSet {
            launchedObserver?.invalidate()
            helperAppHandle = nil
            if delegate == nil {
                return
            }
            
            launchedObserver = NSWorkspace.shared.observe(\.runningApplications, options: [.old, .new, .initial]) { [unowned self] (_, change) in
                
                if change.oldValue?.contains(where: { $0.bundleIdentifier == self.helperAppId } ) ?? false {
                    self.helperAppHandle = nil
                    self.delegate?.helperApp(started: false)
                }
                
                if let launchedApp = change.newValue?.first(where: { $0.bundleIdentifier == self.helperAppId } ) {
                    self.helperAppHandle = launchedApp
                    self.delegate?.helperApp(started: true)
                }
            }
            
            // If the app was running during the .observe call, the callback has been called and helperAppHandle
            // set to non-nil. If it wasn't running, the callbac was not call so we need to call it now.
            if self.helperAppHandle == nil {
                self.delegate?.helperApp(started: false)
            }
        }
    }
    
    init() {
        guard let appId = Bundle.main.object(forInfoDictionaryKey: "HelperApp") as? String else {
            fatalError("HelperApp missing in info plist")
        }
        
        helperAppId = appId
    }
    
    /// Start the helper app if it not running, stops it if it is currently running.
    /// The helper app must reside in the Contents/Library/LoginItems of the app bundle,
    /// and be named <last part of bundle ID>.app.
    func toggleHelperState() {
        if helperAppHandle != nil {
            FileManager.default.createFile(atPath: QuitFlag.quitFlagFullPath.path, contents: nil, attributes: [:])
            return
        }
        
        let afterDotIndex = helperAppId.lastIndex(of: ".").map {helperAppId.index(after: $0) } ?? helperAppId.startIndex
        let appName = helperAppId[afterDotIndex...]
        let helperPath = NSString.path(withComponents: [Bundle.main.bundlePath, "Contents", "Library", "LoginItems", "\(appName).app"])
        
        NSWorkspace.shared.openFile(helperPath)
    }
}
