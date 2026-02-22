import AppKit
import CoreGraphics
import ScreenCaptureKit

/// The main NSView subclass that implements the 3-layer compositing architecture
/// for Draw mode rendering.
///
/// Layer stack (bottom to top):
///   1. `finishedLayer` (CGImage)  — all confirmed strokes rasterized
///   2. `previewLayer`  (NSBezierPath) — shape preview during drag
///   3. `activeFreehand` (NSBezierPath) — freehand path during drag
final class DrawingCanvasView: NSView {

    // MARK: - Callbacks

    /// Called when the user exits draw mode (Escape / right-click).
    var onDismiss: (() -> Void)?

    // MARK: - State

    let drawingState = DrawingState()
    private let strokeManager = StrokeManager()

    /// Background image for Draw mode.
    /// - `nil` in live draw mode (transparent canvas, desktop shows through)
    /// - Set when entering via Zoom→Draw transition (frozen zoomed snapshot)
    private var backgroundImage: CGImage?

    // MARK: - 3-Layer Architecture

    /// Confirmed strokes rasterized into a single bitmap.
    private var finishedLayer: CGImage?

    /// Shape preview path during drag (line/rect/ellipse/arrow).
    private var previewLayer: NSBezierPath?

    /// Freehand path being drawn.
    private var activeFreehand: NSBezierPath?

    // MARK: - Drag State

    private var dragOrigin: CGPoint = .zero
    private var freehandPoints: [CGPoint] = []
    private var isDragging: Bool = false

    // MARK: - Text Mode

    private var textInputController: TextInputController?

    // MARK: - Init

    init(frame: NSRect, backgroundImage: CGImage?) {
        self.backgroundImage = backgroundImage
        super.init(frame: frame)
        wantsLayer = false  // Use draw(_:) based rendering, not layer-backed
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Cursor

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // 1. Draw background (captured screen or whiteboard/blackboard)
        drawBackground(in: context)

        // 2. Draw finishedLayer (all confirmed strokes)
        if let finished = finishedLayer {
            context.draw(finished, in: bounds)
        }

        // 3. Draw previewLayer (shape being dragged)
        if let preview = previewLayer {
            drawingState.currentNSColor.setStroke()
            if drawingState.isHighlighterMode {
                HighlighterRenderer.applyHighlighterStyle(to: preview, penWidth: drawingState.penWidth)
                // .multiply is invisible on transparent pixels; use .normal when no background image
                let blendMode: CGBlendMode = (backgroundImage != nil) ? .multiply : .normal
                NSGraphicsContext.current?.cgContext.setBlendMode(blendMode)
            } else {
                preview.lineWidth = drawingState.penWidth
                preview.lineCapStyle = .round
                preview.lineJoinStyle = .round
            }
            preview.stroke()
            NSGraphicsContext.current?.cgContext.setBlendMode(.normal)
        }

        // 4. Draw activeFreehand (freehand path being drawn)
        if let freehand = activeFreehand {
            drawingState.currentNSColor.setStroke()
            if drawingState.isHighlighterMode {
                HighlighterRenderer.applyHighlighterStyle(to: freehand, penWidth: drawingState.penWidth)
                let blendMode: CGBlendMode = (backgroundImage != nil) ? .multiply : .normal
                NSGraphicsContext.current?.cgContext.setBlendMode(blendMode)
            } else {
                freehand.lineWidth = drawingState.penWidth
                freehand.lineCapStyle = .round
                freehand.lineJoinStyle = .round
            }
            freehand.stroke()
            NSGraphicsContext.current?.cgContext.setBlendMode(.normal)
        }
    }

