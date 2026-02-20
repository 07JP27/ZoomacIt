import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController?
    private var hotkeyManager: HotkeyManager { HotkeyManager.shared }
    private var overlayController: OverlayWindowController?
    private var breakTimerController: BreakTimerWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[AppDelegate] applicationDidFinishLaunching")
        statusBarController = StatusBarController()
        hotkeyManager.onDrawHotkey = { [weak self] in
            self?.toggleDrawMode()
        }
        hotkeyManager.onBreakHotkey = { [weak self] in
            self?.toggleBreakTimer()
        }
        hotkeyManager.start()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    // MARK: - Draw Mode

    private func toggleDrawMode() {
        if let controller = overlayController {
            controller.dismiss()
            overlayController = nil
        } else {
            let controller = OverlayWindowController()
            controller.showOverlay()
            overlayController = controller
        }
    }

    /// Called from OverlayWindowController when the user exits draw mode (Escape / right-click)
    func drawModeDidEnd() {
        overlayController = nil
    }

    // MARK: - Break Timer

    private func toggleBreakTimer() {
        if let controller = breakTimerController {
            controller.dismiss()
            breakTimerController = nil
        } else {
            let controller = BreakTimerWindowController()
            controller.showTimer()
            breakTimerController = controller
        }
    }

    /// Called from BreakTimerWindowController when the timer is dismissed.
    func breakTimerDidEnd() {
        breakTimerController = nil
    }
}
