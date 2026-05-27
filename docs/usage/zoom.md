# Zoom

Press **⌃1** (Control+1) to enter Zoom mode. The screen is captured and you can zoom in/out and pan around.

## Controls

| Input | Action |
|---|---|
| Mouse move | Pan |
| Scroll wheel / ↑↓ | Zoom in / out |
| Click | Enter Draw mode (zoomed view becomes the drawing canvas) |
| Escape | Exit Zoom mode (or return to Zoom if entered from Draw) |
| Right-click | Exit Zoom mode |

## Zoom → Draw → Zoom Flow

When you click in Zoom mode, you enter Draw mode on top of the zoomed view:

1. **Zoom mode** — click to enter Draw
2. **Draw mode** (on zoomed canvas) — press **Escape** to return to Zoom
3. **Zoom mode** — press **Escape** again to exit completely

This two-step dismiss works similarly to text mode in Draw.

## Live Zoom

Press **⌃4** (Control+4) to enter Live Zoom mode. Unlike standard Zoom, the screen content updates in real time — videos, terminals, and animations keep playing while zoomed.

### Controls

| Input | Action |
|---|---|
| Mouse move | Pan the zoomed viewport |
| Scroll wheel / ↑↓ | Zoom in / out (1.0x–8.0x) |
| Click | Freeze the frame and enter Draw mode |
| Escape | Exit Live Zoom |
| Right-click | Exit Live Zoom |

### Differences from Still Zoom

| | Still Zoom (⌃1) | Live Zoom (⌃4) |
|---|---|---|
| Screen content | Static snapshot | Real-time updates |
| Mouse cursor | May not appear (captured in snapshot) | Always visible |
| Enter Draw | Click (stays zoomed) | Click (freezes current frame, then draw) |
