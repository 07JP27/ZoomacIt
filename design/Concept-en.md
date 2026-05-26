
# ZoomacIt (ZoomIt for Mac) — Feature Specification

> **Policy:** Full feature compatibility with Windows ZoomIt (v10.0)
> **Reference:** [ZoomIt - Microsoft Sysinternals](https://learn.microsoft.com/en-us/sysinternals/downloads/zoomit)

---

## 1. Zoom (Screen Zoom)

- Zoom into the screen with a global hotkey
- Pan (scroll) the screen with the mouse while zoomed
- Change magnification with the mouse wheel
- Zoom out to return to original resolution
- **Still Zoom** — Snapshot-based zoom (screen is frozen during zoom)
- **Live Zoom** — Zoom while updating the screen in real time

---

## 2. Draw (Drawing & Annotation)

- Enter draw mode from either zoomed or native resolution
- Freehand pen drawing
- Straight lines (forced horizontal/vertical with Shift)
- Arrows
- Rectangles
- Ellipses
- Highlighter (semi-transparent)
- Customize pen color (changeable via keys during drawing)
- Customize pen thickness
- Clear all drawings with a single key
- **Whiteboard / Blackboard mode** — Draw on a fullscreen white / black canvas

---

## 3. Text (Text Input)

- Switch to text input mode with the `T` key during draw mode
- Click any position on screen to overlay text
- Change font size with the mouse wheel
- Clicking another position during text input confirms (rasterizes) the current text, then places a new text field
- **Escape confirms the text** — Text is rasterized into finishedLayer and returns to pen mode (draw mode continues)
- Right-click confirms text and exits draw mode
- Text color can be changed with the draw color keys (R/G/B/O/Y/P)

---

## 4. DemoType

- Register text in advance, then launch with a hotkey
- Display the registered text one character at a time on screen as if "live typing"
- A feature for smoothly presenting predetermined commands or text during demos

---

## 5. Break Timer

- Display a fullscreen countdown timer with a hotkey
- Customize timer duration
- Customize timer display position and background color
- Timer continues running even when switching to other apps
- Visual alarm when timer expires

---

## 6. Snip (Screenshot)

- Region-selection screenshot
- Copy to clipboard
- Save to file

---

## 7. Record (Screen Recording)

- Record the entire screen or a selected region
- Save in **MP4 format**
- Save in **GIF format**
- Record with system audio
- Trim recording clips (v10.0 feature)

---

## 8. Hotkey Configuration

All feature hotkeys are customizable by the user

| Feature | Windows Default | Mac Default (Proposed) |
|---|---|---|
| Zoom | Ctrl + 1 | ⌃1 |
| Draw (no zoom) | Ctrl + 2 | ⌃2 |
| Break Timer | Ctrl + 3 | ⌃3 |
| Snip | Ctrl + 4 | ⌃4 |
| Record | Ctrl + 5 | ⌃5 |
| Live Zoom | Ctrl + 4 | ⌃4 |
| DemoType | Ctrl + 7 | ⌃7 |

---

## 9. System Behavior

- **Menu bar resident** (equivalent to system tray)
- Show settings dialog on first launch
- Lightweight operation with minimal impact on system resources
- All features operable via hotkeys only (no mouse required)