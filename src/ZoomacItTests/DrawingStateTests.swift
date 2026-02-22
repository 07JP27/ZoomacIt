import XCTest
@testable import ZoomacIt

final class DrawingStateTests: XCTestCase {

    func testDefaultState() {
        let state = DrawingState()
        XCTAssertEqual(state.penWidth, 3.0)
        XCTAssertFalse(state.isHighlighterMode)
        XCTAssertFalse(state.isTextMode)
        XCTAssertFalse(state.isTabHeld)
    }

    func testPenWidthBounds() {
        let state = DrawingState()

        // Decrease to minimum
        for _ in 0..<100 {
            state.decreasePenWidth()
        }
        XCTAssertEqual(state.penWidth, 1.0)

        // Increase to maximum
        for _ in 0..<100 {
            state.increasePenWidth()
        }
        XCTAssertEqual(state.penWidth, 50.0)
    }

    func testColorMapping() {
        XCTAssertEqual(PenColor.from(character: "R"), .red)
        XCTAssertEqual(PenColor.from(character: "g"), .green)
        XCTAssertEqual(PenColor.from(character: "B"), .blue)
        XCTAssertEqual(PenColor.from(character: "O"), .orange)
        XCTAssertEqual(PenColor.from(character: "Y"), .yellow)
        XCTAssertEqual(PenColor.from(character: "P"), .pink)
        XCTAssertNil(PenColor.from(character: "Z"))
    }
}
