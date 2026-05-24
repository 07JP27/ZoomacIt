import AppKit
import CoreGraphics
import CoreVideo
import IOSurface

/// Renders live SCStream frames as a zoomable/pannable full-screen view.
final class LiveZoomView: NSView {

    var onDismiss: (() -> Void)?
    var onEnterDrawMode: (() -> Void)?

    private let screenScaleFactor: CGFloat
    private(set) var zoomLevel: CGFloat = min(max(Settings.shared.defaultZoomLevel, 1.0), 8.0)
    private let minimumZoom: CGFloat = 1.0
    private let maximumZoom: CGFloat = 8.0

    /// Pan center in source pixel space.
    private(set) var panCenter: CGPoint = .zero
    private var imageSize: CGSize = .zero
    private var hasReceivedFirstFrame = false

    init(frame: NSRect, screenScaleFactor: CGFloat) {
        self.screenScaleFactor = screenScaleFactor
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

        if !hasReceivedFirstFrame {
            imageSize = CGSize(width: w, height: h)
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
        }

        // Extract IOSurface for zero-copy GPU rendering
        if let surface = CVPixelBufferGetIOSurface(pixelBuffer) {
            layer?.contents = surface.takeUnretainedValue()
        }
        updateContentsRect()
    }

    // MARK: - Input

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        panCenter = CGPoint(
            x: location.x * screenScaleFactor,
            y: location.y * screenScaleFactor
        )
        updateContentsRect()
    }

    override func scrollWheel(with event: NSEvent) {
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
            zoomLevel = min(zoomLevel + 0.2, maximumZoom)
            updateContentsRect(animated: Settings.shared.zoomAnimationEnabled)
        case downArrow:
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

    // MARK: - Helpers

    private func updateContentsRect(animated: Bool = false) {
        guard imageSize.width > 0 else { return }
        let rect = ZoomMath.visibleContentsRect(
            zoomLevel: zoomLevel,
            panCenter: panCenter,
            imageSize: imageSize
        )
        if animated {
            let anim = CABasicAnimation(keyPath: "contentsRect")
            anim.duration = 0.12
            anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer?.add(anim, forKey: "zoom")
        }
        layer?.contentsRect = rect
    }
}
