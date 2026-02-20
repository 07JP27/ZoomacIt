import AppKit

/// Renders geometric shapes as NSBezierPath for both preview and final compositing.
enum ShapeRenderer {

    // MARK: - Line

    static func linePath(from start: CGPoint, to end: CGPoint) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        return path
    }

    // MARK: - Rectangle

    static func rectanglePath(from start: CGPoint, to end: CGPoint) -> NSBezierPath {
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        return NSBezierPath(rect: rect)
    }

    // MARK: - Ellipse

    static func ellipsePath(from start: CGPoint, to end: CGPoint) -> NSBezierPath {
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        return NSBezierPath(ovalIn: rect)
    }

    // MARK: - Arrow

    /// Creates an arrow path where the **start point is the arrowhead tip**
    /// (ZoomIt-specific behavior — the arrow points toward where you started dragging).
    static func arrowPath(from start: CGPoint, to end: CGPoint) -> NSBezierPath {
        let path = NSBezierPath()

        // The shaft goes from end (tail) to start (tip)
        path.move(to: end)
        path.line(to: start)

        // Arrowhead at the start point (tip)
        let headLength: CGFloat = 20.0
        let headAngle: CGFloat = .pi / 6  // 30 degrees

        let dx = end.x - start.x
        let dy = end.y - start.y
        let angle = atan2(dy, dx)

        let arrowPoint1 = CGPoint(
            x: start.x + headLength * cos(angle + headAngle),
            y: start.y + headLength * sin(angle + headAngle)
        )
        let arrowPoint2 = CGPoint(
            x: start.x + headLength * cos(angle - headAngle),
            y: start.y + headLength * sin(angle - headAngle)
        )

        path.move(to: arrowPoint1)
        path.line(to: start)
        path.line(to: arrowPoint2)

        return path
    }
}
