import Cocoa
import SwiftUI

class CaptureWindowController: NSWindowController {
    var eventMonitor: Any?

    override func windowDidLoad() {
        super.windowDidLoad()
        
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
