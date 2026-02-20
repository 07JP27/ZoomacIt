import AppKit

/// A borderless, transparent window that sits above all other windows
/// and captures input for Draw mode.
final class OverlayWindow: NSWindow {

    convenience init(for screen: NSScreen) {
        self.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .init(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = false
    }

    // MARK: - Overrides

    /// Allow the window to become key so it can receive keyboard events.
    override var canBecomeKey: Bool { true }

    /// Allow the window to become main.
    override var canBecomeMain: Bool { true }
}
