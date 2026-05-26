# Zoom Feature Detailed Specification

### A. Difference Between Zoom Mode and Live Zoom

ZoomIt has two types of zoom. Both are required in the Mac implementation.

| | Still Zoom | Live Zoom |
|---|---|---|
| Hotkey (default) | ⌃1 | ⌃4 |
| Screen update | **Frozen** (snapshot) | **Real-time** (videos, terminal, etc. continue to update) |
| Draw integration | Click during zoom to immediately enter Draw | Screen freezes the moment Draw is entered |
| Implementation difficulty | Low (enlarge a single CGImage) | High (requires ScreenCaptureKit stream) |

> **The screen freezing when entering Draw from Live Zoom** is by design. This avoids the complexity of overlaying drawings on real-time video.

---

### B. Still Zoom Control Scheme

#### Zoom Startup & Exit

| Operation | Effect |
|---|---|
| ⌃1 (hotkey) | Take a snapshot centered on current mouse position and start zoom |
| Scroll wheel up / ↑ | Zoom in |
| Scroll wheel down / ↓ | Zoom out |
| Mouse movement | Pan the visible area while zoomed |
| Escape / right-click | End zoom and return to original screen |
| Left-click | **Enter Draw mode** (can draw while maintaining zoom state) |

#### Zoom Level Details

- Default magnification: Specified in settings dialog (default around 2x)
- Zoom level is **remembered in settings** and maintained on next launch
- ⌃+scroll: Changes pen size (not zoom level)

#### Transitioning to Draw During Zoom

```
[ Launch with ⌃1 ]
    ↓
[ Take snapshot and display zoom ]
    ↓
[ Left-click ] ← This enters Draw mode
    ↓
[ Can draw while zoomed ]
    ↓
[ Escape ] → Exit both zoom and drawing
```

---

### C. Live Zoom Control Scheme

| Operation | Effect |
|---|---|
| ⌃4 (hotkey) | Start real-time zoom |
| Scroll wheel up / ↑ / ↓ | Zoom in / Zoom out |
| Mouse movement | Pan the visible area |
| ⌃2 (Draw hotkey) | **Enter Draw mode (screen freezes at this moment)** |
| Escape / right-click | Exit |

> **Important:** During Live Zoom, the mouse cursor is always visible. In Still Zoom, the cursor may not appear since it's a snapshot.

---

### D. Zoom Window Behavior

- Zoom is displayed as a **fullscreen overlay** (taskbar, etc. are hidden)
- During zoom, all interaction with other apps is **blocked**
- Multi-monitor environment: Zoom applies to **only the monitor where the cursor is located**
  - Moving to another monitor requires exiting zoom first with Escape

---

### E. Settings (Zoom Tab)

| Setting | Description |
|---|---|
| Zoom hotkey | Customizable (default: ⌃1) |
| Live Zoom hotkey | Customizable (default: ⌃4) |
| Animation | ON/OFF for smooth zoom in/out animation |

---

### F. Technical Approach for Mac Implementation

#### Still Zoom

**Capture snapshot → display CGImage enlarged via affine transform** is the simplest and most reliable combination.

```
1. At the moment ⌃1 is pressed, capture the entire screen with SCScreenshotManager
2. Set the captured CGImage to the overlay window's NSImageView / CALayer
3. Shift the visible area (CGRect) according to mouse movement (pan)
4. Change zoom magnification with scroll wheel → update CALayer.contentsRect
```

**Reason for using CALayer.contentsRect:**
Enlarging an NSView with `CGAffineTransform` causes blur,
but updating `CALayer`'s `contentsRect` (UV coordinate system from 0.0 to 1.0)
gets sampled on the GPU side, resulting in high quality and low CPU load.

