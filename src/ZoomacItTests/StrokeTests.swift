import XCTest
@testable import ZoomacIt

final class StrokeTests: XCTestCase {

    func testDefaultInitialization() {
        let stroke = Stroke()
        XCTAssertTrue(stroke.points.isEmpty)
        XCTAssertEqual(stroke.startPoint, .zero)
        XCTAssertEqual(stroke.endPoint, .zero)
        XCTAssertEqual(stroke.color, .red)
        XCTAssertEqual(stroke.lineWidth, 3.0)
        XCTAssertEqual(stroke.shapeType, .freehand)
        XCTAssertFalse(stroke.isHighlighter)
    }

    func testCustomInitialization() {
        let points = [CGPoint(x: 10, y: 20), CGPoint(x: 30, y: 40)]
        let stroke = Stroke(
            points: points,
            startPoint: CGPoint(x: 10, y: 20),
            endPoint: CGPoint(x: 30, y: 40),
            color: .blue,
            lineWidth: 5.0,
            shapeType: .rectangle,
            isHighlighter: true
        )
        XCTAssertEqual(stroke.points.count, 2)
        XCTAssertEqual(stroke.startPoint, CGPoint(x: 10, y: 20))
        XCTAssertEqual(stroke.endPoint, CGPoint(x: 30, y: 40))
        XCTAssertEqual(stroke.color, .blue)
        XCTAssertEqual(stroke.lineWidth, 5.0)
        XCTAssertEqual(stroke.shapeType, .rectangle)
        XCTAssertTrue(stroke.isHighlighter)
    }

    func testPartialInitialization() {
        let stroke = Stroke(lineWidth: 8.0, shapeType: .arrow)
        XCTAssertTrue(stroke.points.isEmpty)
        XCTAssertEqual(stroke.shapeType, .arrow)
        XCTAssertEqual(stroke.lineWidth, 8.0)
        XCTAssertEqual(stroke.color, .red, "Unspecified params should use defaults")
        XCTAssertFalse(stroke.isHighlighter)
    }

    // MARK: - ShapeType Enum

    func testShapeTypeAllCases() {
        let types: [ShapeType] = [.freehand, .line, .rectangle, .ellipse, .arrow]
        XCTAssertEqual(types.count, 5)
    }

    func testShapeTypeEquality() {
        XCTAssertEqual(ShapeType.freehand, ShapeType.freehand)
        XCTAssertNotEqual(ShapeType.line, ShapeType.arrow)
    }
}
