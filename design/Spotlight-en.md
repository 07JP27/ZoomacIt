## Spotlight Feature Detailed Specification

### Overview

A sub-tool that can be activated inside Draw mode and **"covers everything outside a focus rectangle with semi-transparent gray"**.
Used to emphasize "look here" during presentations or screen sharing. This is a ZoomacIt-original feature that does not exist in the Windows version of ZoomIt.

---

### A. Design Principles

#### 1. Integrate as a Sub-Tool of Draw Mode

Spotlight is implemented as a sub-tool inside Draw mode rather than as an independent mode (with a new hotkey like ⌃4).

**Reasons:**
- The goal of "drawing attention" is the same as Draw (arrows, circles). Adding new hotkeys reduces discoverability.
- The **combination** of Spotlight + drawing is powerful (drawing an arrow inside the lit area produces the ultimate attention guide).
- It can be implemented by extending the existing `DrawingCanvasView`, without adding a new window class under `Overlay/`.

Reason for not integrating with Zoom mode: Zoom is intended to "enlarge for detail", which is the opposite of Spotlight's "focus on one part within a broad context".

#### 2. MVP Scope

| Included | Excluded |
|----------|----------|
| One spotlight rectangle | Multiple rectangles |
| Create by drag, overwrite by redrag | Resize / move via handles |
| Darkness adjustment with ↑/↓ | Animated rectangle transitions |
| Default darkness from settings | Non-rectangular shapes (circle, freeform) |
| Drawing on top of an active spotlight | A separate undo stack for spotlight |

Reason for omitting rectangle editing: "Redrag to overwrite if you make a mistake" is intuitive; introducing handle UI increases operational state and causes confusion.

---

### B. Control Scheme

#### B.1 Activation / Deactivation

| Operation | Effect |
|-----------|--------|
| `S` key | Arms the Spotlight tool. The next drag confirms a rectangle |
| Drag | Rectangle preview → confirms the spotlight on mouseUp |
| Redrag after a confirmed rectangle | Discards the existing rectangle and creates a new one (overwrite) |
| `S` key (pressed again) | Spotlight OFF, rectangle cleared |
| `Esc` | Exits Draw mode (spotlight clears at the same time) |

#### B.2 Combining With Drawing

After a spotlight is confirmed, the tool **automatically returns to the normal drawing tool**. The spotlight rectangle stays in place while pen, shapes, and text remain usable.

This enables the following flow:
1. Press `S` → drag to create a spotlight rectangle
2. Immediately draw an arrow (modifier-free freehand, or Shift+⌃ for an arrow)
3. Press `S` again and the spotlight is cleared while the drawing remains

#### B.3 Dynamic Darkness Adjustment

| Operation | Effect |
|-----------|--------|
| `↑` key | Darkness +5% (max 0.9) |
| `↓` key | Darkness -5% (min 0.1) |

**Active condition:** Only when a spotlight is active (rectangle is confirmed).
**Conflict avoidance:** In existing Draw, pen width is adjusted only by `⌃ + ↑/↓` or `⌃ + scroll`. Bare `↑/↓` is unassigned, so there is no conflict.

---

### C. Rendering Design

#### C.1 Layer Composition (with Spotlight)

```
Drawing layer composition (bottom → top):
  [ background        (CGImage / white / black) ]    ← existing
  [ finishedLayer     (CGImage)                  ]   ← existing: confirmed strokes
  [ spotlightLayer    (generated on each draw)   ]   ← new: dim mask
  [ previewLayer      (NSBezierPath)             ]   ← existing: shape preview
  [ activeFreehand    (NSBezierPath)             ]   ← existing: freehand
```

**Important:** Placing `spotlightLayer` **below** `previewLayer` / `activeFreehand` ensures drawing strokes remain visible even over the darkened area.

#### C.2 Spotlight Rendering Method

Inside `DrawingCanvasView.draw(_:)`, draw in the following order:

```swift
// Inserted after finishedLayer is drawn, before previewLayer
if let rect = drawingState.spotlightRect {
    drawSpotlightMask(rect: rect, in: context)
}
```

