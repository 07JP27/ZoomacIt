import AppKit

/// Available pen/text colors.
enum PenColor: String, Sendable, CaseIterable {
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

/// Active sub-tool inside Draw mode.
enum DrawingTool {
    case draw       // freehand / shape / text — the existing Draw behavior
    case spotlight  // next drag creates the spotlight rectangle
}

/// Mutable drawing state that drives the rendering.
final class DrawingState {

    // MARK: - Pen Properties

    var activeColor: PenColor = Settings.shared.defaultPenColor
    var penWidth: CGFloat = Settings.shared.defaultPenWidth
    var isHighlighterMode: Bool = false

    // MARK: - Text Mode

    var isTextMode: Bool = false

    // MARK: - Modifier Key Tracking

    /// Tab key must be tracked via keyDown/keyUp since it's not a modifier flag.
    var isTabHeld: Bool = false

    // MARK: - Background Mode

    enum BackgroundMode {
        case transparent  // draw on transparent canvas (live desktop visible; frozen capture in Zoom→Draw)
        case whiteboard
        case blackboard
    }
    var backgroundMode: BackgroundMode = .transparent

    // MARK: - Spotlight

    var activeTool: DrawingTool = .draw

    /// The confirmed spotlight rectangle in view coordinates. `nil` means spotlight is off.
    var spotlightRect: CGRect?

    /// Darkness of the area outside the spotlight rectangle (0.1 ... 0.9).
    var spotlightDarkness: CGFloat = Settings.shared.spotlightDarkness

    static let spotlightDarknessMin: CGFloat = 0.1
    static let spotlightDarknessMax: CGFloat = 0.9
    static let spotlightDarknessStep: CGFloat = 0.05

    /// Increase spotlight darkness, capped at the max.
    func increaseSpotlightDarkness() {
        spotlightDarkness = min(spotlightDarkness + Self.spotlightDarknessStep, Self.spotlightDarknessMax)
    }

    /// Decrease spotlight darkness, capped at the min.
    func decreaseSpotlightDarkness() {
        spotlightDarkness = max(spotlightDarkness - Self.spotlightDarknessStep, Self.spotlightDarknessMin)
    }

    // MARK: - Derived

    /// The NSColor to use for drawing, applying highlighter alpha if needed.
    var currentNSColor: NSColor {
        let base = activeColor.nsColor
        return isHighlighterMode ? base.withAlphaComponent(Settings.shared.highlighterOpacity) : base
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
