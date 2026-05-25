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

    /// Live spotlight rectangle preview while the user is dragging.
    /// `nil` outside of an active spotlight drag.
    private var spotlightDragRect: CGRect?

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
        let cursor: NSCursor
        switch drawingState.activeTool {
        case .spotlight:
            cursor = Self.spotlightCursor
        default:
            let mods = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let shapeType = drawingState.currentShapeType(modifiers: mods)
            cursor = shapeType == .freehand ? penCursor() : crosshairCursor()
        }
        addCursorRect(bounds, cursor: cursor)
    }

    /// Generates a circular cursor matching the current pen colour and width (freehand mode).
    private func penCursor() -> NSCursor {
        let penWidth = drawingState.penWidth
        let color = drawingState.currentNSColor
        let size = max(penWidth * 2, 8)
        let imageSize = NSSize(width: size + 4, height: size + 4)

        let image = NSImage(size: imageSize, flipped: false) { _ in
            let rect = NSRect(x: 2, y: 2, width: size, height: size)
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()
            NSColor.white.withAlphaComponent(0.8).setStroke()
            let border = NSBezierPath(ovalIn: rect)
            border.lineWidth = 0.5
            border.stroke()
            return true
        }

        let hotSpot = NSPoint(x: imageSize.width / 2, y: imageSize.height / 2)
        return NSCursor(image: image, hotSpot: hotSpot)
    }

    /// Generates a crosshair cursor scaled by pen width (shape modes).
    private func crosshairCursor() -> NSCursor {
        let penWidth = drawingState.penWidth
        let color = drawingState.currentNSColor
        let armLength = min(max(penWidth * 1.5, 8), 40)
        let thickness = min(max(penWidth, 1), 10)
        let size = armLength * 2 + thickness + 6
        let center = size / 2

        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            // Outer contrast stroke (black)
            NSColor.black.withAlphaComponent(0.4).setStroke()
            let outerH = NSBezierPath()
            outerH.move(to: NSPoint(x: center - armLength, y: center))
            outerH.line(to: NSPoint(x: center + armLength, y: center))
            outerH.lineWidth = thickness + 2
            outerH.lineCapStyle = .round
            outerH.stroke()

            let outerV = NSBezierPath()
            outerV.move(to: NSPoint(x: center, y: center - armLength))
            outerV.line(to: NSPoint(x: center, y: center + armLength))
            outerV.lineWidth = thickness + 2
            outerV.lineCapStyle = .round
            outerV.stroke()

            // Inner colored stroke
            color.setStroke()
            let innerH = NSBezierPath()
            innerH.move(to: NSPoint(x: center - armLength, y: center))
            innerH.line(to: NSPoint(x: center + armLength, y: center))
            innerH.lineWidth = thickness
            innerH.lineCapStyle = .round
            innerH.stroke()

            let innerV = NSBezierPath()
            innerV.move(to: NSPoint(x: center, y: center - armLength))
            innerV.line(to: NSPoint(x: center, y: center + armLength))
            innerV.lineWidth = thickness
            innerV.lineCapStyle = .round
            innerV.stroke()

            return true
        }

        return NSCursor(image: image, hotSpot: NSPoint(x: center, y: center))
    }

    /// Minimum width and height (points) for a spotlight rectangle to be confirmed
    /// on mouseUp. Drags smaller than this are treated as accidental clicks /
    /// micro-drags and discarded — chosen above AppKit's ~3pt drag threshold so
    /// the gesture has to be visibly intentional.
    private static let spotlightMinSize: CGFloat = 10

    /// Custom cursor used while the spotlight tool is armed.
    /// Reuses the system crosshair image and overlays a small dashed-rectangle
    /// badge in the lower-right corner so it reads as "drag a rectangle".
    private static let spotlightCursor: NSCursor = {
        let baseCursor = NSCursor.crosshair
        let baseImage = baseCursor.image
        let baseSize = baseImage.size
        let baseHotspot = baseCursor.hotSpot

        // The system crosshair image has a lot of transparent padding around the
        // visible cross. We overlap the badge into that padding so it sits close
        // to the bottom-right arm of the cross instead of floating away from it.
        let badgeWidth: CGFloat = 9
        let badgeHeight: CGFloat = 6
        let badgeOverlap: CGFloat = 6  // how far the badge intrudes into the base image
        let canvasSize = NSSize(
            width: baseSize.width + badgeWidth - badgeOverlap,
            height: baseSize.height + badgeHeight - badgeOverlap
        )

        let composed = NSImage(size: canvasSize, flipped: false) { _ in
            // Draw the system crosshair anchored to the top-left.
            // Image coordinates are bottom-up, so the crosshair's bottom edge
            // sits at y = (canvasSize.height - baseSize.height).
            let baseOrigin = NSPoint(x: 0, y: canvasSize.height - baseSize.height)
            baseImage.draw(at: baseOrigin, from: .zero, operation: .sourceOver, fraction: 1.0)

            // Badge in the bottom-right, partially overlapping the crosshair's padding.
            let badgeRect = NSRect(
                x: canvasSize.width - badgeWidth - 0.5,
                y: 0.5,
                width: badgeWidth,
                height: badgeHeight
            )

            // Outline for visibility on any background.
            NSColor.black.setStroke()
            let outline = NSBezierPath(rect: badgeRect)
            outline.lineWidth = 1.5
            outline.stroke()

            // Dashed white rectangle on top — reads as a "selection / spotlight" hint.
            NSColor.white.setStroke()
            let dashed = NSBezierPath(rect: badgeRect)
            dashed.lineWidth = 1
            dashed.setLineDash([1.5, 1.5], count: 2, phase: 0)
            dashed.stroke()

            return true
        }

        // Hot spot is measured from the top-left in NSCursor, so the x is unchanged
        // and the y matches the system crosshair's hot spot directly (we placed the
        // base image flush with the top of the padded canvas).
        return NSCursor(image: composed, hotSpot: baseHotspot)
    }()

    /// Refresh the cursor after the active tool changes.
    private func updateCursorForTool() {
        window?.invalidateCursorRects(for: self)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // 1. Draw background (captured screen or whiteboard/blackboard)
        drawBackground(in: context)

        // 1.5 Spotlight mask — drawn between background and strokes so that
        // strokes (finished, preview, freehand) always sit on top of the dim layer.
        if let dragRect = spotlightDragRect {
            drawSpotlightMask(rect: dragRect, in: context)
        } else if let confirmedRect = drawingState.spotlightRect {
            drawSpotlightMask(rect: confirmedRect, in: context)
        }

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

    /// Darken everything outside `rect`. The rectangle area itself is left untouched
    /// (the layer below the spotlight stays visible).
    private func drawSpotlightMask(rect: CGRect, in context: CGContext) {
        let normalized = rect.standardized
        context.saveGState()
        context.setFillColor(NSColor.black.withAlphaComponent(drawingState.spotlightDarkness).cgColor)
        context.fill(bounds)
        context.setBlendMode(.clear)
        context.fill(normalized)
        context.restoreGState()
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

        if drawingState.activeTool == .spotlight {
            spotlightDragRect = CGRect(origin: point, size: .zero)
            isDragging = true
            previewLayer = nil
            activeFreehand = nil
            return
        }

        freehandPoints = [point]
        isDragging = true

        activeFreehand = NSBezierPath()
        activeFreehand?.move(to: point)
        previewLayer = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }

        let currentPoint = convert(event.locationInWindow, from: nil)

        if drawingState.activeTool == .spotlight {
            spotlightDragRect = CGRect(
                x: dragOrigin.x,
                y: dragOrigin.y,
                width: currentPoint.x - dragOrigin.x,
                height: currentPoint.y - dragOrigin.y
            )
            setNeedsDisplay(bounds)
            return
        }

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
            previewLayer = ShapeRenderer.arrowPath(from: dragOrigin, to: currentPoint, penWidth: drawingState.penWidth)
            activeFreehand = nil
        }

        setNeedsDisplay(bounds)
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false

        if drawingState.activeTool == .spotlight {
            // Confirm the spotlight rectangle and auto-return to the draw tool.
            // Reject tiny gestures (clicks, accidental micro-drags) so they don't
            // create unusable spotlights or push a phantom undo snapshot that
            // would silently evict older legitimate entries from the 30-slot stack.
            if let dragRect = spotlightDragRect,
               dragRect.standardized.width > Self.spotlightMinSize,
               dragRect.standardized.height > Self.spotlightMinSize {
                strokeManager.pushUndoSnapshot(
                    finishedLayer,
                    backgroundMode: drawingState.backgroundMode,
                    spotlightRect: drawingState.spotlightRect
                )
                drawingState.spotlightRect = dragRect.standardized
            }
            spotlightDragRect = nil
            drawingState.activeTool = .draw
            updateCursorForTool()
            setNeedsDisplay(bounds)
            return
        }

        let currentPoint = convert(event.locationInWindow, from: nil)
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let shapeType = drawingState.currentShapeType(modifiers: modifiers)

        // Push current state for undo
        strokeManager.pushUndoSnapshot(
            finishedLayer,
            backgroundMode: drawingState.backgroundMode,
            spotlightRect: drawingState.spotlightRect
        )

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
                updateCursorForTool()
            }

        // Clear all
        case "E":
            strokeManager.pushUndoSnapshot(
                finishedLayer,
                backgroundMode: drawingState.backgroundMode,
                spotlightRect: drawingState.spotlightRect
            )
            finishedLayer = nil
            setNeedsDisplay(bounds)

        // Whiteboard
        case "W":
            strokeManager.pushUndoSnapshot(
                finishedLayer,
                backgroundMode: drawingState.backgroundMode,
                spotlightRect: drawingState.spotlightRect
            )
            drawingState.backgroundMode = .whiteboard
            finishedLayer = nil
            setNeedsDisplay(bounds)

        // Blackboard
        case "K":
            strokeManager.pushUndoSnapshot(
                finishedLayer,
                backgroundMode: drawingState.backgroundMode,
                spotlightRect: drawingState.spotlightRect
            )
            drawingState.backgroundMode = .blackboard
            finishedLayer = nil
            setNeedsDisplay(bounds)

        // Text mode
        case "T":
            enterTextMode()

        // Tab key for ellipse (track as key, not modifier)
        case "\t":
            drawingState.isTabHeld = true
            updateCursorForTool()

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

        // Spotlight toggle (S without modifiers)
        case "S" where modifiers.intersection([.command, .control, .option, .shift]).isEmpty:
            toggleSpotlightTool()

        // Arrow keys — pen size (when no spotlight rect; ZoomIt-compatible)
        case String(UnicodeScalar(NSUpArrowFunctionKey)!)
            where drawingState.spotlightRect == nil:
            drawingState.increasePenWidth()
            updateCursorForTool()

        case String(UnicodeScalar(NSDownArrowFunctionKey)!)
            where drawingState.spotlightRect == nil:
            drawingState.decreasePenWidth()
            updateCursorForTool()

        // Spotlight darkness — only meaningful when a spotlight rect exists
        case String(UnicodeScalar(NSUpArrowFunctionKey)!)
            where drawingState.spotlightRect != nil
                && modifiers.intersection([.command, .control, .option, .shift]).isEmpty:
            drawingState.increaseSpotlightDarkness()
            setNeedsDisplay(bounds)

        case String(UnicodeScalar(NSDownArrowFunctionKey)!)
            where drawingState.spotlightRect != nil
                && modifiers.intersection([.command, .control, .option, .shift]).isEmpty:
            drawingState.decreaseSpotlightDarkness()
            setNeedsDisplay(bounds)

        default:
            break
        }
    }

    /// Toggle spotlight: arm the tool if no rect exists, otherwise clear the active rect.
    private func toggleSpotlightTool() {
        if drawingState.spotlightRect != nil {
            // Active spotlight → clear (and snapshot for undo).
            strokeManager.pushUndoSnapshot(
                finishedLayer,
                backgroundMode: drawingState.backgroundMode,
                spotlightRect: drawingState.spotlightRect
            )
            drawingState.spotlightRect = nil
            drawingState.activeTool = .draw
        } else {
            // No confirmed spotlight rect. Toggle the tool itself:
            //   .draw      → .spotlight  (arm — wait for the next drag)
            //   .spotlight → .draw       (cancel an armed spotlight before any drag)
            // No undo snapshot is pushed here because nothing has been committed yet.
            drawingState.activeTool = (drawingState.activeTool == .spotlight) ? .draw : .spotlight
        }
        updateCursorForTool()
        setNeedsDisplay(bounds)
    }

    override func keyUp(with event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers else { return }
        if characters == "\t" {
            drawingState.isTabHeld = false
            updateCursorForTool()
        }
    }

    override func flagsChanged(with event: NSEvent) {
        // Modifier changes during drag cause shape type to update.
        if isDragging {
            mouseDragged(with: event)
        }
        // Update cursor to reflect shape tool
        if drawingState.activeTool != .spotlight {
            updateCursorForTool()
        }
    }

    // MARK: - Scroll Wheel (Pen Size)

    override func scrollWheel(with event: NSEvent) {
        if drawingState.isTextMode {
            // In text mode, scroll wheel changes font size
            textInputController?.adjustFontSize(delta: event.scrollingDeltaY)
            return
        }

        // Scroll wheel → pen size (also works with Ctrl held for ZoomIt compatibility)
        if event.scrollingDeltaY > 0 {
            drawingState.increasePenWidth()
        } else if event.scrollingDeltaY < 0 {
            drawingState.decreasePenWidth()
        }
        updateCursorForTool()
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
            bitmapContext.setLineWidth(drawingState.penWidth * Settings.shared.highlighterWidthMultiplier)
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
            path = ShapeRenderer.arrowPath(from: dragOrigin, to: endPoint, penWidth: drawingState.penWidth).cgPath
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
            drawingState.spotlightRect = snapshot.spotlightRect
        } else {
            finishedLayer = nil
            drawingState.spotlightRect = nil
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
        strokeManager.pushUndoSnapshot(
            finishedLayer,
            backgroundMode: drawingState.backgroundMode,
            spotlightRect: drawingState.spotlightRect
        )
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

        // Spotlight mask — placed under the strokes so drawings remain visible
        // both inside and outside the spotlight rectangle.
        if let rect = drawingState.spotlightRect {
            let exportBounds = CGRect(origin: .zero, size: size)
            context.saveGState()
            context.setFillColor(NSColor.black.withAlphaComponent(drawingState.spotlightDarkness).cgColor)
            context.fill(exportBounds)
            context.setBlendMode(.clear)
            context.fill(rect.standardized)
            context.restoreGState()
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