    private func drawBackground(in context: CGContext) {
        switch drawingState.backgroundMode {
        case .transparent:
            if let bg = backgroundImage {
                context.draw(bg, in: bounds)
            }
        case .whiteboard:
            context.setFillColor(NSColor.white.cgColor)
            context.fill(bounds)
        case .blackboard:
            context.setFillColor(NSColor.black.cgColor)
            context.fill(bounds)
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        if drawingState.isTextMode {
            // In text mode, clicks position the text field
            handleTextModeClick(event)
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        dragOrigin = point
        freehandPoints = [point]
        isDragging = true

        activeFreehand = NSBezierPath()
        activeFreehand?.move(to: point)
        previewLayer = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }

        let currentPoint = convert(event.locationInWindow, from: nil)
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let shapeType = drawingState.currentShapeType(modifiers: modifiers)

        switch shapeType {
        case .freehand:
            freehandPoints.append(currentPoint)
            activeFreehand = FreehandRenderer.smoothedPath(from: freehandPoints)
            previewLayer = nil

        case .line:
            previewLayer = ShapeRenderer.linePath(from: dragOrigin, to: currentPoint)
            activeFreehand = nil

        case .rectangle:
            previewLayer = ShapeRenderer.rectanglePath(from: dragOrigin, to: currentPoint)
            activeFreehand = nil

        case .ellipse:
            previewLayer = ShapeRenderer.ellipsePath(from: dragOrigin, to: currentPoint)
            activeFreehand = nil

        case .arrow:
            previewLayer = ShapeRenderer.arrowPath(from: dragOrigin, to: currentPoint)
            activeFreehand = nil
        }

        setNeedsDisplay(bounds)
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false

        let currentPoint = convert(event.locationInWindow, from: nil)
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let shapeType = drawingState.currentShapeType(modifiers: modifiers)

        // Push current state for undo
        strokeManager.pushUndoSnapshot(finishedLayer, backgroundMode: drawingState.backgroundMode)

        // Composite the completed stroke onto finishedLayer
        finishedLayer = compositeStrokeOntoFinished(
            shapeType: shapeType,
            endPoint: currentPoint
        )

        // Clear transient layers
        previewLayer = nil
        activeFreehand = nil
        freehandPoints.removeAll()

        setNeedsDisplay(bounds)
    }

    override func rightMouseDown(with event: NSEvent) {
        // If in text mode, commit current text first
        if drawingState.isTextMode {
            commitCurrentText()
        }
        // Right-click exits draw mode
        onDismiss?()
    }

    // MARK: - Keyboard Events

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers?.uppercased() else { return }
        let modifiers = event.modifierFlags

        switch characters {
        // Exit draw mode
        case "\u{1B}": // Escape
            if drawingState.isTextMode {
                commitText()
            } else {
                onDismiss?()
            }

        // Color keys
        case "R", "G", "B", "O", "Y", "P":
            if let color = PenColor.from(character: characters) {
                if modifiers.contains(.shift) {
                    drawingState.isHighlighterMode = true
                } else {
                    drawingState.isHighlighterMode = false
                }
                drawingState.activeColor = color
                if drawingState.isTextMode {
                    textInputController?.updateColor(drawingState.currentNSColor)
                }
            }

        // Clear all
        case "E":
            strokeManager.pushUndoSnapshot(finishedLayer, backgroundMode: drawingState.backgroundMode)
            finishedLayer = nil
            setNeedsDisplay(bounds)

        // Whiteboard
        case "W":
            strokeManager.pushUndoSnapshot(finishedLayer, backgroundMode: drawingState.backgroundMode)
            drawingState.backgroundMode = .whiteboard
            finishedLayer = nil
            setNeedsDisplay(bounds)

        // Blackboard
        case "K":
            strokeManager.pushUndoSnapshot(finishedLayer, backgroundMode: drawingState.backgroundMode)
            drawingState.backgroundMode = .blackboard
            finishedLayer = nil
            setNeedsDisplay(bounds)

        // Text mode
        case "T":
            enterTextMode()

        // Blur (not yet fully wired — sets state for future integration)
        case "X":
            NSLog("[DrawingCanvasView] Blur mode activated (rendering not yet implemented)")
            drawingState.isBlurMode = true
            drawingState.blurStrength = modifiers.contains(.shift) ? .strong : .weak

        // Tab key for ellipse (track as key, not modifier)
        case "\t":
            drawingState.isTabHeld = true

        // Space — move cursor to center
        case " ":
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let screenCenter = window?.convertPoint(toScreen: convert(center, to: nil)) ?? center
            CGWarpMouseCursorPosition(screenCenter)

        // Undo (⌘Z is handled here since we're key)
        case "Z" where modifiers.contains(.command):
            performUndo()

        // Copy to clipboard (⌘C)
        case "C" where modifiers.contains(.command):
            Task {
                await copyToClipboard()
            }

        // Save to file (⌘S)
        case "S" where modifiers.contains(.command):
            Task {
                await saveToFile()
            }

        default:
            break
        }
    }

