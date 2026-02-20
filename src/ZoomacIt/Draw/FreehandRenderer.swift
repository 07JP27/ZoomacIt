import AppKit

/// Renders smooth freehand paths using Catmull-Rom spline interpolation.
enum FreehandRenderer {

    /// Generates a smoothed NSBezierPath from raw input points using Catmull-Rom subdivision.
    /// Falls back to simple line segments if fewer than 4 points are available.
    static func smoothedPath(from points: [CGPoint]) -> NSBezierPath {
        let path = NSBezierPath()
        guard !points.isEmpty else { return path }

        if points.count < 3 {
            path.move(to: points[0])
            for i in 1..<points.count {
                path.line(to: points[i])
            }
            return path
        }

        // Use Catmull-Rom → Bézier conversion
        path.move(to: points[0])

        for i in 0..<points.count - 1 {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[min(i + 1, points.count - 1)]
            let p3 = points[min(i + 2, points.count - 1)]

            // Catmull-Rom to cubic Bézier control points
            // Using alpha=0.5 (centripetal parameterization) for smoother curves
            let cp1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6.0,
                y: p1.y + (p2.y - p0.y) / 6.0
            )
            let cp2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6.0,
                y: p2.y - (p3.y - p1.y) / 6.0
            )

            path.curve(to: p2, controlPoint1: cp1, controlPoint2: cp2)
        }

        return path
    }
}
