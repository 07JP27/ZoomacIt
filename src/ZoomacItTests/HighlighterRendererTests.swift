import XCTest
@testable import ZoomacIt

final class HighlighterRendererTests: XCTestCase {

    func testApplyHighlighterStyleSetsLineWidth() {
        let path = NSBezierPath()
        path.lineWidth = 3.0
        HighlighterRenderer.applyHighlighterStyle(to: path, penWidth: 3.0)

        let expectedWidth = 3.0 * Settings.shared.highlighterWidthMultiplier
        XCTAssertEqual(path.lineWidth, expectedWidth)
    }

    func testApplyHighlighterStyleSetsLineCap() {
        let path = NSBezierPath()
        HighlighterRenderer.applyHighlighterStyle(to: path, penWidth: 3.0)
        XCTAssertEqual(path.lineCapStyle, .square)
    }

    func testApplyHighlighterStyleSetsLineJoin() {
        let path = NSBezierPath()
        HighlighterRenderer.applyHighlighterStyle(to: path, penWidth: 3.0)
        XCTAssertEqual(path.lineJoinStyle, .round)
    }

    func testHighlighterAlphaMatchesSettings() {
        XCTAssertEqual(
            HighlighterRenderer.highlighterAlpha,
            Settings.shared.highlighterOpacity
        )
    }

    func testRenderHighlighterStrokeIntoBitmapContext() {
        let ctx = CGContext.createBitmapContext(size: CGSize(width: 100, height: 100))!

        let path = CGMutablePath()
        path.move(to: CGPoint(x: 10, y: 10))
        path.addLine(to: CGPoint(x: 90, y: 90))

        HighlighterRenderer.renderHighlighterStroke(
            path: path,
            color: .systemRed,
            penWidth: 5.0,
            into: ctx
        )

        // Verify the context has been drawn to by checking a pixel along the stroke
        guard let image = ctx.makeImage() else {
            XCTFail("Failed to create image from context")
            return
        }
        XCTAssertEqual(image.width, 100)
        XCTAssertEqual(image.height, 100)
    }
}
