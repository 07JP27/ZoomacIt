import AppKit

/// NSView that renders the Break Timer countdown, handles keyboard events
/// for time adjustment and color changes.
@MainActor
final class BreakTimerView: NSView {

    // MARK: - Properties

    let state: BreakTimerState

    /// Optional captured desktop image for faded background.
    var capturedImage: CGImage?

    /// Called when the user presses Escape to dismiss the timer.
    var onDismiss: (() -> Void)?

    /// Whether the elapsed line has been revealed (for animation).
    private var elapsedRevealed: Bool = false

    // MARK: - Init

    init(frame: NSRect, state: BreakTimerState, capturedImage: CGImage? = nil) {
        self.state = state
        self.capturedImage = capturedImage
        super.init(frame: frame)
        NSLog("[BreakTimerView] Initialized with frame %@", NSStringFromRect(frame))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Key Handling

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard let chars = event.charactersIgnoringModifiers else { return }

        switch event.keyCode {
        case 0x7E: // Arrow Up
            state.adjustTime(byMinutes: 1)
            needsDisplay = true
            NSLog("[BreakTimerView] Time adjusted +1 min → %@", state.formattedTime)

        case 0x7D: // Arrow Down
            state.adjustTime(byMinutes: -1)
            needsDisplay = true
            NSLog("[BreakTimerView] Time adjusted -1 min → %@", state.formattedTime)

        case 0x35: // Escape
            NSLog("[BreakTimerView] Escape pressed — dismissing timer")
            onDismiss?()

        default:
            // Color keys
            if let color = PenColor.from(character: chars) {
                state.timerColor = color
                needsDisplay = true
                NSLog("[BreakTimerView] Timer color changed to %@", chars.uppercased())
            }
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let bounds = self.bounds

        // 1. Draw background
        drawBackground(in: ctx, bounds: bounds)

        // 2. Calculate font sizes
        let mainFontSize = bounds.height / 5
        let elapsedFontSize = mainFontSize * 0.4
        let mainFont = NSFont.monospacedDigitSystemFont(ofSize: mainFontSize, weight: .bold)
        let elapsedFont = NSFont.monospacedDigitSystemFont(ofSize: elapsedFontSize, weight: .medium)
        let timerNSColor = state.timerColor.nsColor.withAlphaComponent(state.opacity)

        // 3. Calculate main timer text size
        let mainText = state.formattedTime
        let mainAttrs: [NSAttributedString.Key: Any] = [
            .font: mainFont,
            .foregroundColor: timerNSColor
        ]
        let mainSize = (mainText as NSString).size(withAttributes: mainAttrs)

        // 4. Calculate total bounding box (main + optional elapsed)
        var totalHeight = mainSize.height
        var elapsedSize = NSSize.zero
        let elapsedSpacing: CGFloat = 8

        if state.isExpired && state.showElapsed {
            let elapsedText = state.formattedElapsed
            let elapsedAttrs: [NSAttributedString.Key: Any] = [
                .font: elapsedFont,
                .foregroundColor: timerNSColor
            ]
            elapsedSize = (elapsedText as NSString).size(withAttributes: elapsedAttrs)
            totalHeight += elapsedSpacing + elapsedSize.height
        }

        let totalSize = NSSize(
            width: max(mainSize.width, elapsedSize.width),
            height: totalHeight
        )

        // 5. Position based on grid
        let origin = state.position.origin(forTextSize: totalSize, in: bounds)

        // 6. Draw main timer text
        let mainOrigin = NSPoint(
            x: origin.x + (totalSize.width - mainSize.width) / 2,
            y: origin.y + totalHeight - mainSize.height
        )
        (mainText as NSString).draw(at: mainOrigin, withAttributes: mainAttrs)

        // 7. Draw elapsed text if expired
        if state.isExpired && state.showElapsed {
            let elapsedText = state.formattedElapsed
            let elapsedAttrs: [NSAttributedString.Key: Any] = [
                .font: elapsedFont,
                .foregroundColor: timerNSColor
            ]
            let elapsedOrigin = NSPoint(
                x: origin.x + (totalSize.width - elapsedSize.width) / 2,
                y: origin.y
            )

            // Animate elapsed appearance
            if !elapsedRevealed {
                elapsedRevealed = true
                // First frame: use reduced alpha for fade-in effect
                let fadedAttrs: [NSAttributedString.Key: Any] = [
                    .font: elapsedFont,
                    .foregroundColor: timerNSColor.withAlphaComponent(0.3)
                ]
                (elapsedText as NSString).draw(at: elapsedOrigin, withAttributes: fadedAttrs)
            } else {
                (elapsedText as NSString).draw(at: elapsedOrigin, withAttributes: elapsedAttrs)
            }
        } else {
            elapsedRevealed = false
        }
    }

    // MARK: - Background

    private func drawBackground(in ctx: CGContext, bounds: NSRect) {
        switch state.background {
        case .black:
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fill(bounds)

        case .fadedDesktop:
            if let image = capturedImage {
                // Draw the captured image darkened
                ctx.saveGState()
                ctx.draw(image, in: bounds)
                // Overlay semi-transparent black to darken
                ctx.setFillColor(NSColor.black.withAlphaComponent(Settings.shared.breakTimerBackgroundFadeDarkness).cgColor)
                ctx.fill(bounds)
                ctx.restoreGState()
            } else {
                // Fallback to black if no capture available
                ctx.setFillColor(NSColor.black.cgColor)
                ctx.fill(bounds)
            }
        }
    }
}
