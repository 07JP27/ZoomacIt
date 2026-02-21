import CoreGraphics

/// Pure-function zoom math extracted for testability.
/// Used by StillZoomView to compute the visible region and crop rectangle.
enum ZoomMath {

    /// Normalised [0,1] rect of the source image that should be visible
    /// at the given zoom level and pan centre (in source pixel space).
    static func visibleContentsRect(
        zoomLevel: CGFloat,
        panCenter: CGPoint,
        imageSize: CGSize
    ) -> CGRect {
        let visibleWidth  = 1.0 / zoomLevel
        let visibleHeight = 1.0 / zoomLevel

        let normCenterX = panCenter.x / imageSize.width
        let normCenterY = panCenter.y / imageSize.height

        let originX = clamp(normCenterX - visibleWidth  * 0.5,
                            lower: 0, upper: 1 - visibleWidth)
        let originY = clamp(normCenterY - visibleHeight * 0.5,
                            lower: 0, upper: 1 - visibleHeight)

        return CGRect(x: originX, y: originY,
                      width: visibleWidth, height: visibleHeight)
    }

    /// Converts a CALayer-coordinate contentsRect (origin at bottom-left)
    /// to a CGImage-coordinate (origin at top-left) pixel crop rect.
    static func cropRect(
        contentsRect: CGRect,
        sourceSize: CGSize
    ) -> CGRect {
        let flippedOriginY = 1.0 - contentsRect.origin.y - contentsRect.size.height
        return CGRect(
            x: contentsRect.origin.x * sourceSize.width,
            y: flippedOriginY * sourceSize.height,
            width:  contentsRect.size.width  * sourceSize.width,
            height: contentsRect.size.height * sourceSize.height
        ).integral
    }

    /// Clamp a value to [lower, upper].
    static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }

    /// Clamp zoom level to allowed range.
    static func clampZoomLevel(_ level: CGFloat,
                               minimum: CGFloat = 1.0,
                               maximum: CGFloat = 8.0) -> CGFloat {
        clamp(level, lower: minimum, upper: maximum)
    }

    /// Default pan centre (image centre) for a given image size.
    static func defaultPanCenter(for imageSize: CGSize) -> CGPoint {
        CGPoint(x: imageSize.width * 0.5, y: imageSize.height * 0.5)
    }
}
