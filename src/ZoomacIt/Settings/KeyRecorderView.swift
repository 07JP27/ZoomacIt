import SwiftUI
import Carbon.HIToolbox

/// NSViewRepresentable wrapping a key-recording NSView.
/// Click to start recording, press a key combo (with at least one modifier) to set.
/// Press Escape to cancel recording.
struct KeyRecorderView: NSViewRepresentable {
    @Binding var keyCode: Int
    @Binding var modifiers: Int

    func makeNSView(context: Context) -> KeyRecorderNSView {
        let view = KeyRecorderNSView()
        view.keyCode = UInt32(keyCode)
        view.modifiers = UInt32(modifiers)
        view.onKeyRecorded = { newKeyCode, newModifiers in
            keyCode = Int(newKeyCode)
            modifiers = Int(newModifiers)
        }
        return view
    }

    func updateNSView(_ nsView: KeyRecorderNSView, context: Context) {
        nsView.keyCode = UInt32(keyCode)
        nsView.modifiers = UInt32(modifiers)
        if !nsView.isRecording {
            nsView.needsDisplay = true
        }
    }
}

// MARK: - KeyRecorderNSView

class KeyRecorderNSView: NSView {

    var keyCode: UInt32 = 0
    var modifiers: UInt32 = 0
    var isRecording = false
    var onKeyRecorded: ((UInt32, UInt32) -> Void)?

    private var trackingArea: NSTrackingArea?
    private var savedInputSource: TISInputSource?

    override var acceptsFirstResponder: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 140, height: 28)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        // makeFirstResponder may trigger resignFirstResponder on another recorder,
        // which calls start(). We call stop() AFTER to ensure hotkeys stay unregistered.
        window?.makeFirstResponder(self)
        HotkeyManager.shared.stop()
        switchToASCIIInput()
        needsDisplay = true
    }

    /// performKeyEquivalent is called BEFORE the text input system / IME processes
    /// the event, so it reliably captures Ctrl+number even when a Japanese IME is active.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return super.performKeyEquivalent(with: event) }

        // Escape cancels recording
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return true
        }

        // Require at least one modifier key
        let carbonMods = Settings.nsEventToCarbonModifiers(event.modifierFlags)
        guard carbonMods != 0 else { return true } // consume but ignore

        keyCode = UInt32(event.keyCode)
        modifiers = carbonMods
        stopRecording()
        onKeyRecorded?(keyCode, modifiers)
        return true
    }

    override func keyDown(with event: NSEvent) {
        // Fallback: if performKeyEquivalent didn't catch it (e.g., no modifiers)
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }

        let carbonMods = Settings.nsEventToCarbonModifiers(event.modifierFlags)
        guard carbonMods != 0 else { return }

        keyCode = UInt32(event.keyCode)
        modifiers = carbonMods
        stopRecording()
        onKeyRecorded?(keyCode, modifiers)
    }

    override func flagsChanged(with event: NSEvent) {
        // Don't act on modifier-only presses
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            stopRecording()
        }
        return super.resignFirstResponder()
    }

    // MARK: - Recording helpers

    /// Switch to ASCII-capable input source to prevent IME from intercepting key combos.
    private func switchToASCIIInput() {
        // Save current input source to restore later
        savedInputSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        // Switch to ASCII-capable keyboard
        if let asciiSource = TISCopyCurrentASCIICapableKeyboardInputSource()?.takeRetainedValue() {
            TISSelectInputSource(asciiSource)
        }
    }

    /// Restore the original input source.
    private func restoreInputSource() {
        if let source = savedInputSource {
            TISSelectInputSource(source)
            savedInputSource = nil
        }
    }

    private func stopRecording() {
        isRecording = false
        restoreInputSource()
        HotkeyManager.shared.start()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds

        // Background
        let bgColor: NSColor = isRecording ? .controlAccentColor.withAlphaComponent(0.15) : .controlBackgroundColor
        bgColor.setFill()
        let bgPath = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        bgPath.fill()

        // Border
        let borderColor: NSColor = isRecording ? .controlAccentColor : .separatorColor
        borderColor.setStroke()
        bgPath.lineWidth = 1.0
        bgPath.stroke()

        // Text
        let displayText: String
        if isRecording {
            displayText = "Press shortcut…"
        } else {
            displayText = Settings.hotkeyDisplayString(keyCode: keyCode, modifiers: modifiers)
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: isRecording ? .regular : .medium),
            .foregroundColor: isRecording ? NSColor.secondaryLabelColor : NSColor.labelColor,
        ]
        let textSize = (displayText as NSString).size(withAttributes: attrs)
        let textOrigin = NSPoint(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2
        )
        (displayText as NSString).draw(at: textOrigin, withAttributes: attrs)
    }
}
