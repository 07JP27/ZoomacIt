import AppKit

/// Renders semi-transparent highlighter strokes.
enum HighlighterRenderer {

    /// The alpha value used for highlighter strokes.
    static let highlighterAlpha: CGFloat = 0.35

    /// Creates a highlighter-style NSBezierPath with the appropriate visual settings.
    /// The actual alpha is applied through the color (see DrawingState.currentNSColor).
    ///
    /// Highlighter strokes are rendered with:
    /// - Wider line width (2x the current pen width)
    /// - Square line cap for a marker-like appearance
    /// - Multiply blend mode for realistic color overlay
    static func applyHighlighterStyle(to path: NSBezierPath, penWidth: CGFloat) {
        path.lineWidth = penWidth * 2.0
        path.lineCapStyle = .square
        path.lineJoinStyle = .round
    }

    /// Renders a highlighter stroke directly into a CGContext.
    static func renderHighlighterStroke(
        path: CGPath,
        color: NSColor,
        penWidth: CGFloat,
        into context: CGContext
    ) {
        context.saveGState()
        context.setBlendMode(.multiply)
        context.setStrokeColor(color.withAlphaComponent(highlighterAlpha).cgColor)
        context.setLineWidth(penWidth * 2.0)
        context.setLineCap(.square)
        context.setLineJoin(.round)
        context.addPath(path)
        context.strokePath()
        context.restoreGState()
    }
}
