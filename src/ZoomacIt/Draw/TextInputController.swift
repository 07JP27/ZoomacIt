import AppKit
import CoreGraphics

/// Manages an NSTextView for text input during Draw mode.
/// On commit, the text is rasterized into a CGImage and composited onto finishedLayer.
@MainActor
final class TextInputController: NSObject, NSTextViewDelegate {

    private weak var canvasView: NSView?
    private let drawingState: DrawingState
    private var textView: NSTextView?
    private var fontSize: CGFloat = 24.0

    /// Called when the user presses Escape inside the text view.
    /// The owner (DrawingCanvasView) should call commitText() in response.
    var onCommit: (() -> Void)?

    init(canvasView: NSView, drawingState: DrawingState) {
        self.canvasView = canvasView
        self.drawingState = drawingState
        super.init()
    }

    // MARK: - Public

    /// Whether the controller has a text view with non-empty content.
    var hasText: Bool {
        guard let textView else { return false }
        return !textView.string.isEmpty
    }

    /// Place a text field at the specified position within the canvas.
    /// If there is existing text, the caller is responsible for committing it first.
    func placeTextField(at point: CGPoint) {
        cleanup() // Remove any existing text view (caller should have committed first)

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

        // Set delegate to intercept Escape key
        textView.delegate = self

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
        textView?.delegate = nil
        textView?.removeFromSuperview()
        textView = nil
    }

    // MARK: - NSTextViewDelegate

    /// Intercept Escape key (cancelOperation:) before NSTextView consumes it.
    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            // Escape pressed — notify owner to commit text and exit text mode
            onCommit?()
            return true // We handled it
        }
        return false // Let NSTextView handle other commands
    }
}
