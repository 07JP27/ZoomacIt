import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController?
    private var hotkeyManager: HotkeyManager { HotkeyManager.shared }
    private var overlayController: OverlayWindowController?
    private var zoomController: StillZoomWindowController?
    private var breakTimerController: BreakTimerWindowController?
    /// Stores the full-resolution source image when transitioning from Zoom → Draw,
    /// so that Escape from Draw can return to Zoom mode.
    private var zoomSourceForDrawReturn: CGImage?
    private var zoomPanCenterForDrawReturn: CGPoint?
    private var zoomLevelForDrawReturn: CGFloat?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[AppDelegate] applicationDidFinishLaunching")
        statusBarController = StatusBarController()
        hotkeyManager.onZoomHotkey = { [weak self] in
            self?.toggleStillZoomMode()
        }
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
        if let zoomController {
            let captured = zoomController.snapshotImageForDrawTransition()
            self.zoomSourceForDrawReturn = zoomController.sourceImage
            zoomController.dismiss()
            self.zoomPanCenterForDrawReturn = zoomController.lastPanCenter
            self.zoomLevelForDrawReturn = zoomController.lastZoomLevel
            self.zoomController = nil
            presentDrawMode(backgroundImage: captured)
            return
        }

        if let controller = overlayController {
            zoomSourceForDrawReturn = nil  // ⌃2 toggle = full exit, don't return to zoom
            controller.dismiss()
            overlayController = nil
        } else {
            presentDrawMode(backgroundImage: nil)
        }
    }

    private func presentDrawMode(backgroundImage: CGImage?) {
        let controller = OverlayWindowController(backgroundImageOverride: backgroundImage)
        controller.showOverlay()
        overlayController = controller
    }

    /// Called from OverlayWindowController when the user exits draw mode (Escape / right-click)
    func drawModeDidEnd() {
        overlayController = nil
        if let savedImage = zoomSourceForDrawReturn {
            zoomSourceForDrawReturn = nil
            restoreZoomMode(withImage: savedImage)
        }
    }

    // MARK: - Still Zoom

    private func toggleStillZoomMode() {
        NSLog("[AppDelegate] toggleStillZoomMode called")
        if let controller = zoomController {
            NSLog("[AppDelegate] Zoom already active — dismissing")
            controller.dismiss()
            zoomController = nil
            return
        }

        if let drawController = overlayController {
            NSLog("[AppDelegate] Draw active — dismissing before zoom")
            zoomSourceForDrawReturn = nil  // switching to fresh zoom, don't restore
            drawController.dismiss()
            overlayController = nil
        }

        let controller = StillZoomWindowController()
        setupZoomCallbacks(controller)
        controller.showZoomOverlay()
        zoomController = controller
        NSLog("[AppDelegate] zoomController assigned")
    }

    private func setupZoomCallbacks(_ controller: StillZoomWindowController) {
        controller.onDismiss = { [weak self] in
            NSLog("[AppDelegate] Zoom onDismiss callback")
            self?.zoomController = nil
        }
        controller.onEnterDrawMode = { [weak self] snapshot in
            guard let self else { return }
            NSLog("[AppDelegate] Zoom -> Draw transition")
            self.zoomSourceForDrawReturn = self.zoomController?.sourceImage
            self.zoomController?.dismiss()
            self.zoomPanCenterForDrawReturn = self.zoomController?.lastPanCenter
            self.zoomLevelForDrawReturn = self.zoomController?.lastZoomLevel
            self.zoomController = nil
            self.presentDrawMode(backgroundImage: snapshot)
        }
        controller.onShowFailed = { [weak self] in
            NSLog("[AppDelegate] Zoom show failed (permission denied?)")
            self?.zoomController = nil
        }
    }

    private func restoreZoomMode(withImage source: CGImage) {
        NSLog("[AppDelegate] Restoring zoom mode from Draw")
        let controller = StillZoomWindowController()
        setupZoomCallbacks(controller)
        controller.showZoomOverlay(
            withCapturedImage: source,
            panCenter: zoomPanCenterForDrawReturn,
            zoomLevel: zoomLevelForDrawReturn
        )
        zoomController = controller
        zoomPanCenterForDrawReturn = nil
        zoomLevelForDrawReturn = nil
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
