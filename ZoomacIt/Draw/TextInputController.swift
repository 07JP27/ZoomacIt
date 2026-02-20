import AppKit
import CoreGraphics

/// Manages an NSTextView for text input during Draw mode.
/// On commit, the text is rasterized into a CGImage and composited onto finishedLayer.
final class TextInputController {

    private weak var canvasView: NSView?
    private let drawingState: DrawingState
    private var textView: NSTextView?
    private var fontSize: CGFloat = 24.0

    init(canvasView: NSView, drawingState: DrawingState) {
        self.canvasView = canvasView
        self.drawingState = drawingState
    }

    // MARK: - Public

    /// Place a text field at the specified position within the canvas.
    func placeTextField(at point: CGPoint) {
        cleanup() // Remove any existing text view

        guard let canvas = canvasView else { return }

        let textView = NSTextView(frame: CGRect(x: point.x, y: point.y - 30, width: 400, height: 60))
        textView.backgroundColor = .clear
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.insertionPointColor = drawingState.activeColor.nsColor
        textView.textColor = drawingState.activeColor.nsColor
        textView.font = NSFont.systemFont(ofSize: fontSize, weight: .medium)

        // Allow the text view to grow as the user types
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.maxSize = NSSize(width: canvas.bounds.width - point.x, height: canvas.bounds.height - point.y)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        canvas.addSubview(textView)
        textView.window?.makeFirstResponder(textView)

        self.textView = textView
    }

    /// Adjust the font size (called from scroll wheel events).
    func adjustFontSize(delta: CGFloat) {
        fontSize = max(8, min(200, fontSize + delta))
        textView?.font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
    }

    /// Update the text color (called when color keys are pressed in text mode).
    func updateColor(_ color: NSColor) {
        textView?.textColor = color
        textView?.insertionPointColor = color
    }

    /// Rasterize the text into a CGImage and composite it onto the existing finishedLayer.
    func rasterizeAndComposite(onto finishedLayer: CGImage?, canvasSize: CGSize) -> CGImage? {
        guard let textView, let text = textView.string as String?, !text.isEmpty else {
            return finishedLayer
        }

        guard let bitmapContext = CGContext.createBitmapContext(size: canvasSize) else {
            return finishedLayer
        }

        // Draw existing finished layer
        if let existing = finishedLayer {
            bitmapContext.draw(existing, in: CGRect(origin: .zero, size: canvasSize))
        }

        // Render the text
        let nsGraphicsContext = NSGraphicsContext(cgContext: bitmapContext, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsGraphicsContext

        let attrs: [NSAttributedString.Key: Any] = [
            .font: textView.font ?? NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: textView.textColor ?? NSColor.red
        ]

        let string = NSAttributedString(string: text, attributes: attrs)
        string.draw(at: textView.frame.origin)

        NSGraphicsContext.restoreGraphicsState()

        return bitmapContext.makeImage()
    }

    /// Remove the text view from the canvas.
    func cleanup() {
        textView?.removeFromSuperview()
        textView = nil
    }
}
