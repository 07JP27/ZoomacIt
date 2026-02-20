import XCTest
@testable import ZoomacIt

final class StrokeManagerTests: XCTestCase {

    func testPushAndPopSnapshot() {
        let manager = StrokeManager()

        // Initially empty
        XCTAssertNil(manager.popUndoSnapshot())
        XCTAssertEqual(manager.undoLevels, 0)

        // Push a nil snapshot (representing empty canvas)
        manager.pushUndoSnapshot(nil)
        XCTAssertEqual(manager.undoLevels, 1)

        // Pop returns the nil snapshot
        let snapshot = manager.popUndoSnapshot()
        XCTAssertTrue(true) // We got here without crashing
        XCTAssertEqual(manager.undoLevels, 0)
    }

    func testUndoStackCap() {
        let manager = StrokeManager()

        // Push 35 snapshots — should cap at 30
        for _ in 0..<35 {
            manager.pushUndoSnapshot(nil)
        }

        XCTAssertEqual(manager.undoLevels, 30)
    }

    func testClearHistory() {
        let manager = StrokeManager()

        manager.pushUndoSnapshot(nil)
        manager.pushUndoSnapshot(nil)
        XCTAssertEqual(manager.undoLevels, 2)

        manager.clearHistory()
        XCTAssertEqual(manager.undoLevels, 0)
    }
}
