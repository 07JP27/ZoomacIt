import AppKit
import CoreGraphics

/// Manages undo history using CGImage snapshots of the finishedLayer.
final class StrokeManager {

    /// Maximum number of undo snapshots to retain.
    /// Each snapshot is a full-resolution CGImage — memory usage = width * height * 4 bytes.
    private let maxUndoLevels = 30

    /// Stack of finishedLayer snapshots for undo.
    private var undoStack: [CGImage?] = []

    // MARK: - Undo

    /// Push the current finishedLayer state onto the undo stack.
    func pushUndoSnapshot(_ finishedLayer: CGImage?) {
        undoStack.append(finishedLayer)

        // Cap the stack to prevent unbounded memory growth
        if undoStack.count > maxUndoLevels {
            undoStack.removeFirst()
        }
    }

    /// Pop and return the most recent snapshot, or nil if the stack is empty.
    func popUndoSnapshot() -> CGImage? {
        guard !undoStack.isEmpty else { return nil }
        return undoStack.removeLast()
    }

    /// Returns the number of available undo levels.
    var undoLevels: Int {
        undoStack.count
    }

    /// Clears all undo history.
    func clearHistory() {
        undoStack.removeAll()
    }
}
