import XCTest
@testable import ZoomacIt

final class ShapeRendererTests: XCTestCase {

    func testLinePath() {
        let path = ShapeRenderer.linePath(
            from: CGPoint(x: 0, y: 0),
            to: CGPoint(x: 100, y: 100)
        )
        XCTAssertEqual(path.elementCount, 2) // moveTo + lineTo
    }

    func testRectanglePath() {
        let path = ShapeRenderer.rectanglePath(
            from: CGPoint(x: 10, y: 10),
            to: CGPoint(x: 110, y: 110)
        )
        // NSBezierPath(rect:) creates moveTo + 3 lineTo + closePath = 5 elements
        XCTAssertTrue(path.elementCount >= 4)
    }

    func testEllipsePath() {
        let path = ShapeRenderer.ellipsePath(
            from: CGPoint(x: 0, y: 0),
            to: CGPoint(x: 100, y: 50)
        )
        XCTAssertTrue(path.elementCount > 0)
    }

    func testArrowPath() {
        let path = ShapeRenderer.arrowPath(
            from: CGPoint(x: 50, y: 50),
            to: CGPoint(x: 150, y: 50)
        )
        // Arrow = shaft (moveTo + lineTo) + head (moveTo + lineTo + lineTo) = 5 elements
        XCTAssertTrue(path.elementCount >= 5)
    }
}
