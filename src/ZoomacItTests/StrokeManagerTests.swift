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

        // Pop returns the snapshot with nil finishedLayer and default backgroundMode
        let snapshot = manager.popUndoSnapshot()
        XCTAssertNotNil(snapshot, "Stack was not empty, should return a snapshot")
        XCTAssertNil(snapshot?.finishedLayer, "Popped snapshot should have nil finishedLayer since we pushed nil")
        XCTAssertEqual(manager.undoLevels, 0)
    }

    func testPushAndPopSnapshotWithBackgroundMode() {
        let manager = StrokeManager()

        manager.pushUndoSnapshot(nil, backgroundMode: .whiteboard)
        let snapshot = manager.popUndoSnapshot()
        XCTAssertNotNil(snapshot)
        // Verify backgroundMode is preserved through push/pop
        switch snapshot?.backgroundMode {
        case .whiteboard:
            break // expected
        default:
            XCTFail("Expected whiteboard background mode")
        }
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
