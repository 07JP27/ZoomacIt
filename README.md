<p align="center">
  <img src="images/1024.png" width="200">
</p>

<p align="center">English | <a href="README_ja.md">日本語</a></p>

# ZoomacIt
ZoomacIt is a native macOS menu bar app inspired by [ZoomIt for Windows](https://learn.microsoft.com/en-us/sysinternals/downloads/zoomit).
The project aims for feature compatibility with ZoomIt, providing system-wide hotkeys, smooth zooming, and on-screen annotation while minimizing required permissions.

## Installation

1. Download the latest `.dmg` from [Releases](https://github.com/07JP27/ZoomacIt/releases)
2. Open the `.dmg` file and drag **ZoomacIt.app** to the **Applications** folder
3. If you see the warning "Apple could not verify "ZoomacIt" is free of malware that may harm your Mac or compromise your privacy", run the following command in **Terminal** to remove the quarantine flag. Please review the source code in this repository and run at your own risk.
   ```bash
   xattr -cr /Applications/ZoomacIt.app
   ```
4. Open ZoomacIt from Applications
5. Grant **Screen Recording** permission when prompted

## Current feature coverage
| Feature | Status |
|---|---|
|Zoom||
|Draw|✅|
|Text|✅|
|DemoType||
|Break Timer|✅|
|Snip||
|Record||

## Feature details
### Draw

Press **⌃2** (Control+2) to enter Draw mode. The screen freezes and you can draw on top of it.

#### Drawing

| Input | Action |
|---|---|
| Drag | Freehand drawing |
| Shift + Drag | Straight line |
| Control + Drag | Rectangle |
| Tab + Drag | Ellipse |
| Shift + Control + Drag | Arrow |

#### Colors

| Key | Color |
|---|---|
| R | Red (default) |
| G | Green |
| B | Blue |
| O | Orange |
| Y | Yellow |
| P | Pink |
| Shift + color key | Highlighter mode |

#### Tools

| Key | Action |
|---|---|
| T | Text input mode |
| X | Blur (weak) |
| Shift + X | Blur (strong) |
| ⌃ + scroll wheel | Change pen width |
| E | Erase all |
| W | Whiteboard background |
| K | Blackboard background |

#### Actions

| Key | Action |
|---|---|
| ⌘Z | Undo |
| ⌘C | Copy to clipboard |
| ⌘S | Save to file |
| Space | Center cursor |
| Escape | Exit text mode (confirm text) / Exit Draw mode |
| Right-click | Exit Draw mode |

#### Text mode

Press **T** to enter text mode. Click anywhere to place a text field and start typing.

- **Click another position** — the current text is confirmed (rasterized) and a new text field is placed
- **Escape** — confirms the current text and returns to pen mode (Draw mode stays active)
- **Scroll wheel** — change font size
- **Color keys** (R/G/B/O/Y/P) — change text color
- **Right-click** — confirms the current text and exits Draw mode

### Break Timer

Press **⌃3** (Control+3) to start a break timer. A full-screen countdown appears and starts immediately with the default duration (10 minutes).

#### Timer Controls

| Input | Action |
|---|---|
| ↑ | Add 1 minute |
| ↓ | Subtract 1 minute |
| R / G / B / O / Y / P | Change timer text color |
| Escape | Dismiss timer |

#### Behavior

- The timer starts immediately when the hotkey is pressed — no confirmation dialog
- Adjusting time with ↑/↓ works even during countdown
- When the timer reaches **0:00**, it stays on screen and shows elapsed time below (e.g., `0:00 (1:15)`)
- The timer continues running in the background when switching to other apps
- You can also start the timer from the menu bar icon → **Break**
- Draw mode (⌃2) and Break Timer (⌃3) can run simultaneously

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