Implementation outline of `drawSpotlightMask`:

```
1. context.saveGState()
2. context.setFillColor(NSColor.black.withAlphaComponent(spotlightDarkness).cgColor)
3. context.fill(bounds)                    // darken the entire view
4. context.setBlendMode(.clear)
5. context.fill(rect)                      // punch out the spotlight rectangle
6. context.restoreGState()
```

The `.clear` blend mode "makes the drawn pixels fully transparent", so only the rectangular area lets the underlying background show through.

#### C.3 Preview While Creating a Spotlight

Rather than reusing `previewLayer` during the drag, give `DrawingCanvasView` a dedicated `spotlightDragRect: CGRect?`:

```
mouseDragged (when the Spotlight tool is active):
  spotlightDragRect = CGRect(from: dragOrigin, to: currentPoint).standardized

draw():
  if let dragRect = spotlightDragRect {
      drawSpotlightMask(rect: dragRect, in: context)  // live preview
  } else if let confirmedRect = drawingState.spotlightRect {
      drawSpotlightMask(rect: confirmedRect, in: context)  // confirmed
  }

mouseUp (when the Spotlight tool is active):
  drawingState.spotlightRect = spotlightDragRect
  spotlightDragRect = nil
  drawingState.activeTool = .draw   // auto-return to the drawing tool
```

---

### D. State Management

#### D.1 Additions to `DrawingState`

```swift
enum DrawingTool {
    case draw          // normal drawing (existing behavior)
    case spotlight     // creating a spotlight rectangle
}

var activeTool: DrawingTool = .draw
var spotlightRect: CGRect?           // nil means spotlight is disabled
var spotlightDarkness: CGFloat = Settings.shared.spotlightDarkness
```

#### D.2 State Transitions

```
[Draw normal state] --(press S)--> [Spotlight tool armed]
                                          |
                               (drag → mouseUp)
                                          |
                                          v
                          [Spotlight active · Draw normal state]
                                          |
                                          +-- (press S) --> [Spotlight OFF]
                                          +-- (Esc) --> [Exit Draw mode]
                                          +-- (press S → redrag) --> overwrite
```

#### D.3 Branching in mouseDown

Branch on `activeTool` at the top of `DrawingCanvasView.mouseDown`:

```swift
override func mouseDown(with event: NSEvent) {
    if drawingState.isTextMode { ...existing... }

    let point = convert(event.locationInWindow, from: nil)
    dragOrigin = point

    if drawingState.activeTool == .spotlight {
        // Spotlight drag begins
        spotlightDragRect = CGRect(origin: point, size: .zero)
        isDragging = true
        return
    }

    // ...existing freehand / shape initialization...
}
```

`mouseDragged` / `mouseUp` branch the same way at the top. When the Spotlight tool is active, **do not touch** the existing `freehandPoints` / `previewLayer`.

---

### E. Key Binding Integration

Additions to `DrawingCanvasView.keyDown`:

```swift
case "S" where !modifiers.contains(.command):  // distinguish from ⌘S (save)
    toggleSpotlightTool()

case String(UnicodeScalar(NSUpArrowFunctionKey)!) where drawingState.spotlightRect != nil:
    drawingState.spotlightDarkness = min(drawingState.spotlightDarkness + 0.05, 0.9)
    setNeedsDisplay(bounds)

case String(UnicodeScalar(NSDownArrowFunctionKey)!) where drawingState.spotlightRect != nil:
    drawingState.spotlightDarkness = max(drawingState.spotlightDarkness - 0.05, 0.1)
    setNeedsDisplay(bounds)
```

Behavior of `toggleSpotlightTool()`:

```swift
private func toggleSpotlightTool() {
    if drawingState.spotlightRect != nil {
        // Already active → clear
        drawingState.spotlightRect = nil
        drawingState.activeTool = .draw
    } else {
        // Inactive → arm the tool (wait for next drag)
        drawingState.activeTool = .spotlight
    }
    updateCursor()
    setNeedsDisplay(bounds)
}
```

