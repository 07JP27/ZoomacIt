import AppKit

/// The type of shape being drawn.
enum ShapeType: Sendable {
    case freehand
    case line
    case rectangle
    case ellipse
    case arrow
}

/// Represents a single confirmed drawing stroke.
struct Stroke {
    /// Raw points collected during freehand drawing.
    var points: [CGPoint]

    /// Starting point (used for shape rendering).
    var startPoint: CGPoint

    /// Ending point (used for shape rendering).
    var endPoint: CGPoint

    /// The stroke color.
    var color: NSColor

    /// The line width in points.
    var lineWidth: CGFloat

    /// The shape type.
    var shapeType: ShapeType

    /// Whether the stroke uses highlighter (semi-transparent) mode.
    var isHighlighter: Bool

    init(
        points: [CGPoint] = [],
        startPoint: CGPoint = .zero,
        endPoint: CGPoint = .zero,
        color: NSColor = .red,
        lineWidth: CGFloat = 3.0,
        shapeType: ShapeType = .freehand,
        isHighlighter: Bool = false
    ) {
        self.points = points
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.color = color
        self.lineWidth = lineWidth
        self.shapeType = shapeType
        self.isHighlighter = isHighlighter
    }
}
