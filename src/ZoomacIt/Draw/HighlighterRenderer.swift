import AppKit

/// Renders semi-transparent highlighter strokes.
enum HighlighterRenderer {

    /// The alpha value used for highlighter strokes.
    static var highlighterAlpha: CGFloat { Settings.shared.highlighterOpacity }

    /// Creates a highlighter-style NSBezierPath with the appropriate visual settings.
    /// The actual alpha is applied through the color (see DrawingState.currentNSColor).
    ///
    /// Highlighter strokes are rendered with:
    /// - Wider line width (4x the current pen width)
    /// - Square line cap for a marker-like appearance
    /// - Multiply blend mode for realistic color overlay
    static func applyHighlighterStyle(to path: NSBezierPath, penWidth: CGFloat) {
        path.lineWidth = penWidth * Settings.shared.highlighterWidthMultiplier
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
        context.setLineWidth(penWidth * Settings.shared.highlighterWidthMultiplier)
        context.setLineCap(.square)
        context.setLineJoin(.round)
        context.addPath(path)
        context.strokePath()
        context.restoreGState()
    }
}
