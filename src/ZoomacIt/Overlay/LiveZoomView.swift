import AppKit
import CoreGraphics
import CoreVideo
import IOSurface

/// Renders live SCStream frames as a zoomable/pannable full-screen view.
final class LiveZoomView: NSView {

    var onDismiss: (() -> Void)?
    var onEnterDrawMode: (() -> Void)?

    private let screenScaleFactor: CGFloat
    private(set) var zoomLevel: CGFloat
    private let targetInitialZoom: CGFloat
    private let minimumZoom: CGFloat = 1.0
    private let maximumZoom: CGFloat = 8.0

    /// Pan center in source pixel space.
    private(set) var panCenter: CGPoint = .zero
    private var imageSize: CGSize = .zero
    private var visibleContentsRect: CGRect = .zero
    private var hasReceivedFirstFrame = false
    private var entryAnimationState: EntryAnimationState = .pending

    private enum EntryAnimationState {
        case pending
        case running
        case completed
    }

    init(frame: NSRect, screenScaleFactor: CGFloat) {
        self.screenScaleFactor = screenScaleFactor
        self.targetInitialZoom = ZoomMath.clampZoomLevel(
            Settings.shared.defaultZoomLevel,
            minimum: minimumZoom,
            maximum: maximumZoom
        )
        self.zoomLevel = 1.0
        super.init(frame: frame)
        wantsLayer = true
        layer?.contentsGravity = .resizeAspectFill
        layer?.magnificationFilter = .linear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Frame Updates

    func updateFrame(_ pixelBuffer: CVPixelBuffer) {
        let w = CVPixelBufferGetWidth(pixelBuffer)
        let h = CVPixelBufferGetHeight(pixelBuffer)
        let frameSize = CGSize(width: w, height: h)

        let isFirstFrame = !hasReceivedFirstFrame
        if !hasReceivedFirstFrame {
            imageSize = frameSize
            let mouse = NSEvent.mouseLocation
            let screen = window?.screen ?? NSScreen.main!
            let mouseInView = CGPoint(
                x: mouse.x - screen.frame.origin.x,
                y: mouse.y - screen.frame.origin.y
            )
            panCenter = CGPoint(
                x: mouseInView.x * screenScaleFactor,
                y: mouseInView.y * screenScaleFactor
            )
            hasReceivedFirstFrame = true
        } else if imageSize != frameSize {
            imageSize = frameSize
            updateContentsRect()
        }

        // Extract IOSurface for zero-copy GPU rendering
        if let surface = CVPixelBufferGetIOSurface(pixelBuffer) {
            layer?.contents = surface.takeUnretainedValue()
        }

        if isFirstFrame {
            updateContentsRect()
        }

        if isFirstFrame {
            animateInitialZoom()
        }
    }

    // MARK: - Input

    override func mouseMoved(with event: NSEvent) {
        cancelEntryAnimationForUserInteraction()
        let location = convert(event.locationInWindow, from: nil)
        panCenter = CGPoint(
            x: location.x * screenScaleFactor,
            y: location.y * screenScaleFactor
        )
        updateContentsRect()
    }

    override func scrollWheel(with event: NSEvent) {
        cancelEntryAnimationForUserInteraction()
        if event.scrollingDeltaY > 0 {
            zoomLevel = min(zoomLevel + 0.2, maximumZoom)
        } else if event.scrollingDeltaY < 0 {
            zoomLevel = max(zoomLevel - 0.2, minimumZoom)
        }
        updateContentsRect(animated: Settings.shared.zoomAnimationEnabled)
    }

    override func keyDown(with event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers else { return }
        let upArrow = String(UnicodeScalar(NSUpArrowFunctionKey)!)
        let downArrow = String(UnicodeScalar(NSDownArrowFunctionKey)!)

        switch characters {
        case "\u{1B}": // Escape
            onDismiss?()
        case upArrow:
            cancelEntryAnimationForUserInteraction()
            zoomLevel = min(zoomLevel + 0.2, maximumZoom)
            updateContentsRect(animated: Settings.shared.zoomAnimationEnabled)
        case downArrow:
            cancelEntryAnimationForUserInteraction()
            zoomLevel = max(zoomLevel - 0.2, minimumZoom)
            updateContentsRect(animated: Settings.shared.zoomAnimationEnabled)
        default:
            super.keyDown(with: event)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onDismiss?()
    }

    override func mouseDown(with event: NSEvent) {
        onEnterDrawMode?()
    }

    // MARK: - Public

    func currentZoomedSnapshot(from sourceImage: CGImage) -> CGImage? {
        renderCurrentZoomedImage(from: sourceImage)
    }

    // MARK: - Helpers

    private func animateInitialZoom() {
        guard entryAnimationState == .pending else { return }

        // Small delay so the full-screen frame is rendered first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, self.entryAnimationState == .pending else { return }
            self.zoomLevel = self.targetInitialZoom
            if Settings.shared.zoomAnimationEnabled {
                self.entryAnimationState = .running
                self.updateContentsRect(animated: true, duration: 0.35)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                    guard let self, self.entryAnimationState == .running else { return }
                    self.entryAnimationState = .completed
                }
            } else {
                self.updateContentsRect()
                self.entryAnimationState = .completed
            }
        }
    }

    private func cancelEntryAnimationForUserInteraction() {
        guard entryAnimationState != .completed else { return }
        entryAnimationState = .completed
        layer?.removeAnimation(forKey: "zoom")
    }

    private func updateContentsRect(animated: Bool = false, duration: CFTimeInterval = 0.12) {
        guard imageSize.width > 0 else { return }
        visibleContentsRect = ZoomMath.visibleContentsRect(
            zoomLevel: zoomLevel,
            panCenter: panCenter,
            imageSize: imageSize
        )
        if animated {
            let anim = CABasicAnimation(keyPath: "contentsRect")
            anim.duration = duration
            anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer?.add(anim, forKey: "zoom")
        }
        layer?.contentsRect = visibleContentsRect
    }

    private func renderCurrentZoomedImage(from sourceImage: CGImage) -> CGImage? {
        let sourceWidth = CGFloat(sourceImage.width)
        let sourceHeight = CGFloat(sourceImage.height)

        let crop = ZoomMath.cropRect(
            contentsRect: visibleContentsRect,
            sourceSize: CGSize(width: sourceWidth, height: sourceHeight)
        )

        guard let cropped = sourceImage.cropping(to: crop) else {
            return nil
        }

        let outputWidth = Int(bounds.width * screenScaleFactor)
        let outputHeight = Int(bounds.height * screenScaleFactor)
        guard outputWidth > 0, outputHeight > 0 else { return nil }

        guard let context = CGContext(
            data: nil,
            width: outputWidth,
            height: outputHeight,
            bitsPerComponent: 8,
            bytesPerRow: outputWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
        return context.makeImage()
    }
}
