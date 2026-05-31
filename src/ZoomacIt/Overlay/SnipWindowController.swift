import AppKit
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers

/// Controls Snip mode — capture screen, select region, copy to clipboard.
@MainActor
final class SnipWindowController {

    var onDismiss: (() -> Void)?
    var onShowFailed: (() -> Void)?
    var saveToFile: Bool = false

    private var snipWindow: OverlayWindow?
    private var snipView: SnipView?

    func showSnipOverlay() {
        NSLog("[SnipWindowController] showSnipOverlay called")
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            NSLog("[SnipWindowController] Screen Recording permission denied")
            onShowFailed?()
            return
        }
        guard let screen = NSScreen.screenContainingMouse ?? NSScreen.main else {
            onShowFailed?()
            return
        }

        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGMainDisplayID()
        let scaleFactor = screen.backingScaleFactor

        Task { @MainActor in
            do {
                let image = try await Self.captureScreen(displayID: displayID, screen: screen, scaleFactor: scaleFactor)
                self.presentOverlay(on: screen, image: image, scaleFactor: scaleFactor)
            } catch {
                NSLog("[SnipWindowController] Capture failed: %@", error.localizedDescription)
                self.onShowFailed?()
            }
        }
    }

    func dismiss() {
        snipWindow?.orderOut(nil)
        snipWindow?.close()
        snipWindow = nil
        snipView = nil
        onDismiss?()
    }

    private func presentOverlay(on screen: NSScreen, image: CGImage, scaleFactor: CGFloat) {
        let window = OverlayWindow(for: screen)
        let view = SnipView(frame: NSRect(origin: .zero, size: screen.frame.size),
                            sourceImage: image, scaleFactor: scaleFactor)

        view.onDismiss = { [weak self] in
            self?.dismiss()
        }
        view.onSnip = { [weak self] croppedImage in
            if self?.saveToFile == true {
                Self.saveToDesktop(croppedImage)
                NSLog("[SnipWindowController] Snip saved to Desktop")
            } else {
                Self.copyToClipboard(croppedImage)
                NSLog("[SnipWindowController] Snip copied to clipboard")
            }
            self?.dismiss()
        }

        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        NSApplication.shared.activate(ignoringOtherApps: true)

        snipWindow = window
        snipView = view
    }

    private static func copyToClipboard(_ image: CGImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let size = NSSize(width: CGFloat(image.width) / (NSScreen.main?.backingScaleFactor ?? 2.0),
                          height: CGFloat(image.height) / (NSScreen.main?.backingScaleFactor ?? 2.0))
        let nsImage = NSImage(cgImage: image, size: size)
        pasteboard.writeObjects([nsImage])
    }

    private static func saveToDesktop(_ image: CGImage) {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = desktop.appendingPathComponent("ZoomacIt-\(timestamp).png")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
        showSaveNotification(image: image, url: url)
    }

    private static func showSaveNotification(image: CGImage, url: URL) {
        guard let screen = NSScreen.main else { return }
        let thumbSize: CGFloat = 160
        let padding: CGFloat = 20
        let frame = NSRect(
            x: screen.visibleFrame.maxX - thumbSize - padding,
            y: screen.visibleFrame.minY + padding,
            width: thumbSize,
            height: thumbSize
        )

        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = true
        window.isReleasedWhenClosed = false

        let clickView = SnipThumbnailView(frame: NSRect(origin: .zero, size: frame.size), image: image, fileURL: url)
        clickView.onClose = { window.close() }

        window.contentView = clickView
        window.orderFrontRegardless()

        // Thumbnail fades out after 4 seconds; click to reveal in Finder
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.5
                window.animator().alphaValue = 0
            }, completionHandler: {
                window.close()
            })
        }
    }

    private static func captureScreen(displayID: CGDirectDisplayID, screen: NSScreen, scaleFactor: CGFloat) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw NSError(domain: "Snip", code: 1, userInfo: [NSLocalizedDescriptionKey: "Display not found"])
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(screen.frame.width * scaleFactor)
        config.height = Int(screen.frame.height * scaleFactor)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
}

// MARK: - Clickable Thumbnail

private final class SnipThumbnailView: NSView {
    var onClose: (() -> Void)?
    private let fileURL: URL

    init(frame: NSRect, image: CGImage, fileURL: URL) {
        self.fileURL = fileURL
        super.init(frame: frame)
        wantsLayer = true
        layer?.contents = image
        layer?.contentsGravity = .resizeAspect
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        layer?.borderColor = NSColor.white.withAlphaComponent(0.8).cgColor
        layer?.borderWidth = 2
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        onClose?()
    }
}
