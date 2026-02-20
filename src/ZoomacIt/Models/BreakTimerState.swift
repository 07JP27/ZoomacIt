import AppKit

/// Position of the timer text on screen (3×3 grid).
enum BreakTimerPosition: Int, Sendable, CaseIterable {
    case topLeft, topCenter, topRight
    case middleLeft, center, middleRight
    case bottomLeft, bottomCenter, bottomRight

    /// Returns the origin point for a text bounding box of the given size,
    /// centered within the specified cell of a 3×3 grid over `screenFrame`.
    func origin(forTextSize textSize: NSSize, in screenFrame: NSRect) -> NSPoint {
        let margin: CGFloat = 40
        let col = self.rawValue % 3
        let row = 2 - (self.rawValue / 3) // flip: row 0 = top → NSView row 2

        let x: CGFloat
        switch col {
        case 0:  x = margin
        case 1:  x = (screenFrame.width - textSize.width) / 2
        default: x = screenFrame.width - textSize.width - margin
        }

        let y: CGFloat
        switch row {
        case 0:  y = margin
        case 1:  y = (screenFrame.height - textSize.height) / 2
        default: y = screenFrame.height - textSize.height - margin
        }

        return NSPoint(x: x, y: y)
    }
}

/// Background mode for the break timer screen.
enum BreakTimerBackground: Sendable {
    case black
    case fadedDesktop
    // Phase 2: case customImage(URL)
}

/// Mutable state for the Break Timer feature.
final class BreakTimerState {

    // MARK: - Timer

    /// Default countdown duration in seconds (persisted via UserDefaults in Phase 2).
    var defaultDuration: Int = 600 // 10 minutes

    /// Seconds remaining in the countdown. Stops at 0.
    var remainingSeconds: Int = 600

    /// Whether the timer has reached zero.
    var isExpired: Bool { remainingSeconds <= 0 }

    /// Seconds elapsed after the timer expired (counts up from 0).
    var elapsedSinceExpiration: Int = 0

    // MARK: - Appearance

    /// Timer text color — reuses PenColor from Draw.
    var timerColor: PenColor = .red

    /// Position on the 3×3 grid.
    var position: BreakTimerPosition = .center

    /// Timer text opacity (0.1 … 1.0).
    var opacity: CGFloat = 1.0

    /// Background mode.
    var background: BreakTimerBackground = .black

    // MARK: - Options

    /// Show elapsed time after expiration.
    var showElapsed: Bool = true

    /// Play a sound when time expires.
    var playSoundOnExpiration: Bool = false

    /// Custom sound file URL (nil = system default).
    var soundFileURL: URL?

    // MARK: - Methods

    /// Adjust remaining time by the given number of minutes.
    /// Clamps to a minimum of 0 seconds.
    func adjustTime(byMinutes minutes: Int) {
        let newValue = remainingSeconds + (minutes * 60)
        remainingSeconds = max(0, newValue)
        // If time was added after expiration, reset elapsed counter
        if remainingSeconds > 0 {
            elapsedSinceExpiration = 0
        }
    }

    /// Tick the timer by one second. Returns `true` if the timer just expired (transition to 0).
    @discardableResult
    func tick() -> Bool {
        if remainingSeconds > 0 {
            remainingSeconds -= 1
            if remainingSeconds == 0 {
                return true // just expired
            }
        } else {
            elapsedSinceExpiration += 1
        }
        return false
    }

    // MARK: - Formatting

    /// Formatted remaining time, e.g. "10:00", "1:01", "0:00".
    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Formatted elapsed time after expiration, e.g. "(1:15)".
    var formattedElapsed: String {
        let minutes = elapsedSinceExpiration / 60
        let seconds = elapsedSinceExpiration % 60
        return String(format: "(%d:%02d)", minutes, seconds)
    }
}
