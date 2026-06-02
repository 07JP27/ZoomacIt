# DemoType

Press **⌃7** (Control+7) to start DemoType. It synthesizes keystrokes from a script into the currently focused application — perfect for live demos and presentations.

## Input Sources (checked in order)

1. **Clipboard**: If clipboard text starts with `[start]`, it is used as the script (prefix stripped)
2. **File**: If a script file path is configured in Settings → DemoType
3. **Dialog**: If neither is available, an input dialog appears

## Usage

1. Prepare your script (file, clipboard with `[start]`, or type in dialog)
2. Click into the target application (editor, terminal, etc.)
3. Press **⌃7** — typing begins automatically
4. Press **Escape** to cancel at any time
5. Switching to another app also cancels

## Control Keywords

Embed these in your script for flow control:

| Keyword | Effect |
|---|---|
| `[end]` | Pause here. Press ⌃7 again to continue with next segment. |
| `[pause:N]` | Pause for N seconds, then resume |
| `[enter]` | Press Return key |
| `[up]` | Press Up arrow |
| `[down]` | Press Down arrow |
| `[left]` | Press Left arrow |
| `[right]` | Press Right arrow |

## Segments

Use `[end]` to split a script into segments:

```
print("Hello")[end]
print("World")[end]
print("Done")
```

Each press of ⌃7 types the next segment. Useful for stepping through code during a presentation.

## Settings

| Setting | Description | Default |
|---|---|---|
| Script file path | Path to a text file to use as the DemoType script | (empty) |
| Speed | Milliseconds per character (lower = faster) | 55 ms |
| User-driven mode | Each keypress injects characters instead of auto-typing | Off |

## Permissions

DemoType requires **Accessibility** permission to inject keystrokes. You will be prompted on first use.
