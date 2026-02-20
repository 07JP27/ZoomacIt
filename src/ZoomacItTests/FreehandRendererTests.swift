import XCTest
@testable import ZoomacIt

final class FreehandRendererTests: XCTestCase {

    func testEmptyPoints() {
        let path = FreehandRenderer.smoothedPath(from: [])
        XCTAssertEqual(path.elementCount, 0)
    }

    func testSinglePoint() {
        let path = FreehandRenderer.smoothedPath(from: [CGPoint(x: 50, y: 50)])
        XCTAssertEqual(path.elementCount, 1) // just moveTo
    }

    func testTwoPoints() {
        let path = FreehandRenderer.smoothedPath(from: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 100)
        ])
        XCTAssertEqual(path.elementCount, 2) // moveTo + lineTo
    }

    func testMultiplePointsProduceSmoothPath() {
        let points = (0..<10).map { CGPoint(x: Double($0) * 10, y: Double($0) * 5) }
        let path = FreehandRenderer.smoothedPath(from: points)
        // Should produce a smooth path with curveTo elements
        XCTAssertTrue(path.elementCount > points.count / 2)
    }
}
