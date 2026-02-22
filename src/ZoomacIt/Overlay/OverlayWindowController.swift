import AppKit
import CoreGraphics
import CoreVideo
import ScreenCaptureKit

/// Manages the lifecycle of the overlay window used for Draw mode.
@MainActor
final class OverlayWindowController {

    private var overlayWindow: OverlayWindow?
    private var canvasView: DrawingCanvasView?
    private let backgroundImageOverride: CGImage?

    init(backgroundImageOverride: CGImage? = nil) {
        self.backgroundImageOverride = backgroundImageOverride
    }

    // MARK: - Public

    func showOverlay() {
        guard let screen = NSScreen.screenContainingMouse ?? NSScreen.main else { return }

        if let backgroundImageOverride {
            // Zoom → Draw transition: use the frozen zoomed snapshot as background
            self.presentOverlay(screen: screen, backgroundImage: backgroundImageOverride)
            return
        }

        // Direct Draw entry (⌃2): transparent canvas over live desktop — no capture needed.
        // OverlayWindow is already isOpaque=false / backgroundColor=.clear,
        // so the desktop shows through when DrawingCanvasView draws nothing for the background.
        self.presentOverlay(screen: screen, backgroundImage: nil)
    }

    private func presentOverlay(screen: NSScreen, backgroundImage: CGImage?) {
        let window = OverlayWindow(for: screen)
        let canvas = DrawingCanvasView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            backgroundImage: backgroundImage
        )
        canvas.onDismiss = { [weak self] in
            self?.dismiss()
        }

        window.contentView = canvas
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(canvas)

        // Ensure the app is active so the window receives events
        NSApplication.shared.activate(ignoringOtherApps: true)

        overlayWindow = window
        canvasView = canvas
    }

    func dismiss() {
        overlayWindow?.orderOut(nil)
        overlayWindow?.close()
        overlayWindow = nil
        canvasView = nil

        // Notify the app delegate
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.drawModeDidEnd()
        }
    }

    // MARK: - Screen Capture

    static func captureScreenImage(
        displayID: CGDirectDisplayID,
        width: CGFloat,
        height: CGFloat,
        scaleFactor: CGFloat
    ) async -> CGImage? {
        guard CGPreflightScreenCaptureAccess() else {
            NSLog("[OverlayWindowController] Screen Recording not permitted — using blank background.")
            return nil
        }

        do {
            let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = availableContent.displays.first(where: { $0.displayID == displayID }) else {
                NSLog("[OverlayWindowController] Display not found.")
                return nil
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
        } catch {
            NSLog("[OverlayWindowController] Screen capture failed: %@", error.localizedDescription)
            return nil
        }
    }
}
