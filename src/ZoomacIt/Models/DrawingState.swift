import AppKit

/// Available pen/text colors.
enum PenColor: Sendable {
    case red, green, blue, orange, yellow, pink

    var nsColor: NSColor {
        switch self {
        case .red:    return .systemRed
        case .green:  return .systemGreen
        case .blue:   return .systemBlue
        case .orange: return .systemOrange
        case .yellow: return .systemYellow
        case .pink:   return .systemPink
        }
    }

    /// Map from key character to pen color.
    static func from(character: String) -> PenColor? {
        switch character.uppercased() {
        case "R": return .red
        case "G": return .green
        case "B": return .blue
        case "O": return .orange
        case "Y": return .yellow
        case "P": return .pink
        default:  return nil
        }
    }
}

/// Blur effect strength.
enum BlurStrength: Sendable {
    case weak
    case strong

    var radius: CGFloat {
        switch self {
        case .weak:   return 10.0
        case .strong: return 30.0
        }
    }
}

/// Mutable drawing state that drives the rendering.
final class DrawingState {

    // MARK: - Pen Properties

    var activeColor: PenColor = .red
    var penWidth: CGFloat = 3.0
    var isHighlighterMode: Bool = false

    // MARK: - Blur

    var isBlurMode: Bool = false
    var blurStrength: BlurStrength = .weak

    // MARK: - Text Mode

    var isTextMode: Bool = false

    // MARK: - Modifier Key Tracking

    /// Tab key must be tracked via keyDown/keyUp since it's not a modifier flag.
    var isTabHeld: Bool = false

    // MARK: - Background Mode

    enum BackgroundMode {
        case transparent  // draw on top of captured screen
        case whiteboard
        case blackboard
    }
    var backgroundMode: BackgroundMode = .transparent

    // MARK: - Derived

    /// The NSColor to use for drawing, applying highlighter alpha if needed.
    var currentNSColor: NSColor {
        let base = activeColor.nsColor
        return isHighlighterMode ? base.withAlphaComponent(0.35) : base
    }

    /// Determine the current shape type based on modifier flags and Tab key state.
    func currentShapeType(modifiers: NSEvent.ModifierFlags) -> ShapeType {
        let hasShift = modifiers.contains(.shift)
        let hasControl = modifiers.contains(.control)

        if isTabHeld {
            return .ellipse
        } else if hasShift && hasControl {
            return .arrow
        } else if hasShift {
            return .line
        } else if hasControl {
            return .rectangle
        } else {
            return .freehand
        }
    }

    // MARK: - Pen Size

    /// Increase pen width (capped at 50).
    func increasePenWidth() {
        penWidth = min(penWidth + 1.0, 50.0)
    }

    /// Decrease pen width (minimum 1).
    func decreasePenWidth() {
        penWidth = max(penWidth - 1.0, 1.0)
    }
}
