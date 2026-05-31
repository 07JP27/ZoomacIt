## DemoType Feature Detailed Specification

### Reference Implementation

Source: [microsoft/PowerToys — src/modules/ZoomIt/ZoomIt/DemoType.cpp](https://github.com/microsoft/PowerToys/blob/main/src/modules/ZoomIt/ZoomIt/DemoType.cpp)

DemoType synthesizes keystrokes from a script into the currently focused application.
It does **not** render text in an overlay — it literally types into whatever app has focus.

### Core Behavior

#### Two Operating Modes

| Mode | Trigger | Behavior |
|------|---------|----------|
| **Standard** | `userDriven = false` | Auto-types at configurable speed with random variance |
| **User-driven** | `userDriven = true` | Each real keypress injects N characters (N = speed ratio 1–3) |

#### Input Sources (priority order)

1. **Clipboard**: If clipboard text starts with `[start]`, use it as the script (strip prefix)
2. **File**: Load from a configured file path (UTF-8, UTF-8 BOM, UTF-16LE, UTF-16BE)
3. **Dialog fallback** (macOS addition): If neither clipboard nor file available, show input dialog

#### Keystroke Injection

- Characters injected via `CGEvent` with unicode string (macOS equivalent of Windows `SendInput` + `KEYEVENTF_UNICODE`)
- Newline → `kVK_Return`, Tab → `kVK_Tab`
- All other characters → unicode CGEvent

#### Keyboard Blocking

During DemoType, real user keystrokes are blocked (not passed through to the app).
On macOS: use `CGEvent.tapCreate` with `.cgSessionEventTap` to intercept and suppress.

In user-driven mode, intercepted keystrokes trigger character injection instead of being passed through.

#### Kill Signals

DemoType terminates immediately when:
- **Escape** is pressed
- **Focus changes** (user switches to another app)
- Script reaches final `[end]` (standard mode only)

### Control Keywords

Embedded in script text, processed during injection:

| Keyword | Behavior |
|---------|----------|
| `[end]` | Marks segment boundary. Standard mode: stops. User-driven: pauses until re-triggered. |
| `[pause:N]` | Pause for N seconds (standard mode only; ignored in user-driven) |
| `[enter]` | Inject Return key |
| `[up]` | Inject Up arrow |
| `[down]` | Inject Down arrow |
| `[left]` | Inject Left arrow |
| `[right]` | Inject Right arrow |
| `[paste]...[/paste]` | Inject enclosed text via clipboard paste (Cmd+V) |

### Segment Navigation

- `[end]` splits a script into segments
- Re-triggering the DemoType hotkey resumes from the next segment
- "Reset" (re-trigger with modifier) goes back to the previous segment
- When all segments are exhausted, index resets to 0

### Speed Configuration

| Parameter | Value |
|-----------|-------|
| Fastest | 10 ms per character |
| Slowest | 100 ms per character |
| Variance | ±100% of base speed (random per character, for natural feel) |
| User-driven ratio | Speed slider maps to 1–3 characters per keypress |

### Settings UI

| Setting | Type | Default |
|---------|------|---------|
| DemoType hotkey | Key combo | ⌃7 |
| Script file path | File picker | (empty) |
| Typing speed | Slider (10–100ms) | 55ms |
| User-driven mode | Toggle | Off |

---

## Implementation Plan (macOS / Swift)

### Phase 1: Core Rewrite ← Current Sprint

Rewrite `DemoTypeController.swift` to match ZoomIt behavior:

- [x] Keystroke injection into focused app (already working)
- [ ] File input: load script from `Settings.shared.demoTypeFilePath`
- [ ] Clipboard input: detect `[start]` prefix, use clipboard as script
- [ ] Control keywords: `[end]`, `[pause:N]`, `[enter]`, arrows
- [ ] Segment tracking: pause at `[end]`, resume on re-trigger
- [ ] Escape to cancel (global event monitor)
- [ ] Focus change detection → auto-cancel
- [ ] Speed variance (random ± for natural typing feel)
- [ ] Settings: file path picker, user-driven toggle

### Phase 2: User-Driven Mode

- [ ] CGEvent tap to intercept real keystrokes
- [ ] Map each intercepted key-up → inject N characters
- [ ] Block all non-injected input during DemoType
- [ ] Speed slider → injection ratio (1–3 chars per keypress)

### Phase 3: Polish

- [ ] Auto-format awareness (detect `{`, `(`, newline → use paste for IDE compat)
- [ ] Baseline indentation detection
- [ ] Clipboard cache/restore after DemoType ends
- [ ] File change detection (reload if file modified between triggers)

---

### macOS-Specific Considerations

| Windows (ZoomIt) | macOS (ZoomacIt) |
|------------------|------------------|
| `SetWindowsHookEx(WH_KEYBOARD_LL)` | `CGEvent.tapCreate(.cgSessionEventTap)` |
| `SendInput` + `KEYEVENTF_UNICODE` | `CGEvent` with `keyboardSetUnicodeString` |
| `GetForegroundWindow()` | `NSWorkspace.shared.frontmostApplication` |
| `Ctrl+V` paste | `Cmd+V` paste |
| Notepad detection | Not needed (no special-casing) |

### Permissions Required

- **Accessibility**: Required for CGEvent posting and event tap
- Prompt user on first DemoType activation if not granted