    override func keyUp(with event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers else { return }
        if characters == "\t" {
            drawingState.isTabHeld = false
        }
    }

    override func flagsChanged(with event: NSEvent) {
        // Modifier changes during drag cause shape type to update.
        // The actual shape determination happens in mouseDragged via currentShapeType().
        if isDragging {
            // Trigger a "drag" update with current position
            mouseDragged(with: event)
        }
    }

    // MARK: - Scroll Wheel (Pen Size)

    override func scrollWheel(with event: NSEvent) {
        let modifiers = event.modifierFlags

        if drawingState.isTextMode {
            // In text mode, scroll wheel changes font size
            textInputController?.adjustFontSize(delta: event.scrollingDeltaY)
            return
        }

        if modifiers.contains(.control) {
            // ⌃ + scroll wheel → pen size
            if event.scrollingDeltaY > 0 {
                drawingState.increasePenWidth()
            } else if event.scrollingDeltaY < 0 {
                drawingState.decreasePenWidth()
            }
        }
    }

    // MARK: - Compositing

    /// Renders the current stroke onto finishedLayer and returns the new CGImage.
    private func compositeStrokeOntoFinished(shapeType: ShapeType, endPoint: CGPoint) -> CGImage? {
        let size = bounds.size
        guard size.width > 0 && size.height > 0 else { return finishedLayer }

        guard let bitmapContext = CGContext.createBitmapContext(size: size) else {
            return finishedLayer
        }

        // Draw existing finished layer
        if let existing = finishedLayer {
            bitmapContext.draw(existing, in: CGRect(origin: .zero, size: size))
        }

        // Set stroke properties
        let color = drawingState.currentNSColor
        if drawingState.isHighlighterMode {
            // .multiply is invisible on transparent pixels; use .normal when no background image
            let blendMode: CGBlendMode = (backgroundImage != nil) ? .multiply : .normal
            bitmapContext.setBlendMode(blendMode)
            bitmapContext.setStrokeColor(color.cgColor)
            bitmapContext.setLineWidth(drawingState.penWidth * 2.0)
            bitmapContext.setLineCap(.square)
            bitmapContext.setLineJoin(.round)
        } else {
            bitmapContext.setStrokeColor(color.cgColor)
            bitmapContext.setLineWidth(drawingState.penWidth)
            bitmapContext.setLineCap(.round)
            bitmapContext.setLineJoin(.round)
        }

        // Draw the stroke
        let path: CGPath
        switch shapeType {
        case .freehand:
            let bezier = FreehandRenderer.smoothedPath(from: freehandPoints)
            path = bezier.cgPath
        case .line:
            path = ShapeRenderer.linePath(from: dragOrigin, to: endPoint).cgPath
        case .rectangle:
            path = ShapeRenderer.rectanglePath(from: dragOrigin, to: endPoint).cgPath
        case .ellipse:
            path = ShapeRenderer.ellipsePath(from: dragOrigin, to: endPoint).cgPath
        case .arrow:
            path = ShapeRenderer.arrowPath(from: dragOrigin, to: endPoint).cgPath
        }

        bitmapContext.addPath(path)
        bitmapContext.strokePath()

        return bitmapContext.makeImage()
    }

    // MARK: - Undo

    private func performUndo() {
        if let snapshot = strokeManager.popUndoSnapshot() {
            finishedLayer = snapshot.finishedLayer
            drawingState.backgroundMode = snapshot.backgroundMode
        } else {
            finishedLayer = nil
        }
        setNeedsDisplay(bounds)
    }

    // MARK: - Text Mode

    private func enterTextMode() {
        drawingState.isTextMode = true
        let controller = TextInputController(canvasView: self, drawingState: drawingState)
        controller.onCommit = { [weak self] in
            self?.commitText()
        }
        textInputController = controller
    }

    private func handleTextModeClick(_ event: NSEvent) {
        // Commit any existing text before placing a new text field
        commitCurrentText()
        let point = convert(event.locationInWindow, from: nil)
        textInputController?.placeTextField(at: point)
    }

