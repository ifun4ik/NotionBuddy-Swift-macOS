
import HotKey
import Cocoa
import SwiftUI

class GlobalShortcutManager {
    static let shared = GlobalShortcutManager()
    var captureHotKey: HotKey?

    private init() {}

    func setupGlobalShortcut() {
        captureHotKey = HotKey(key: .n, modifiers: [.command, .control], keyDownHandler: {
            showCaptureWindow()
        })
    }
}

func showCaptureWindow() {
    DispatchQueue.main.async {
        let captureView = CaptureView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.setFrameAutosaveName("Capture Window")
        window.contentView = NSHostingView(rootView: captureView)
        window.makeKeyAndOrderFront(nil)
        window.level = .floating

        // Listen for Esc key to close the window
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc key
                window.close()
                return nil
            }
            return event
        }
    }
}
