# Usage

Each feature can be launched via a global hotkey or from the menu bar icon.

| Feature | Default Hotkey |
|---|---|
| Zoom | **⌃1** (Control+1) |
| Draw | **⌃2** (Control+2) |
| Break Timer | **⌃3** (Control+3) |

::: tip
Hotkeys can be customized in **Settings** (click the menu bar icon → Settings).
:::

## Zoom

Press **⌃1** to enter Zoom mode. The screen is captured and you can zoom in/out and pan around.

### Controls

| Input | Action |
|---|---|
| Mouse move | Pan |
| Scroll wheel / ↑↓ | Zoom in / out |
| Click | Enter Draw mode (zoomed view becomes the drawing canvas) |
| Escape | Exit Zoom mode (or return to Zoom if entered from Draw) |
| Right-click | Exit Zoom mode |

### Zoom → Draw → Zoom Flow

When you click in Zoom mode, you enter Draw mode on top of the zoomed view:

1. **Zoom mode** — click to enter Draw
2. **Draw mode** (on zoomed canvas) — press **Escape** to return to Zoom
3. **Zoom mode** — press **Escape** again to exit completely

This two-step dismiss works similarly to text mode in Draw.

## Draw

Press **⌃2** to enter Draw mode. The screen freezes and you can draw on top of it.

### Drawing

| Input | Action |
|---|---|
| Drag | Freehand drawing |
| Shift + Drag | Straight line |
| Control + Drag | Rectangle |
| Tab + Drag | Ellipse |
| Shift + Control + Drag | Arrow |

### Colors

| Key | Color |
|---|---|
| R | Red (default) |
| G | Green |
| B | Blue |
| O | Orange |
| Y | Yellow |
| P | Pink |
| Shift + color key | Highlighter mode |

### Tools

| Key | Action |
|---|---|
| T | Text input mode |
| ⌃ + scroll wheel | Change pen width |
| E | Erase all |
| W | Whiteboard background |
| K | Blackboard background |

### Actions

| Key | Action |
|---|---|
| ⌘Z | Undo |
| ⌘C | Copy to clipboard |
| ⌘S | Save to file |
| Space | Center cursor |
| Escape | Exit text mode (confirm text) / Exit Draw mode |
| Right-click | Exit Draw mode |

### Text Mode

Press **T** to enter text mode. Click anywhere to place a text field and start typing.

- **Click another position** — the current text is confirmed (rasterized) and a new text field is placed
- **Escape** — confirms the current text and returns to pen mode (Draw mode stays active)
- **Scroll wheel** — change font size
- **Color keys** (R/G/B/O/Y/P) — change text color
- **Right-click** — confirms the current text and exits Draw mode

## Break Timer

Press **⌃3** to start a break timer. A full-screen countdown appears and starts immediately with the default duration (10 minutes).

### Timer Controls

| Input | Action |
|---|---|
| ↑ | Add 1 minute |
| ↓ | Subtract 1 minute |
| R / G / B / O / Y / P | Change timer text color |
| Escape | Dismiss timer |

### Behavior

- The timer starts immediately when the hotkey is pressed — no confirmation dialog
- Adjusting time with ↑/↓ works even during countdown
- When the timer reaches **0:00**, it stays on screen and shows elapsed time below (e.g., `0:00 (1:15)`)
- The timer continues running in the background when switching to other apps
- You can also start the timer from the menu bar icon → **Break**
- Draw mode (⌃2) and Break Timer (⌃3) can run simultaneously