**Cursor:** While the Spotlight tool is armed, `.crosshair` (same as existing) is sufficient. Visual feedback comes more from "the next drag actually produces a rectangle" than from the cursor shape itself.

---

### F. Integration With Undo

Spotlight operations should also be undoable with `⌘Z`. The existing `StrokeManager.pushUndoSnapshot` stores `finishedLayer` and `backgroundMode`, so add `spotlightRect` to it.

```swift
struct UndoSnapshot {
    let finishedLayer: CGImage?
    let backgroundMode: DrawingState.BackgroundMode
    let spotlightRect: CGRect?     // added
}
```

Timing for calling `pushUndoSnapshot` (in addition to existing stroke confirmation):
- When a spotlight rectangle is confirmed (just before mouseUp)
- When the spotlight is cleared (just before disabling with S)
- When a spotlight is overwritten (just before mouseUp; once per operation)

---

### G. Settings

Additions to `Settings`:

```swift
// Keys
static let spotlightDarkness = "spotlightDarkness"

// Add to registerDefaults
Keys.spotlightDarkness: 0.6,

// Accessor
var spotlightDarkness: CGFloat {
    get { CGFloat(defaults.double(forKey: Keys.spotlightDarkness)) }
    set { defaults.set(Double(newValue), forKey: Keys.spotlightDarkness) }
}
```

Add a "Spotlight Darkness (0.1 – 0.9)" slider to `DrawTab.swift`.

Also add the key to the `allKeys` list in `resetToDefaults`.

---

### H. Consistency With Export (⌘C / ⌘S)

`renderFinalImage()` must also include the spotlight when exporting. This can be handled by adding the same `drawSpotlightMask` call after the `finishedLayer` is drawn in the existing implementation of `DrawingCanvasView`.

This makes it possible to share a "presentation screen with spotlight included" as a screenshot.

---

### I. Testing Strategy

Unit tests (`ZoomacItTests/`) cover the following:

| Test Target | Content |
|-------------|---------|
| `DrawingState` | Transitions of `activeTool`, clamping of `spotlightDarkness` (0.1 – 0.9) |
| Spotlight rectangle normalization | `CGRect.standardized` conversion when dragging in each direction from dragOrigin |
| Settings | Persistence and read-back of `spotlightDarkness` |

**Out of scope for unit tests:**
- The drawing result of `DrawingCanvasView` (consistent with the existing policy; view-layer code is verified manually)
- Integrated key binding behavior (same as above)

---

### J. Implementation Order

1. `Settings.swift`: Add `spotlightDarkness` + register default
2. `DrawingState.swift`: Add `DrawingTool` enum and `activeTool` / `spotlightRect` / `spotlightDarkness`
3. `StrokeManager.swift` / `UndoSnapshot`: Include `spotlightRect`
4. `DrawingCanvasView.swift`:
   - Add `spotlightDragRect` property
   - Add `drawSpotlightMask` method
   - Integrate into the ordering of `draw(_:)`
   - Branch on `activeTool` in `mouseDown` / `mouseDragged` / `mouseUp`
   - Add `S` / `↑` / `↓` to `keyDown`
   - Reflect spotlight in `renderFinalImage()` as well
5. `DrawTab.swift`: Add the Spotlight darkness slider
6. Add tests

---

### K. Known Constraints and Future Extensions

- **MVP supports only one rectangle.** Supporting multiple spotlights requires turning it into an array and tracking "which one is being edited".
- **MVP has no rectangle editing.** Adding resize/move requires handle UI, hit-testing, and an edit-mode state, which substantially increases operational state.
- **Animated fade** is a future consideration. It could be achieved by promoting `spotlightLayer` to an actual NSView layer with Core Animation, but that diverges from the current `draw(_:)`-centric design.
- **Circular spotlight** depends on use cases. Implementation is as simple as switching `context.fill(rect)` to `context.fillEllipse(in: rect)` inside `drawSpotlightMask`.
