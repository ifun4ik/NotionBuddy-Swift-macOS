import Cocoa
import SwiftUI

class CaptureWindowController: NSWindowController {
    var eventMonitor: Any?

    override func windowDidLoad() {
        super.windowDidLoad()
        
        window?.setFrame(NSRect(x: 0, y: 0, width: 480, height: 1500), display: false)
        positionWindowNearTop()
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self = self else { return event }
            if event.keyCode == 53 { // Esc key
                self.closeWindow()
                return nil
            }
            return event
        }
        
        // New code: This should focus the text field if this window becomes key
        DispatchQueue.main.async {
            self.focusTextField()
        }
    }
    
    // New Method: To focus the text field
    func focusTextField() {
        if let textField = findFirstResponder(in: window?.contentView) {
            window?.makeFirstResponder(textField)
        }
    }
    
    // New Method: Recursive function to find the NSTextField in the view hierarchy
    private func findFirstResponder(in view: NSView?) -> NSView? {
        guard let view = view else { return nil }
        for subview in view.subviews {
            if subview is NSTextField {
                return subview
            }
            if let firstResponder = findFirstResponder(in: subview) {
                return firstResponder
            }
        }
        return nil
    }
    
    func positionWindowNearTop() {
        guard let screen = NSScreen.main, let window = self.window else { return }

        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame

        let newOriginX = (screenFrame.width - windowFrame.width) / 2 + screenFrame.minX
        let newOriginY = screenFrame.maxY - 120 // Leave more space at the top

        window.setFrameTopLeftPoint(NSPoint(x: newOriginX, y: newOriginY))
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.setFrame(NSRect(x: 0, y: 0, width: 480, height: 1500), display: false)
        positionWindowNearTop()
    }

    func closeWindow() {
        self.window?.close()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitor = nil
    }
    
    func setupEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self = self else { return event }
            if event.keyCode == 53 { // Esc key
                self.closeWindow()
                return nil
            }
            return event
        }
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
