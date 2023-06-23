import SwiftUI

class FixedSizeWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return NSRect(x: frameRect.origin.x, y: frameRect.origin.y, width: 552, height: 612)
    }
}
