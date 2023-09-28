
import HotKey
import Cocoa
import SwiftUI

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
        let captureView = CaptureView()
        let window = CustomWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let xPos = (screenRect.width - 480) / 2
            let yPos = (screenRect.height - 200) / 2
            window.setFrameOrigin(NSPoint(x: xPos, y: yPos))
        }

        captureWindowController = CaptureWindowController(window: window)
        captureWindowController?.setupEventMonitor()
        window.contentView = NSHostingView(rootView: captureView)
        window.makeKeyAndOrderFront(nil)
        window.level = .floating
        captureWindowController?.showWindow(nil)
    }
}
