## Draw Feature Detailed Specification

### A. Draw Mode Control Scheme (Full ZoomIt Compatibility)

#### Key Design Philosophy: "Modifier Key Hold" Instead of "Mode Switching"

ZoomIt's shape switching is **not done through a toolbar or state toggle**.
The shape changes only while modifier keys are held during a mouse drag.
This means releasing the key immediately returns to freehand drawing.

```
[ During mouse drag ]
  No modifier keys     → Freehand (pen)
  Shift held           → Straight line
  ⌘/Ctrl held          → Rectangle
  Tab held             → Ellipse
  Shift + ⌘/Ctrl      → Arrow (start point is the arrow tip)
```

> **Mac Note:** Whether to map Windows `Ctrl` to `⌘ (Command)` or `⌃ (Control)` needs consideration.
> `⌘` tends to conflict with macOS system shortcuts, so `⌃` is safer. However, if ZoomIt compatibility is prioritized, support both via settings.

#### Shape Drawing Behavior Details

| Shape | Modifier Keys | Drawing Start/End Points |
|---|---|---|
| Freehand | None | Follows mouse trail directly |
| Straight line | Shift | Drag start point → current point |
| Rectangle | ⌃ (Ctrl) | Bounding box with drag start point as a vertex |
| Ellipse | Tab | Inscribed in bounding box with drag start point as a vertex |
| Arrow | Shift + ⌃ | **Start point is the arrow tip** (end point is the tail) ← ZoomIt-specific behavior, note carefully |

---

### B. Color Switching

Pressing the following keys during drawing immediately changes the color (even during a drag).

| Key | Color |
|---|---|
| R | Red (default) |
| G | Green |
| B | Blue |
| O | Orange |
| Y | Yellow |
| P | Pink |

#### Switching to Highlighter

`Shift + color key` activates highlighter mode.
Pressing the same color key without Shift returns to normal pen.

---

### C. Pen Size Changes

| Operation | Effect |
|---|---|
| ⌃ + Scroll wheel | Increase/decrease pen thickness |
| ⌃ + ↑ / ↓ | Increase/decrease pen thickness (when no mouse wheel available) |

---

### D. Undo / Erase

| Key | Effect |
|---|---|
| ⌘Z | Undo the last single stroke |
| E | Erase all drawings (mode is maintained) |
| Spacebar | Move cursor to screen center (drawings are not erased) |

---

### E. Sketch Pad Mode (Background Color Change)

| Key | Effect |
|---|---|
| W | Fill the entire screen with **white** (whiteboard) |
| K | Fill the entire screen with **black** (blackboard) |

`W` / `K` implementation:
→ Rather than changing the transparent overlay's `backgroundColor`,
  **draw a white/black rectangle at the bottom of finishedLayer and cache it**.
  Otherwise, subsequent strokes won't layer correctly on top of the background color.

---

### F. Text Mode

| Operation | Effect |
|---|---|
| T key | Enter text input mode |
| Scroll wheel / ↑↓ | Change font size |
| R/G/B/O/Y/P | Change text color |
| Escape | Confirm text and return to pen mode |

Processing on text confirmation:
→ Render the `NSTextView` content to an offscreen `CGBitmapContext`,
  then rasterize and burn it into `finishedLayer`.
  The NSTextView is then destroyed.

---

### G. Entering and Exiting Draw Mode

| Operation | Effect |
|---|---|
| Hotkey (⌃2) | Start Draw mode at native resolution |
| Left-click during zoom | Start Draw mode while maintaining zoom |
| Escape | Exit Draw mode and destroy overlay |
| Right-click | Exit Draw mode |
| ⌘C | Copy current screen (including drawings) to clipboard |
| ⌘S | Save current screen (including drawings) to file |

---

### H. Event Handling Implementation Approach

```
mouseDown  → Start stroke. Record start point. Check modifier key state.
mouseDragged →
  ├ No modifiers  : Append to points array → Smooth with Catmull-Rom
  ├ Shift         : Preview line between start point and current point (don't touch finishedLayer)
  ├ ⌃             : Preview bounding box from start point to current point
  ├ Tab           : Same as above but ellipse preview
  └ Shift+⌃      : Arrow preview
mouseUp    → Confirm. Rasterize the preview shape into finishedLayer.

keyDown    →
  ├ R/G/B/O/Y/P  : Update activeColor
  ├ Shift+color   : Set highlighterMode flag ON + update activeColor
  ├ W/K           : Write background color layer to finishedLayer
  ├ T             : Switch to textMode
  ├ E             : Clear entire finishedLayer
  └ Space         : Move cursor to center
```

#### Shape Preview Implementation

Lines, rectangles, ellipses, and arrows need to show a "preview" during drag.
Rewriting finishedLayer on every `mouseDragged` is too heavy, so:

```
Drawing layer structure:
  [ finishedLayer  (CGImage) ]      ← Confirmed strokes, not modified
  [ previewLayer   (NSBezierPath) ] ← Only the shape being dragged, destroyed on mouseUp
  [ activeFreehand (NSBezierPath) ] ← Current freehand stroke
```

All 3 layers are drawn in sequence within `draw(_:)`, and on `mouseUp` the `previewLayer` is burned into `finishedLayer`.