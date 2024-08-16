import HotKey
import Cocoa
import SwiftUI

class GlobalShortcutManager {
    static let shared = GlobalShortcutManager()
    private var sessionManager: SessionManager?
    private var captureHotKey: HotKey?
    private var captureWindowController: CaptureWindowController?

    private init() {}

    func setupGlobalShortcut(sessionManager: SessionManager) {
        print("Setting up global shortcut with SessionManager")
        self.sessionManager = sessionManager
        captureHotKey = HotKey(key: .n, modifiers: [.command, .control]) { [weak self] in
            print("Hotkey pressed")
            self?.handleHotKeyPress()
        }
    }

    
    private func handleHotKeyPress() {
        print("Handling hotkey press")
        Task { @MainActor in
            print("Refreshing accounts")
            await sessionManager?.refreshAccountsAsync()
            print("Showing capture window")
            self.showCaptureWindow()
        }
    }
    
    @MainActor
    private func showCaptureWindow() {
        print("Attempting to show capture window")
        guard let sessionManager = sessionManager else {
            print("SessionManager not set in GlobalShortcutManager")
            return
        }

        print("Accounts in SessionManager: \(sessionManager.accounts)")
        print("Selected account index: \(sessionManager.selectedAccountIndex)")

        guard let currentAccount = sessionManager.currentAccount else {
            print("No valid account selected")
            let alert = NSAlert()
            alert.messageText = "No Valid Account"
            alert.informativeText = "Please add a Notion account in the main window before using the quick capture feature."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        let accessToken = currentAccount.accessToken
        
        // Create and show the CaptureView
        let context = PersistenceController.shared.container.viewContext
        let captureView = CaptureView(accessToken: accessToken)
            .environment(\.managedObjectContext, context)

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
            let yPos = screenRect.origin.y + (screenRect.height) / 2
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
