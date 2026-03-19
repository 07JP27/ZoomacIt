import XCTest
@testable import ZoomacIt

final class NSBezierPathExtensionsTests: XCTestCase {

    func testEmptyPathProducesEmptyCGPath() {
        let path = NSBezierPath()
        let cgPath = path.cgPath
        XCTAssertTrue(cgPath.isEmpty)
    }

    func testMoveToLineTo() {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 10, y: 20))
        path.line(to: NSPoint(x: 30, y: 40))

        let cgPath = path.cgPath
        XCTAssertFalse(cgPath.isEmpty)
        XCTAssertTrue(cgPath.contains(CGPoint(x: 20, y: 30)),
                       "CGPath should contain a point on the line segment")
    }

    func testRectPath() {
        let rect = NSRect(x: 0, y: 0, width: 100, height: 50)
        let path = NSBezierPath(rect: rect)
        let cgPath = path.cgPath

        let bounds = cgPath.boundingBoxOfPath
        XCTAssertEqual(bounds.width, 100, accuracy: 0.1)
        XCTAssertEqual(bounds.height, 50, accuracy: 0.1)
    }

    func testOvalPath() {
        let rect = NSRect(x: 0, y: 0, width: 80, height: 80)
        let path = NSBezierPath(ovalIn: rect)
        let cgPath = path.cgPath

        XCTAssertFalse(cgPath.isEmpty)
        let bounds = cgPath.boundingBoxOfPath
        XCTAssertEqual(bounds.width, 80, accuracy: 1.0)
        XCTAssertEqual(bounds.height, 80, accuracy: 1.0)
    }

    func testClosePathProducesClosedSubpath() {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 0, y: 0))
        path.line(to: NSPoint(x: 100, y: 0))
        path.line(to: NSPoint(x: 100, y: 100))
        path.close()

        let cgPath = path.cgPath
        XCTAssertFalse(cgPath.isEmpty)
        XCTAssertTrue(cgPath.contains(CGPoint(x: 50, y: 25)),
                       "Closed triangle should contain interior point")
    }

    func testCurveToPath() {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 0, y: 0))
        path.curve(to: NSPoint(x: 100, y: 100),
                    controlPoint1: NSPoint(x: 0, y: 50),
                    controlPoint2: NSPoint(x: 50, y: 100))

        let cgPath = path.cgPath
        XCTAssertFalse(cgPath.isEmpty)
        let bounds = cgPath.boundingBoxOfPath
        XCTAssertGreaterThan(bounds.width, 0)
        XCTAssertGreaterThan(bounds.height, 0)
    }
}