```swift
// Calculate contentsRect from zoom level and pan position
func updateContentsRect(zoom: CGFloat, pan: CGPoint, imageSize: CGSize) -> CGRect {
    let visibleW = 1.0 / zoom
    let visibleH = 1.0 / zoom
    let originX = (pan.x / imageSize.width) - visibleW / 2
    let originY = (pan.y / imageSize.height) - visibleH / 2
    return CGRect(
        x: originX.clamped(to: 0...(1 - visibleW)),
        y: originY.clamped(to: 0...(1 - visibleH)),
        width: visibleW,
        height: visibleH
    )
}
```

#### Live Zoom

**Receive frames with ScreenCaptureKit (SCStream) and display them via Metal or CALayer.**
This is the most technically challenging part of the Zoom feature.

```swift
// Minimal SCStream configuration
let config = SCStreamConfiguration()
config.width = Int(NSScreen.main!.frame.width * NSScreen.main!.backingScaleFactor)
config.height = Int(NSScreen.main!.frame.height * NSScreen.main!.backingScaleFactor)
config.minimumFrameInterval = CMTime(value: 1, timescale: 60)  // Max 60fps
config.pixelFormat = kCVPixelFormatType_32BGRA
config.showsCursor = true   // Show cursor in Live Zoom

// Receive frames via SCStreamOutput protocol
func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
    guard let pixelBuffer = buffer.imageBuffer else { return }
    // Update CALayer contents from CVPixelBuffer
    DispatchQueue.main.async {
        self.overlayLayer.contents = pixelBuffer  // Zero-copy via Metal texture
    }
}
```

**Importance of Zero-Copy Rendering:**
The `CMSampleBuffer → CGImage → NSImage → NSImageView` path causes per-frame memory copies that burn through CPU.
Passing `CVPixelBuffer` directly to `CALayer.contents` (via Metal backend) is the best practice.

#### SCStream Permissions and Sandbox Issues

Using `ScreenCaptureKit` requires **Screen Recording permission** (macOS 12.3+).

```swift
// Check/request permission at first launch
SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
    if let error = error {
        // No permission → Display UI guiding to System Settings
        self.promptForPermission()
    }
}
```

**macOS 26.1 (Tahoe) Note:**
Plain executables that are not `.app` bundles no longer appear in the Screen Recording permission UI (confirmed on Developer Forums).
→ **Must be distributed as an `.app` bundle.** Distributing as a CLI tool breaks permission management.

#### Pan (Moving the Visible Area)

Both Still and Live zoom require **mouse coordinates → display center point** mapping.

```
Mouse movement during zoom = changing the center point of "where you're looking"

pan.x = mousePosition.x / screenWidth   (0.0 to 1.0)
pan.y = mousePosition.y / screenHeight  (0.0 to 1.0)
→ Feed this back as the origin of contentsRect
```

Clamp panning when reaching edges to prevent black bars outside the image from becoming visible.

#### Animation

Smooth zoom in/out animation is implemented with `CABasicAnimation`.

```swift
let anim = CABasicAnimation(keyPath: "contentsRect")
anim.duration = 0.15
anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
overlayLayer.add(anim, forKey: "zoom")
overlayLayer.contentsRect = newRect
```

When the animation OFF setting is active, skip with `CATransaction.setDisableActions(true)`.

---

### G. Still Zoom vs Live Zoom Implementation Flow Comparison

```
【Still Zoom】
⌃1 pressed
  → SCScreenshotManager.captureImage()  ← Capture single frame
  → Set CGImage to CALayer
  → Update contentsRect with mouse movement/scroll
  → Destroy overlay on Escape/right-click

【Live Zoom】
⌃4 pressed
  → SCStream.startCapture()  ← Start frame stream
  → Every frame: pixelBuffer → Update CALayer.contents (60fps)
  → Update contentsRect with mouse movement/scroll (same as Still Zoom)
  → ⌃2 pressed → SCStream.stopCapture() → Switch to single snapshot → Enter Draw mode
  → Escape/right-click → SCStream.stopCapture() → Destroy overlay
```

---