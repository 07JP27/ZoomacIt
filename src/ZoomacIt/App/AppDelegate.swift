import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController?
    private var hotkeyManager: HotkeyManager { HotkeyManager.shared }
    private var permissionManager: PermissionManager { PermissionManager.shared }
    private var overlayController: OverlayWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[AppDelegate] applicationDidFinishLaunching")
        statusBarController = StatusBarController()
        hotkeyManager.onDrawHotkey = { [weak self] in
            self?.toggleDrawMode()
        }
        hotkeyManager.start()

        // Request Screen Recording permission if needed
        permissionManager.requestRequiredPermissions()
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
}
