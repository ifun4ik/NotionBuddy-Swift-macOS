import SwiftUI
import Cocoa
import HotKey
import DSFQuickActionBar

class GlobalShortcutManager {
    static let shared = GlobalShortcutManager()
    var captureHotKey: HotKey?
    var actionBar: DSFQuickActionBar?

    private init() {}

    func setupGlobalShortcut() {
        captureHotKey = HotKey(key: .n, modifiers: [.command, .control], keyDownHandler: {
            self.showActionBar()
        })
    }

    func showActionBar() {
        if actionBar == nil {
            actionBar = DSFQuickActionBar()
        }
        actionBar?.present(parentWindow: nil, placeholderText: "Type something...", searchImage: NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: nil), initialSearchText: "")
    }
}
