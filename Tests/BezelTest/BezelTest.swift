// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import Cocoa

/// A view that displays two colors side by side
final class ColorView: NSView {
    static private let colors : [(NSColor, NSColor)] = [
        (.white, .white),
        (.black, .black),
        (.white, .black),
        (.windowBackgroundColor, .windowBackgroundColor),
        (.green, .green),
    ]
    
    var colorIndex = colors.startIndex
    
    override var isOpaque: Bool { return true }
    
    override func draw(_ dirtyRect: NSRect) {
        let (leftPart, rightPart) = self.bounds.divided(atDistance: self.bounds.width / 2, from: .minXEdge)
        let (leftColor, rightColor) = ColorView.colors[colorIndex]
        
        leftColor.setFill()
        NSBezierPath.fill(leftPart.intersection(dirtyRect))
        
        rightColor.setFill()
        NSBezierPath.fill(rightPart.intersection(dirtyRect))
    }
    
    @IBAction
    func switchColor(sender: Any) {
        colorIndex = ColorView.colors.index(after: colorIndex)
        if colorIndex == ColorView.colors.endIndex {
            colorIndex = ColorView.colors.startIndex
        }
        needsDisplay = true
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var colorView: ColorView!
    @IBOutlet weak var titleField: NSTextField!
    
    var switchBezelController = SwitchBezelController()
    
    /// Window position so the color view is under the bezel
    private var windowUnderBezelPosition: NSPoint {
        // The bezel window is 200x200pt, 140pt from the bottom of the screen, vertically centerd.
        // Since the color view is 220x220pt, it needs to be at 130pt from the bottom of the screen, vertically centered.
        
        let mainScreenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 640, height: 480)
        
        let colorViewScreenLeft = (mainScreenFrame.width - colorView.frame.width) / 2
        let colorViewScreenBottom: CGFloat = 130
        
        let colorViewWindowPosition = colorView.frame.origin
        
        let windowScreenLeft = colorViewScreenLeft - colorViewWindowPosition.x
        let windowScreenBottom = colorViewScreenBottom - colorViewWindowPosition.y
        
        return NSPoint(x: windowScreenLeft, y: windowScreenBottom)
    }
    
    @IBAction func displayBezel(_ sender: Any) {
        switchBezelController.display(text: titleField.stringValue)
    }

    @IBAction func positionWindow(_ sender: Any) {
        window.setFrame(NSRect(origin: windowUnderBezelPosition, size: window.frame.size), display: false, animate: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

