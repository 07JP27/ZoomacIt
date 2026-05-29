# DemoType

Press **⌃7** (Control+7) to activate DemoType. A dialog appears where you enter the text to be typed. After clicking **Type**, the text is typed character-by-character into the previously focused app.

## Input Dialog

| Element | Description |
|---|---|
| Text field | Multi-line text to type (pre-filled with last used text) |
| Type button | Starts simulated typing |
| Cancel button | Dismisses the dialog without typing |

## Settings

| Setting | Description | Default |
|---|---|---|
| Hotkey | Global shortcut to activate DemoType | ⌃7 |
| Typing speed | Characters per second | 15 |

## Behavior

- The dialog pre-fills with the last text you typed — useful for repeating demos
- After clicking **Type**, focus returns to the previous app and typing begins after a short delay
- Typing speed is clamped between 1 and 200 characters per second
- Newlines and tabs are supported (typed as Return and Tab key presses)
- Pressing the hotkey again while typing is in progress stops it immediately
- You can also start DemoType from the menu bar icon → **DemoType**

## Requirements

- **Accessibility permission** is required for DemoType to simulate key presses
- On first use, macOS will prompt you to grant Accessibility access in System Settings → Privacy & Security → Accessibility
