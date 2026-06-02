# Record

Press **⌃5** (Control+5) to start full-screen recording. A 3-2-1 countdown appears, then recording begins.

## Usage

1. Press **⌃5** — countdown overlay appears (3… 2… 1…)
2. Recording starts automatically after countdown
3. Press **Escape** to stop recording
4. Video saved to `~/Movies/ZoomacIt/` with timestamp filename

## Controls

| Input | Action |
|---|---|
| ⌃5 | Start recording |
| Escape | Stop recording |

## Output

- **Format**: MOV (H.264 via AVAssetWriter)
- **Location**: `~/Movies/ZoomacIt/`
- **Filename**: `ZoomacIt-YYYY-MM-DD-HHmmss.mov`

## Permissions

Record requires both:
- **Screen Recording** — to capture screen content
- **Accessibility** — for global Escape key detection (works without app focus)

You will be prompted on first use.
