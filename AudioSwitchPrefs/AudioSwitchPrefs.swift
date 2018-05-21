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
