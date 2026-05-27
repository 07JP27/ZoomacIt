import AppKit
import Carbon.HIToolbox

/// Simulates typing text character-by-character into the focused app.
/// Shows an input dialog on activation, then types the entered text.
@MainActor
final class DemoTypeController {

    var onFinished: (() -> Void)?

    private var characters: [Character] = []
    private var charIndex: Int = 0
    private var timer: Timer?
    private var isTyping: Bool = false

    private var speed: Double {
        max(1.0, min(Settings.shared.demoTypeSpeed, 200.0))
    }

    func start() {
        if isTyping {
            stop()
            return
        }

        guard checkAccessibilityPermission() else { return }
        showInputDialog()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isTyping = false
        onFinished?()
    }

    private func checkAccessibilityPermission() -> Bool {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            let key = "AXTrustedCheckOptionPrompt" as CFString
            let options = [key: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            NSLog("[DemoTypeController] Accessibility permission not granted")
        }
        return trusted
    }

    private func showInputDialog() {
        // Remember which app to type into
        let targetApp = NSWorkspace.shared.frontmostApplication

        let alert = NSAlert()
        alert.messageText = "DemoType"
        alert.informativeText = "Enter text to type:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Type")
        alert.addButton(withTitle: "Cancel")

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 150))
        textView.isEditable = true
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.string = Settings.shared.demoTypeText // Pre-fill with last used text

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 150))
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        alert.accessoryView = scrollView

        alert.window.level = .floating

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            targetApp?.activate()
            onFinished?()
            return
        }

        let inputText = textView.string
        guard !inputText.isEmpty else {
            targetApp?.activate()
            onFinished?()
            return
        }

        Settings.shared.demoTypeText = inputText
        characters = Array(inputText)
        charIndex = 0
        isTyping = true

        // Reactivate the target app, then start typing
        targetApp?.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startTyping()
        }
    }

    private func startTyping() {
        NSLog("[DemoTypeController] Typing %d chars at %.0f cps", characters.count, speed)
        let interval = 1.0 / speed
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.typeNextCharacter()
            }
        }
    }

    private func typeNextCharacter() {
        guard charIndex < characters.count else {
            stop()
            return
        }

        let char = characters[charIndex]
        charIndex += 1

        simulateKeyPress(for: char)
    }

    private func simulateKeyPress(for char: Character) {
        if char == "\n" {
            postKeyEvent(keyCode: UInt16(kVK_Return))
            return
        }
        if char == "\t" {
            postKeyEvent(keyCode: UInt16(kVK_Tab))
            return
        }

        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else { return }
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }

        var utf16 = Array(String(char).utf16)
        keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
        keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func postKeyEvent(keyCode: UInt16) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)?.post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)?.post(tap: .cghidEventTap)
    }
}
