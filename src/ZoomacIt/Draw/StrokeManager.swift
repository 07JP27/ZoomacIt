import AppKit
import CoreGraphics

/// A snapshot of the canvas state for undo.
struct UndoSnapshot {
    let finishedLayer: CGImage?
    let backgroundMode: DrawingState.BackgroundMode
}

/// Manages undo history using snapshots of the canvas state.
final class StrokeManager {

    /// Maximum number of undo snapshots to retain.
    /// Each snapshot is a full-resolution CGImage — memory usage = width * height * 4 bytes.
    private let maxUndoLevels = 30

    /// Stack of canvas state snapshots for undo.
    private var undoStack: [UndoSnapshot] = []

    // MARK: - Undo

    /// Push the current canvas state onto the undo stack.
    func pushUndoSnapshot(_ finishedLayer: CGImage?, backgroundMode: DrawingState.BackgroundMode = .transparent) {
        undoStack.append(UndoSnapshot(finishedLayer: finishedLayer, backgroundMode: backgroundMode))

        // Cap the stack to prevent unbounded memory growth
        if undoStack.count > maxUndoLevels {
            undoStack.removeFirst()
        }
    }

    /// Pop and return the most recent snapshot, or nil if the stack is empty.
    func popUndoSnapshot() -> UndoSnapshot? {
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
