# Record Mode — Implementation Plan

## Windows ZoomIt Spec (Reference)

### Hotkeys
| Hotkey | Action |
|--------|--------|
| Ctrl+5 | Start/Stop full screen recording (MP4 or GIF) |
| Ctrl+Shift+5 | Crop screen recording (select region, then record) |
| Ctrl+Alt+5 | Record only the window under the cursor |
| Esc | Stop recording |

### Output Formats
- **MP4** — default, with optional audio
- **GIF** — animated, no audio

### Features (from Windows ZoomIt)
- Full screen recording
- Region/crop recording (user selects rectangle first)
- Window-only recording (captures single window)
- Audio capture (microphone)
- Cursor included in recording
- Recording indicator (visual feedback that recording is active)

## macOS Implementation Strategy

### Core Technology: ScreenCaptureKit + AVAssetWriter
- **ScreenCaptureKit** (`SCStream`) — already used by Live Zoom, proven to work
- **AVAssetWriter** — encode frames to MP4 (H.264/HEVC)
- **AVAudioEngine** or `SCStream` audio — capture microphone/system audio
- **CGImage → GIF** — ImageIO framework for animated GIF export

### Architecture

```
RecordController
├── RecordSessionManager        — manages SCStream + AVAssetWriter lifecycle
├── RegionSelector (reuse SnipView pattern) — for crop recording
├── WindowPicker                — for window-only recording
└── RecordIndicatorView         — floating "recording" badge
```

### Files to Create
- `src/ZoomacIt/Record/RecordController.swift` — main controller (start/stop/mode selection)
- `src/ZoomacIt/Record/RecordSessionManager.swift` — SCStream → AVAssetWriter pipeline
- `src/ZoomacIt/Record/RecordIndicatorView.swift` — small floating recording indicator
- `src/ZoomacIt/Record/GIFExporter.swift` — frame buffer → animated GIF

### Files to Modify
- `Settings.swift` — add record hotkey keys + output format preference
- `GeneralTab.swift` — add Record hotkey row
- `HotkeyManager.swift` — register Ctrl+5, Ctrl+Shift+5, Ctrl+Alt+5
- `AppDelegate.swift` — wire hotkey callbacks to RecordController
- `StatusBarController.swift` — add Record menu item

### Settings
- `recordHotkeyKeyCode` / `recordHotkeyModifiers` — default: Ctrl+5
- `recordCropHotkeyKeyCode` / `recordCropHotkeyModifiers` — default: Ctrl+Shift+5
- `recordWindowHotkeyKeyCode` / `recordWindowHotkeyModifiers` — default: Ctrl+Alt+5
- `recordOutputFormat` — "mp4" | "gif" (default: mp4)
- `recordAudioEnabled` — Bool (default: false)
- `recordShowCursor` — Bool (default: true)
- `recordFrameRate` — Int (default: 30)
- `recordSaveDirectory` — String (default: ~/Desktop)

## Implementation Phases

### Phase 1: Full Screen MP4 Recording ✅
1. ~~Register Ctrl+5 hotkey~~
2. ~~On trigger: start SCStream (full display, similar to Live Zoom)~~
3. ~~Pipe frames to AVAssetWriter (H.264, .mp4)~~
4. ~~Show recording indicator (red dot)~~
5. ~~On Ctrl+5 again or Esc: stop stream, finalize file, save to Desktop~~
6. ~~3-2-1 countdown before recording starts~~
7. ~~Esc to stop (global monitor with Accessibility permission prompt)~~
8. ~~Reveal file in Finder on stop~~
9. ~~Add settings UI for hotkey~~

### Phase 2: Region & Window Recording
1. Ctrl+Shift+5: show region selector (reuse SnipView overlay pattern)
2. After selection: start recording only that rect (SCContentFilter with crop)
3. Ctrl+Alt+5: detect window under cursor, record only that window
4. SCContentFilter supports single-window capture natively
5. Add hotkey settings for crop and window recording

### Phase 3: GIF Export + Audio
1. Add GIF output option (buffer frames, export via ImageIO)
2. GIF considerations: lower frame rate (10-15fps), palette optimization, file size
3. Audio capture via SCStream's audio output (macOS 13+)
4. Mux audio + video in AVAssetWriter
5. Add settings toggle for audio capture

### Phase 4: Polish
1. Better recording indicator (elapsed time counter, larger, pulsing)
2. Settings for output format (MP4/GIF), frame rate, save directory
3. Notification on save (instead of or in addition to Finder reveal)
4. Handle edge cases: display disconnect during recording, disk full

## Key Considerations

### Permissions
- Screen Recording permission (already required for Zoom/Live Zoom)
- Microphone permission (only if audio enabled — request on first use)

### Performance
- Use hardware encoding (VideoToolbox via AVAssetWriter)
- Don't buffer frames in memory — write directly to disk
- GIF mode needs frame buffer (limit duration or downsample)

### File Naming
- Default: `ZoomacIt Recording YYYY-MM-DD at HH.MM.SS.mp4`
- Match macOS screenshot naming convention

### Recording Indicator
- Small floating window (always on top, not captured in recording)
- Red circle + elapsed time
- Click to stop (alternative to hotkey)
- Exclude from SCStream capture (same pattern as Live Zoom overlay exclusion)

## Reusable Code from Existing Features
- **Live Zoom**: SCStream setup, display detection, window exclusion
- **Snip**: Region selection overlay (for crop recording)
- **Settings pattern**: Hotkey registration, GeneralTab rows, resetToDefaults

## Dependencies
- macOS 13+ (ScreenCaptureKit audio capture)
- macOS 12.3+ (SCStream basic capture — already our floor via Live Zoom)
- No external dependencies needed
