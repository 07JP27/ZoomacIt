import AppKit
import CoreGraphics
import CoreVideo
import ScreenCaptureKit

/// Manages the lifecycle of the overlay window used for Draw mode.
@MainActor
final class OverlayWindowController {

    private var overlayWindow: OverlayWindow?
    private var canvasView: DrawingCanvasView?

    /// The captured screen image at the moment Draw mode was activated.
    private var screenCapture: CGImage?

    // MARK: - Public

    func showOverlay() {
        guard let screen = NSScreen.main else { return }

        let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGMainDisplayID()
        let scaleFactor = screen.backingScaleFactor
        let screenFrame = screen.frame

        Task { @MainActor in
            let captured = await Self.captureScreenImage(
                displayID: screenNumber,
                width: screenFrame.width,
                height: screenFrame.height,
                scaleFactor: scaleFactor
            )
            self.screenCapture = captured
            self.presentOverlay(screen: screen, backgroundImage: captured)
        }
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

        // Change cursor for drawing
        NSCursor.crosshair.push()
    }

    func dismiss() {
        NSCursor.pop()
        overlayWindow?.orderOut(nil)
        overlayWindow?.close()
        overlayWindow = nil
        canvasView = nil
        screenCapture = nil

        // Notify the app delegate
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.drawModeDidEnd()
        }
    }

    // MARK: - Screen Capture

    private static func captureScreenImage(
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