    /// Rasterize current text into finishedLayer without leaving text mode.
    private func commitCurrentText() {
        guard let controller = textInputController, controller.hasText else { return }
        strokeManager.pushUndoSnapshot(finishedLayer, backgroundMode: drawingState.backgroundMode)
        finishedLayer = controller.rasterizeAndComposite(onto: finishedLayer, canvasSize: bounds.size)
        controller.cleanup()
        setNeedsDisplay(bounds)
    }

    /// Commit current text and exit text mode (return to pen mode).
    private func commitText() {
        commitCurrentText()
        textInputController?.cleanup()
        textInputController = nil
        drawingState.isTextMode = false
        setNeedsDisplay(bounds)
    }

    // MARK: - Export

    private func copyToClipboard() async {
        guard let image = await renderFinalImage() else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let nsImage = NSImage(cgImage: image, size: bounds.size)
        pasteboard.writeObjects([nsImage])
    }

    private func saveToFile() async {
        guard let image = await renderFinalImage() else { return }
        guard let window = self.window else { return }

        // Hide the overlay so the save panel is accessible.
        // The rendered image is already captured, so the data is safe.
        window.orderOut(nil)

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "ZoomacIt-draw.png"

        let response = await withCheckedContinuation { continuation in
            savePanel.begin { panelResponse in
                continuation.resume(returning: panelResponse)
            }
        }

        // Restore overlay
        window.makeKeyAndOrderFront(nil)

        guard response == .OK, let url = savePanel.url else { return }

        let nsImage = NSImage(cgImage: image, size: self.bounds.size)
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return }

        try? pngData.write(to: url)
    }

    /// Renders the full canvas (background + finishedLayer) as a CGImage.
    /// When in live draw mode (no backgroundImage), captures the current desktop on demand.
    private func renderFinalImage() async -> CGImage? {
        let size = bounds.size
        guard let context = CGContext.createBitmapContext(size: size) else { return nil }

        // Background
        switch drawingState.backgroundMode {
        case .transparent:
            if let bg = backgroundImage {
                // Zoom→Draw transition: use frozen snapshot
                context.draw(bg, in: CGRect(origin: .zero, size: size))
            } else {
                // Live draw mode: capture desktop on demand (excluding our overlay)
                if let captured = await captureDesktopExcludingOverlay() {
                    context.draw(captured, in: CGRect(origin: .zero, size: size))
                }
                // If capture fails (no permission), export as transparent PNG
            }
        case .whiteboard:
            context.setFillColor(NSColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
        case .blackboard:
            context.setFillColor(NSColor.black.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
        }

        // Finished strokes
        if let finished = finishedLayer {
            context.draw(finished, in: CGRect(origin: .zero, size: size))
        }

        return context.makeImage()
    }

    // MARK: - On-Demand Desktop Capture

    /// Captures the current desktop excluding the overlay window.
    /// Uses ScreenCaptureKit's excludingWindows filter to avoid flicker.
    private func captureDesktopExcludingOverlay() async -> CGImage? {
        guard CGPreflightScreenCaptureAccess() else {
            NSLog("[DrawingCanvasView] Screen Recording not permitted — exporting strokes only.")
            return nil
        }

        guard let screen = window?.screen ?? NSScreen.main else { return nil }
        let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGMainDisplayID()
        let scaleFactor = screen.backingScaleFactor

        do {
            let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = availableContent.displays.first(where: { $0.displayID == screenNumber }) else {
                NSLog("[DrawingCanvasView] Display not found for on-demand capture.")
                return nil
            }

            // Exclude our overlay window from the capture
            let excludedWindows: [SCWindow]
            if let overlayWindowNumber = window?.windowNumber, overlayWindowNumber > 0 {
                excludedWindows = availableContent.windows.filter { $0.windowID == CGWindowID(overlayWindowNumber) }
            } else {
                NSLog("[DrawingCanvasView] Overlay windowNumber unavailable; proceeding without exclusion.")
                excludedWindows = []
            }

            let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
            let config = SCStreamConfiguration()
            config.width = Int(screen.frame.width * scaleFactor)
            config.height = Int(screen.frame.height * scaleFactor)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = false

            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            NSLog("[DrawingCanvasView] On-demand capture failed: %@", error.localizedDescription)
            return nil
        }
    }
}
