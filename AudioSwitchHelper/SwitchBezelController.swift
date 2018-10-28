// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import AppKit

/// Used to set the effect view material type to the one used by the sound volume panel
@objc private protocol NSVisualEffectViewPrivateApi {
    @objc optional func _setInternalMaterialType(_ materialType: CUnsignedLongLong)
}

extension NSVisualEffectView: NSVisualEffectViewPrivateApi { }

/// Bezel panel, similar to the sound volume panel
class SwitchBezel: NSPanel {
    @objc func _backdropBleedAmount() -> Float {
        return 0.0
    }
}

/// Public interface for the bezel controller
protocol SwitchBezelControllerProtocol: AnyObject {
    func display(text: String)
}

/// Controller for the bezel panel
class SwitchBezelController: NSWindowController, SwitchBezelControllerProtocol {
    @IBOutlet weak var effectView: NSVisualEffectView!
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var textField: NSTextField!
    
    var fadeStartTimer: Timer? = nil
    var fadeEndTimer: Timer? = nil
    
    static let delayBeforeFade: TimeInterval = 1.0
    static let fadeDelay: TimeInterval = 1.0
    static let switchIcon = NSImage.Name("SwitchIcon")
    
    convenience init() {
        self.init(windowNibName: "SwitchBezel")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 20
        
        let image = NSImage(named: SwitchBezelController.switchIcon)!
        image.isTemplate = true
        imageView.image = image
    }
    
    /// Display the panel, with the specified text.
    /// If the panel is currently displayed or fading out, the display/fade-out interval is reset.
    /// - Parameter text: Text to display
    func display(text: String) {
        let window = self.window!
        
        let defaults = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)
        let style = defaults?["AppleInterfaceStyle"] as? String
        let isDark = style?.caseInsensitiveCompare("dark") == .orderedSame

        // effectView’s initial appearance should be Aqua for this code to work
        if (isDark && effectView.appearance?.name != .vibrantDark) {
            effectView.appearance = NSAppearance(named: .vibrantDark)
            effectView.material = .dark
            (effectView as NSVisualEffectViewPrivateApi)._setInternalMaterialType?(4)
        } else if (!isDark && effectView.appearance?.name != .vibrantLight) {
            effectView.appearance = NSAppearance(named: .vibrantLight)
            effectView.material = .light
            (effectView as NSVisualEffectViewPrivateApi)._setInternalMaterialType?(0)
        }
        
        let mainScreenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 640, height: 480)
        
        // The sound volume window center is 140px from the bottom of the screen. We use the same spot.
        let switchWindowLeft = (mainScreenFrame.width - window.frame.width) / 2
        let switchWindowBottom: CGFloat = 140
        window.setFrameOrigin(NSPoint(x: switchWindowLeft, y: switchWindowBottom))
        
        textField.stringValue = text
        
        fadeStartTimer?.invalidate()
        fadeEndTimer?.invalidate()
        
        fadeStartTimer = Timer.scheduledTimer(withTimeInterval: SwitchBezelController.delayBeforeFade, repeats: false) { [unowned self] _ in
            self.fadeStartTimer = nil
            
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = SwitchBezelController.fadeDelay
                self.window?.animator().alphaValue = 0.0
            })
            
            // This code needs to run at the end of the animation, but can not use the animator completion
            // handler because it needs to be able to be cancelled
            self.fadeEndTimer = Timer.scheduledTimer(withTimeInterval: SwitchBezelController.fadeDelay, repeats: false) { [unowned self] _ in
                self.fadeEndTimer = nil
                self.window?.orderOut(nil)
            }
        }
        
        window.alphaValue = 1.0
        window.setIsVisible(true)
    }
}
