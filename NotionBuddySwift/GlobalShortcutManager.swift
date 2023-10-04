import HotKey
import Cocoa
import SwiftUI

class GlobalShortcutManager {
    static let shared = GlobalShortcutManager()
    var captureHotKey: HotKey?
    var captureWindowController: CaptureWindowController?

    private init() {}

    func setupGlobalShortcut() {
        captureHotKey = HotKey(key: .n, modifiers: [.command, .control], keyDownHandler: {
            self.showCaptureWindow()
        })
    }

    func showCaptureWindow() {
        DispatchQueue.main.async {
            let captureView = CaptureView()
            let window = CustomWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 200),
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.backgroundColor = .clear
            
            if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) {
                let screenRect = screen.visibleFrame
                let xPos = screenRect.origin.x + (screenRect.width - 480) / 2
                let yPos = screenRect.origin.y + (screenRect.height - 200) / 2
                window.setFrameOrigin(NSPoint(x: xPos, y: yPos))
            }
            
            self.captureWindowController = CaptureWindowController(window: window)
            self.captureWindowController?.setupEventMonitor()
            window.contentView = NSHostingView(rootView: captureView)
            window.orderFrontRegardless()
            window.level = .floating
            window.animator().hasShadow = true
            window.animator().alphaValue = 1
            self.captureWindowController?.showWindow(nil)
            
            // Bring the app to the front
            NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
        }
    }


}
