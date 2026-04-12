# Break Timer Feature Detailed Specification

### A. Timer Startup and Basic Behavior

| Operation | Effect |
|---|---|
| Hotkey (⌃3) | Displays the timer window fullscreen and immediately starts countdown |
| Menu bar icon → Break | Same as above |
| Escape | Terminates the timer and restores the screen |

**Important Behaviors:**
- The moment the hotkey is pressed, the timer **automatically starts with the previously set duration** (no confirmation dialog)
- During the first few seconds after start, the duration can be adjusted with arrow keys / scroll wheel
- The timer continues running in the background even when switching to other apps
- Clicking the menu bar icon returns to the timer screen

---

### B. Controls During Timer Display

| Operation | Effect |
|---|---|
| ↑ / Scroll up | Increase remaining time by 1 minute |
| ↓ / Scroll down | Decrease remaining time by 1 minute |
| R / G / B / O / Y / P | Change the timer text color (same color keys as Draw) |
| Escape | End timer |

**When Time Changes Are Accepted:**
ZoomIt allows adjusting time with ↑↓ even after the countdown has started. This design lets presenters complete a "5 more minutes" extension using only the keyboard. The Mac version should implement this the same way.

---

### C. Behavior After Timer Expiration

- The timer screen **does not disappear** when the count reaches `0:00`
- Below `0:00`, the elapsed time continues to be displayed in parentheses
  Example: `0:00` → `0:00 (0:32)` → `0:00 (1:15)` ...
- The timer screen is maintained until Escape is pressed
- Optionally, **play a sound on expiration** (described below)

---

### D. Settings (Advanced)

Configurable via the Break tab → Advanced button in the settings dialog.

#### Default Duration
- Setting value: Default 10 minutes (some documentation states 2 minutes, but this is configurable in ZoomIt's settings dialog)

#### Timer Display Position
Select from a 3×3 grid (9 positions)

```
┌───┬───┬───┐
│TL │TC │TR │
├───┼───┼───┤
│ML │ C │MR │   ← Default: Center (C)
├───┼───┼───┤
│BL │BC │BR │
└───┴───┴───┘
```

#### Timer Opacity
- 10% to 100% (Default: 100%)

#### Background Display

| Setting | Behavior |
|---|---|
| No background (default) | Timer displayed only on a solid black screen |
| Fade desktop and use as background | Capture current screen → darken with fade → use as background |
| Use an image file as background | Display specified image file fullscreen with the timer overlaid on top |

**Note:** When elapsed display is ON, the timer display area expands vertically after `0:00`, so when using a background image, the design needs to account for this extra space.

#### Expiration Sound
- ON/OFF toggle (Default: OFF)
- When ON: specify an arbitrary audio file (WAV, etc.)

#### Elapsed Display (Elapsed Time)
- ON/OFF toggle (Default: ON)
- After expiration, displays in `0:00 (elapsed time)` format

---

### E. Technical Approach for Mac Implementation

#### Timer Window

```swift
// Separate window independent from the Draw overlay
let timerWindow = NSWindow(
    contentRect: NSScreen.main!.frame,
    styleMask: [.borderless],
    backing: .buffered,
    defer: false
)
timerWindow.level = .screenSaver
timerWindow.ignoresMouseEvents = true   // During timer, pass interactions through to apps below
timerWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
```

#### Timer Countdown Loop

Use `DispatchSourceTimer` instead of `Timer.scheduledTimer`.
Reason: `scheduledTimer` loses accuracy when the RunLoop blocks. `DispatchSourceTimer` maintains 1-second accuracy even when CPU load increases during a presentation.

```swift
let source = DispatchSource.makeTimerSource(queue: .main)
source.schedule(deadline: .now(), repeating: .seconds(1))
source.setEventHandler {
    self.remainingSeconds -= 1
    self.updateDisplay()
    if self.remainingSeconds <= 0 {
        self.handleExpiration()
    }
}
source.resume()
```

#### Background: Desktop Fade

Capture the screen just before timer launch with `ScreenCaptureKit` → darken with `CIFilter` fade → draw as background.
Since it's a static single image, no real-time updates are needed (= no Live Zoom complexity required).

#### Background: Image File

Simply display with `NSImageView` at fullscreen using `scaleToFill`. Implementation cost is virtually zero.

#### Timer Text Rendering

- Font: System font (San Francisco) Monospaced Digit variant
  → Character width doesn't change when digits change, preventing text from wobbling left/right
- Render with `NSAttributedString` + `CTFrameDraw`

```swift
let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
```

#### Area Expansion from Elapsed Display

After expiration, an elapsed line is added, causing the timer's bounding box to expand vertically.
Changing this abruptly without animation would feel janky, so use `NSAnimationContext` to fade in the height from 0.

#### Sound Playback

```swift
// AVFoundation
let player = try AVAudioPlayer(contentsOf: soundFileURL)
player.play()
```

`NSSound` is also acceptable when using macOS system sounds.

#### Background Continuation

Since the timer uses `DispatchSourceTimer`, it continues running even when the app goes to the background.
Clicking the menu bar icon calls `timerWindow.makeKeyAndOrderFront` to bring it back to the foreground.

---