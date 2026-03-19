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

    // MARK: - Shape Type from Modifiers

    func testShapeTypeFreehandNoModifiers() {
        let state = DrawingState()
        let shape = state.currentShapeType(modifiers: [])
        XCTAssertEqual(shape, .freehand)
    }

    func testShapeTypeLineWithShift() {
        let state = DrawingState()
        let shape = state.currentShapeType(modifiers: .shift)
        XCTAssertEqual(shape, .line)
    }

    func testShapeTypeRectangleWithControl() {
        let state = DrawingState()
        let shape = state.currentShapeType(modifiers: .control)
        XCTAssertEqual(shape, .rectangle)
    }

    func testShapeTypeArrowWithShiftControl() {
        let state = DrawingState()
        let shape = state.currentShapeType(modifiers: [.shift, .control])
        XCTAssertEqual(shape, .arrow)
    }

    func testShapeTypeEllipseWithTab() {
        let state = DrawingState()
        state.isTabHeld = true
        let shape = state.currentShapeType(modifiers: [])
        XCTAssertEqual(shape, .ellipse)
    }

    func testShapeTypeTabOverridesOtherModifiers() {
        let state = DrawingState()
        state.isTabHeld = true
        let shape = state.currentShapeType(modifiers: [.shift, .control])
        XCTAssertEqual(shape, .ellipse, "Tab should take priority over other modifiers")
    }

    // MARK: - Current NSColor

    func testCurrentNSColorNormalMode() {
        let state = DrawingState()
        state.activeColor = .blue
        state.isHighlighterMode = false
        XCTAssertEqual(state.currentNSColor, NSColor.systemBlue)
    }

    func testCurrentNSColorHighlighterMode() {
        let state = DrawingState()
        state.activeColor = .red
        state.isHighlighterMode = true
        let color = state.currentNSColor
        XCTAssertEqual(
            color.alphaComponent,
            Settings.shared.highlighterOpacity,
            accuracy: 0.01
        )
    }

    // MARK: - Background Mode

    func testDefaultBackgroundMode() {
        let state = DrawingState()
        switch state.backgroundMode {
        case .transparent: break
        default: XCTFail("Default background should be .transparent")
        }
    }
}
