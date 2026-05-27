import AppKit
import CoreGraphics
import CoreMedia
import ScreenCaptureKit

/// Controls Live Zoom mode — real-time screen capture via SCStream with pan/zoom.
@MainActor
final class LiveZoomWindowController: NSObject {

    var onDismiss: (() -> Void)?
    var onEnterDrawMode: ((CGImage) -> Void)?
    var onShowFailed: (() -> Void)?

    private var zoomWindow: OverlayWindow?
    private var zoomView: LiveZoomView?
    private var stream: SCStream?
    private var streamOutput: StreamOutputHandler?

    /// Last received pixel buffer — used for Draw mode transition snapshot.
    private var lastPixelBuffer: CVPixelBuffer?
    private lazy var ciContext = CIContext()

    func showLiveZoom() {
        NSLog("[LiveZoomWindowController] showLiveZoom called")
        guard CGPreflightScreenCaptureAccess() else {
            NSLog("[LiveZoomWindowController] Screen Recording permission denied")
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
                try await self.startStream(screen: screen, displayID: displayID, scaleFactor: scaleFactor)
            } catch {
                NSLog("[LiveZoomWindowController] Failed to start stream: %@", error.localizedDescription)
                self.dismiss()
                self.onShowFailed?()
            }
        }
    }

    func dismiss() {
        stream?.stopCapture { _ in }
        stream = nil
        streamOutput = nil
        lastPixelBuffer = nil
        zoomWindow?.orderOut(nil)
        zoomWindow?.close()
        zoomWindow = nil
        zoomView = nil
        onDismiss?()
    }

    /// Snapshot the currently visible zoomed frame for Draw mode transition.
    func snapshotCurrentZoomedFrame() -> CGImage? {
        guard let buffer = lastPixelBuffer else { return nil }
        let ciImage = CIImage(cvPixelBuffer: buffer)
        guard let sourceImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return zoomView?.currentZoomedSnapshot(from: sourceImage) ?? sourceImage
    }

    // MARK: - Private

    private func startStream(screen: NSScreen, displayID: CGDirectDisplayID, scaleFactor: CGFloat) async throws {
        // Present overlay first so it exists when we query windows
        presentOverlay(on: screen, scaleFactor: scaleFactor)

        // Wait until our overlay window is visible to the window server
        var excludedWindows: [SCWindow] = []
        let myPID = ProcessInfo.processInfo.processIdentifier
        for _ in 0..<10 {
            try await Task.sleep(nanoseconds: 20_000_000) // 20ms
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            excludedWindows = content.windows.filter { $0.owningApplication?.processID == myPID }
            if !excludedWindows.isEmpty { break }
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw LiveZoomError.displayNotFound
        }

        if excludedWindows.isEmpty {
            excludedWindows = content.windows.filter { $0.owningApplication?.processID == myPID }
        }
        NSLog("[LiveZoomWindowController] Excluding %d windows from capture (pid=%d)", excludedWindows.count, myPID)

        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
        let config = SCStreamConfiguration()
        config.width = Int(screen.frame.width * scaleFactor)
        config.height = Int(screen.frame.height * scaleFactor)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.queueDepth = 3

        let outputHandler = StreamOutputHandler { [weak self] buffer in
            DispatchQueue.main.async {
                self?.handleFrame(buffer)
            }
        }
        self.streamOutput = outputHandler

        let newStream = SCStream(filter: filter, configuration: config, delegate: nil)
        let captureQueue = DispatchQueue(label: "com.zoomacit.livezoom.capture", qos: .userInteractive)
        try newStream.addStreamOutput(outputHandler, type: .screen, sampleHandlerQueue: captureQueue)
        try await newStream.startCapture()
        self.stream = newStream
        NSLog("[LiveZoomWindowController] Stream started at %dx%d @60fps", config.width, config.height)
    }

    private func presentOverlay(on screen: NSScreen, scaleFactor: CGFloat) {
        let window = OverlayWindow(for: screen)
        let view = LiveZoomView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            screenScaleFactor: scaleFactor
        )

        view.onDismiss = { [weak self] in
            self?.dismiss()
        }
        view.onEnterDrawMode = { [weak self] in
            guard let self, let snapshot = self.snapshotCurrentZoomedFrame() else { return }
            self.onEnterDrawMode?(snapshot)
        }

        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        NSApplication.shared.activate(ignoringOtherApps: true)

        zoomWindow = window
        zoomView = view
    }

    private func handleFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        lastPixelBuffer = pixelBuffer
        zoomView?.updateFrame(pixelBuffer)
    }

    private enum LiveZoomError: LocalizedError {
        case displayNotFound
        var errorDescription: String? { "Target display not found." }
    }
}

// MARK: - Stream Output Handler

private final class StreamOutputHandler: NSObject, SCStreamOutput {
    private let handler: (CMSampleBuffer) -> Void

    init(handler: @escaping (CMSampleBuffer) -> Void) {
        self.handler = handler
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        handler(sampleBuffer)
    }
}
