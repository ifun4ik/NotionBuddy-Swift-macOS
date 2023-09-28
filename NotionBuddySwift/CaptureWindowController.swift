import HotKey
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

