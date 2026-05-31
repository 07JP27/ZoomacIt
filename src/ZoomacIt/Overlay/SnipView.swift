import AppKit
import CoreGraphics

/// Displays a frozen screenshot and lets the user drag-select a region.
final class SnipView: NSView {

    var onDismiss: (() -> Void)?
    var onSnip: ((CGImage) -> Void)?

    private let sourceImage: CGImage
    private let scaleFactor: CGFloat
    private var selectionRect: NSRect = .zero
    private var dragStart: NSPoint = .zero
    private var isDragging = false

    init(frame: NSRect, sourceImage: CGImage, scaleFactor: CGFloat) {
        self.sourceImage = sourceImage
        self.scaleFactor = scaleFactor
        super.init(frame: frame)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.invalidateCursorRects(for: self)
    }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        // Draw the source image as background (avoids layer.contents vs draw() conflict)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.draw(sourceImage, in: bounds)

        guard isDragging, selectionRect.width > 0, selectionRect.height > 0 else { return }

        // Dim everything outside selection
        NSColor.black.withAlphaComponent(0.4).setFill()
        dirtyRect.fill()

        // Clear the selection area (show original image through)
        let path = NSBezierPath(rect: selectionRect)
        NSGraphicsContext.current?.compositingOperation = .clear
        path.fill()

        // Redraw image in selection area
        NSGraphicsContext.current?.compositingOperation = .sourceOver
        context.saveGState()
        context.clip(to: selectionRect)
        context.draw(sourceImage, in: bounds)
        context.restoreGState()

        // Draw selection border
        NSColor.white.setStroke()
        let border = NSBezierPath(rect: selectionRect)
        border.lineWidth = 1.5
        border.stroke()
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        dragStart = convert(event.locationInWindow, from: nil)
        selectionRect = .zero
        isDragging = true
    }

    override func mouseDragged(with event: NSEvent) {
        let current = convert(event.locationInWindow, from: nil)
        let clampedCurrent = NSPoint(
            x: min(max(current.x, 0), bounds.width),
            y: min(max(current.y, 0), bounds.height)
        )
        selectionRect = NSRect(
            x: min(dragStart.x, clampedCurrent.x),
            y: min(dragStart.y, clampedCurrent.y),
            width: abs(clampedCurrent.x - dragStart.x),
            height: abs(clampedCurrent.y - dragStart.y)
        )
        setNeedsDisplay(bounds)
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        guard selectionRect.width > 2, selectionRect.height > 2 else {
            onDismiss?()
            return
        }

        // Convert view coords to image pixel coords, clamped to image bounds
        let imageBounds = CGRect(x: 0, y: 0, width: sourceImage.width, height: sourceImage.height)
        let cropRect = CGRect(
            x: selectionRect.origin.x * scaleFactor,
            y: (bounds.height - selectionRect.origin.y - selectionRect.height) * scaleFactor,
            width: selectionRect.width * scaleFactor,
            height: selectionRect.height * scaleFactor
        ).integral.intersection(imageBounds)

        guard !cropRect.isEmpty, let cropped = sourceImage.cropping(to: cropRect) else {
            onDismiss?()
            return
        }
        onSnip?(cropped)
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == "\u{1B}" { // Escape
            onDismiss?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onDismiss?()
    }
}
