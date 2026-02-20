import AppKit

/// A borderless, full-screen window used to display the Break Timer.
/// Uses `.screenSaver` level so it appears above the Draw overlay.
/// Mouse events pass through to the underlying application.
final class BreakTimerWindow: NSWindow {

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
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = false
        ignoresMouseEvents = true
    }

    // MARK: - Overrides

    /// Allow the window to become key so it can receive keyboard events.
    override var canBecomeKey: Bool { true }

    /// Allow the window to become main.
    override var canBecomeMain: Bool { true }
}
