import AppKit
import CoreGraphics

/// Renders a captured screen image as a zoomable/pannable full-screen view.
final class StillZoomView: NSView {

    // MARK: - Callbacks

    var onDismiss: (() -> Void)?
    var onEnterDrawMode: ((CGImage) -> Void)?

    // MARK: - State

    private let sourceImage: CGImage
    private let screenScaleFactor: CGFloat
    private var zoomLevel: CGFloat
    private let targetInitialZoom: CGFloat
    private let minimumZoom: CGFloat = 1.0
    private let maximumZoom: CGFloat = 8.0

    /// Pan center in source image pixel space.
    private var panCenter: CGPoint

    /// Normalized [0,1] rect of source image currently visible in view.
    private var visibleContentsRect: CGRect = .zero

    init(frame: NSRect, sourceImage: CGImage, initialZoomLevel: CGFloat = 2.0, screenScaleFactor: CGFloat) {
        self.sourceImage = sourceImage
        self.screenScaleFactor = screenScaleFactor
        self.targetInitialZoom = max(min(initialZoomLevel, maximumZoom), minimumZoom)
        // Start at 1.0 (full screen) for the entry animation
        self.zoomLevel = 1.0
        self.panCenter = CGPoint(
            x: CGFloat(sourceImage.width) * 0.5,
            y: CGFloat(sourceImage.height) * 0.5
        )
        super.init(frame: frame)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - NSView

    override var acceptsFirstResponder: Bool { true }

    override var wantsUpdateLayer: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let layer {
            layer.contents = sourceImage
            layer.contentsGravity = .resizeAspectFill
            layer.magnificationFilter = .linear
        }
        // Show full screen first, then animate zoom in
        updateLayerContentsRect()
        animateInitialZoom()
    }

    private func animateInitialZoom() {
        // Small delay so the full-screen frame is rendered first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.zoomLevel = self.targetInitialZoom
            self.updateLayerContentsRect(animated: true, duration: 0.35)
        }
    }

    override func updateLayer() {
        guard let layer else { return }
        layer.contents = sourceImage
        layer.contentsGravity = .resizeAspectFill
        layer.contentsRect = visibleContentsRect
        layer.magnificationFilter = .linear
    }

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        panCenter = CGPoint(
            x: location.x * screenScaleFactor,
            y: location.y * screenScaleFactor
        )
        updateLayerContentsRect()
    }

    override func scrollWheel(with event: NSEvent) {
        if event.scrollingDeltaY > 0 {
            zoomLevel = min(zoomLevel + 0.2, maximumZoom)
        } else if event.scrollingDeltaY < 0 {
            zoomLevel = max(zoomLevel - 0.2, minimumZoom)
        }
        updateLayerContentsRect(animated: true)
    }

    override func keyDown(with event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers else { return }

        switch characters {
        case "\u{1B}": // Escape
            onDismiss?()
        case NSUpArrowFunctionKey.description:
            zoomLevel = min(zoomLevel + 0.2, maximumZoom)
            updateLayerContentsRect(animated: true)
        case NSDownArrowFunctionKey.description:
            zoomLevel = max(zoomLevel - 0.2, minimumZoom)
            updateLayerContentsRect(animated: true)
        default:
            super.keyDown(with: event)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onDismiss?()
    }

    override func mouseDown(with event: NSEvent) {
        if let snapshot = renderCurrentZoomedImage() {
            onEnterDrawMode?(snapshot)
        } else {
            onDismiss?()
        }
    }

    // MARK: - Public

    func currentZoomedSnapshot() -> CGImage? {
        renderCurrentZoomedImage()
    }

    // MARK: - Helpers

    private func updateLayerContentsRect(animated: Bool = false, duration: CFTimeInterval = 0.12) {
        let visibleWidth = 1.0 / zoomLevel
        let visibleHeight = 1.0 / zoomLevel

        let normalizedCenterX = panCenter.x / CGFloat(sourceImage.width)
        let normalizedCenterY = panCenter.y / CGFloat(sourceImage.height)

        let originX = clamp(normalizedCenterX - visibleWidth * 0.5, lower: 0, upper: 1 - visibleWidth)
        let originY = clamp(normalizedCenterY - visibleHeight * 0.5, lower: 0, upper: 1 - visibleHeight)

        visibleContentsRect = CGRect(
            x: originX,
            y: originY,
            width: visibleWidth,
            height: visibleHeight
        )

        if animated {
            let anim = CABasicAnimation(keyPath: "contentsRect")
            anim.duration = duration
            anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer?.add(anim, forKey: "zoom")
        }

        layer?.contentsRect = visibleContentsRect
    }

    private func renderCurrentZoomedImage() -> CGImage? {
        let sourceWidth = CGFloat(sourceImage.width)
        let sourceHeight = CGFloat(sourceImage.height)

        let cropRect = CGRect(
            x: visibleContentsRect.origin.x * sourceWidth,
            y: visibleContentsRect.origin.y * sourceHeight,
            width: visibleContentsRect.size.width * sourceWidth,
            height: visibleContentsRect.size.height * sourceHeight
        )

        guard let cropped = sourceImage.cropping(to: cropRect.integral) else {
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

    private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}
