<p align="center">
  <img src="images/1024.png" width="200">
</p>

<p align="center">English | <a href="README_ja.md">日本語</a></p>

# ZoomacIt
ZoomacIt is a native macOS menu bar app inspired by [ZoomIt for Windows](https://learn.microsoft.com/en-us/sysinternals/downloads/zoomit).
The project aims for feature compatibility with ZoomIt, providing system-wide hotkeys, smooth zooming, and on-screen annotation while minimizing required permissions.

## Installation

1. Download the latest `.pkg` from [Releases](https://github.com/07JP27/ZoomacIt/releases)
2. Right-click the `.pkg` file → **Open** → Click **Open** in the dialog  
   *(Required because the app is not signed with an Apple Developer ID)*
3. Follow the installer to install ZoomacIt to Applications
4. Grant **Screen Recording** permission when prompted

## Current feature coverage
| Feature | Status |
|---|---|
|Zoom||
|Draw|✅|
|Text||
|DemoType||
|Break Timer||
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
| T | Text input mode (Escape to confirm) |
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
| Escape / Right-click | Exit Draw mode |
