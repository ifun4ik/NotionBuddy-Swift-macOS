import Cocoa
import SwiftUI

class CaptureWindowController: NSWindowController, NSWindowDelegate {
    var eventMonitor: Any?

    override func windowDidLoad() {
        super.windowDidLoad()
        
        window?.delegate = self
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
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        focusTextField()
    }
    
    func focusTextField() {
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.window else { return }
            if let firstResponder = window.firstResponder as? NSTextView,
               firstResponder.isDescendant(of: window.contentView!) {
                return // TextField is already focused
            }
            window.makeFirstResponder(nil) // Reset first responder
            if let hostingView = window.contentView?.subviews.first as? NSHostingView<CaptureView> {
                hostingView.rootView.focusFirstTextField()
            }
        }
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
