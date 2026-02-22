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
    private(set) var zoomLevel: CGFloat
    private let targetInitialZoom: CGFloat
    private let minimumZoom: CGFloat = 1.0
    private let maximumZoom: CGFloat = 8.0

    /// Pan center in source image pixel space.
    private(set) var panCenter: CGPoint

    /// Normalized [0,1] rect of source image currently visible in view.
    private var visibleContentsRect: CGRect = .zero
    private let skipEntryAnimation: Bool

    init(frame: NSRect, sourceImage: CGImage, initialZoomLevel: CGFloat = Settings.shared.defaultZoomLevel,
         initialPanCenter: CGPoint? = nil, screenScaleFactor: CGFloat,
         skipEntryAnimation: Bool = false) {
        self.sourceImage = sourceImage
        self.screenScaleFactor = screenScaleFactor
        self.skipEntryAnimation = skipEntryAnimation
        self.targetInitialZoom = ZoomMath.clampZoomLevel(initialZoomLevel, minimum: minimumZoom, maximum: maximumZoom)
        // Start at target zoom immediately when skipping animation, otherwise 1.0 for entry animation
        self.zoomLevel = skipEntryAnimation ? self.targetInitialZoom : 1.0
        self.panCenter = initialPanCenter ?? ZoomMath.defaultPanCenter(
            for: CGSize(width: sourceImage.width, height: sourceImage.height)
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
        updateLayerContentsRect()
        if !skipEntryAnimation {
            animateInitialZoom()
        }
    }

    private func animateInitialZoom() {
        // Small delay so the full-screen frame is rendered first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.zoomLevel = self.targetInitialZoom
            if Settings.shared.zoomAnimationEnabled {
                self.updateLayerContentsRect(animated: true, duration: 0.35)
            } else {
                self.updateLayerContentsRect()
            }
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
        updateLayerContentsRect(animated: Settings.shared.zoomAnimationEnabled)
    }

    override func keyDown(with event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers else { return }

        let upArrow = String(UnicodeScalar(NSUpArrowFunctionKey)!)
        let downArrow = String(UnicodeScalar(NSDownArrowFunctionKey)!)

        switch characters {
        case "\u{1B}": // Escape
            onDismiss?()
        case upArrow:
            zoomLevel = min(zoomLevel + 0.2, maximumZoom)
            updateLayerContentsRect(animated: Settings.shared.zoomAnimationEnabled)
        case downArrow:
            zoomLevel = max(zoomLevel - 0.2, minimumZoom)
            updateLayerContentsRect(animated: Settings.shared.zoomAnimationEnabled)
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
        visibleContentsRect = ZoomMath.visibleContentsRect(
            zoomLevel: zoomLevel,
            panCenter: panCenter,
            imageSize: CGSize(width: sourceImage.width, height: sourceImage.height)
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
