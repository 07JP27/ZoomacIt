# Live Zoom Implementation Plan

## Overview
Implement real-time zoom using ScreenCaptureKit's `SCStream` for continuous frame capture, following the spec in `Zoom-en.md`.

## Phases

### Phase 1: Core Stream Capture
- [ ] Create `LiveZoomWindowController.swift` in `src/ZoomacIt/Overlay/`
- [ ] Set up `SCStream` with 60fps frame delivery
- [ ] Implement `SCStreamOutput` protocol to receive `CMSampleBuffer`
- [ ] Display frames via `CALayer.contents` (zero-copy CVPixelBuffer path)
- [ ] Handle Screen Recording permission check/request

### Phase 2: Pan & Zoom Controls
- [ ] Reuse `ZoomMath.swift` for contentsRect calculations
- [ ] Mouse movement → pan (same as Still Zoom)
- [ ] Scroll wheel → zoom level change
- [ ] Edge clamping to prevent black bars

### Phase 3: Hotkey & Lifecycle
- [ ] Register ⌃4 hotkey (configurable in Settings)
- [ ] Start/stop SCStream on hotkey toggle
- [ ] Escape / right-click → stop stream, destroy overlay
- [ ] Multi-monitor: capture only the screen where cursor is located

### Phase 4: Draw Mode Transition
- [ ] ⌃2 during Live Zoom → freeze current frame (stop SCStream)
- [ ] Convert last CVPixelBuffer to CGImage
- [ ] Hand off to existing Draw mode (same as Still Zoom's draw entry)
- [ ] Escape from Draw → exit everything

### Phase 5: Polish
- [ ] Cursor visibility during Live Zoom (`showsCursor = true`)
- [ ] Smooth zoom animation (CABasicAnimation on contentsRect)
- [ ] Settings UI: Live Zoom hotkey configuration
- [ ] Performance profiling (target: <5% CPU at idle zoom)

## Key Technical Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Frame delivery | `SCStreamOutput` delegate | Lower latency than `SCStreamFrameOutput` |
| Rendering | `CALayer.contents = CVPixelBuffer` | Zero-copy, GPU-backed |
| Zoom math | Reuse `ZoomMath.swift` | Already tested, same logic applies |
| Draw transition | Stop stream → snapshot last buffer | Matches Windows ZoomIt behavior |

## Files to Create/Modify

**New:**
- `src/ZoomacIt/Overlay/LiveZoomWindowController.swift`
- `src/ZoomacIt/Overlay/LiveZoomView.swift` (if needed, or reuse StillZoomView)

**Modify:**
- `src/ZoomacIt/App/` — Register Live Zoom hotkey, add menu item
- `src/ZoomacIt/Settings/` — Add Live Zoom hotkey setting
- `src/ZoomacIt/Overlay/OverlayWindowController.swift` — May need shared base logic
- `src/ZoomacItTests/` — Add Live Zoom tests

## References
- `design/Zoom-en.md` — Full spec (sections C, F, G)
- `src/ZoomacIt/Overlay/StillZoomWindowController.swift` — Pattern to follow
- `src/ZoomacIt/Overlay/ZoomMath.swift` — Reusable zoom calculations
- Apple docs: [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)
