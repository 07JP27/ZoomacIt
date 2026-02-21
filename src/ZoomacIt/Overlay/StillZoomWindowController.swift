import AppKit
import CoreGraphics
import ScreenCaptureKit

/// Controls Still Zoom mode (single screenshot + contentsRect based pan/zoom).
@MainActor
final class StillZoomWindowController {

    var onDismiss: (() -> Void)?
    var onEnterDrawMode: ((CGImage) -> Void)?
    /// Called when the overlay could not be shown (e.g. permission denied).
    var onShowFailed: (() -> Void)?

    private var zoomWindow: OverlayWindow?
    private var zoomView: StillZoomView?

    private(set) var sourceImage: CGImage?

    func showZoomOverlay() {
        NSLog("[StillZoomWindowController] showZoomOverlay called")
        guard let screen = NSScreen.screenContainingMouse ?? NSScreen.main else {
            NSLog("[StillZoomWindowController] No screen found")
            onShowFailed?()
            return
        }

        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGMainDisplayID()
        let scaleFactor = screen.backingScaleFactor
        NSLog("[StillZoomWindowController] Screen: %@, displayID=%d, scale=%.1f", screen.localizedName, displayID, scaleFactor)

        Task { @MainActor in
            NSLog("[StillZoomWindowController] Starting screen capture via ScreenCaptureKit...")
            do {
                let captured = try await Self.captureScreen(
                    displayID: displayID,
                    width: screen.frame.width,
                    height: screen.frame.height,
                    scaleFactor: scaleFactor
                )
                NSLog("[StillZoomWindowController] Capture succeeded: %dx%d", captured.width, captured.height)
                self.sourceImage = captured
                self.presentOverlay(on: screen, image: captured, scaleFactor: scaleFactor)
            } catch {
                NSLog("[StillZoomWindowController] Screen capture failed: %@", error.localizedDescription)
                self.showPermissionAlert()
                self.onShowFailed?()
            }
        }
    }

    func dismiss() {
        zoomWindow?.orderOut(nil)
        zoomWindow?.close()
        zoomWindow = nil
        zoomView = nil
        sourceImage = nil
        onDismiss?()
    }

    func snapshotImageForDrawTransition() -> CGImage? {
        zoomView?.currentZoomedSnapshot() ?? sourceImage
    }

    private func presentOverlay(on screen: NSScreen, image: CGImage, scaleFactor: CGFloat) {
        let window = OverlayWindow(for: screen)
        let view = StillZoomView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            sourceImage: image,
            initialZoomLevel: 2.0,
            screenScaleFactor: scaleFactor
        )

        view.onDismiss = { [weak self] in
            self?.dismiss()
        }

        view.onEnterDrawMode = { [weak self] zoomedSnapshot in
            self?.dismiss()
            self?.onEnterDrawMode?(zoomedSnapshot)
        }

        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)

        NSApplication.shared.activate(ignoringOtherApps: true)

        zoomWindow = window
        zoomView = view
        NSLog("[StillZoomWindowController] Zoom overlay presented.")
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "ZoomacIt needs Screen Recording permission to capture the screen for Zoom mode.\n\nPlease enable it in System Settings → Privacy & Security → Screen Recording, then try again."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Screen Capture

    private static func captureScreen(
        displayID: CGDirectDisplayID,
        width: CGFloat,
        height: CGFloat,
        scaleFactor: CGFloat
    ) async throws -> CGImage {
        let availableContent = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true
        )
        guard let display = availableContent.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.displayNotFound
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(width * scaleFactor)
        config.height = Int(height * scaleFactor)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false

        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
    }

    private enum CaptureError: LocalizedError {
        case displayNotFound

        var errorDescription: String? {
            switch self {
            case .displayNotFound: return "Target display not found."
            }
        }
    }
}
