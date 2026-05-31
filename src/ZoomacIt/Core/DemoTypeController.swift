import AppKit
import Carbon.HIToolbox

/// Synthesizes keystrokes from a script into the focused application.
/// Matches ZoomIt DemoType behavior: file/clipboard input, control keywords,
/// segment navigation, escape-to-cancel, focus-change detection.
@MainActor
final class DemoTypeController {

    var onFinished: (() -> Void)?

    private var text: String = ""
    private var index: Int = 0
    private var segments: [Int] = []
    private var isActive: Bool = false
    private var timer: Timer?
    private var escapeMonitor: Any?
    private var focusObserver: NSObjectProtocol?
    private var targetApp: NSRunningApplication?

    // MARK: - Public API

    func start() {
        if isActive {
            // Re-trigger: advance to next segment
            advanceToNextSegment()
            return
        }

        guard checkAccessibilityPermission() else { return }

        // Load script: clipboard ([start] prefix) → file → dialog fallback
        if !loadFromClipboard() && !loadFromFile() {
            showInputDialog()
            return
        }

        beginTyping()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        removeMonitors()
        isActive = false
        onFinished?()
    }

    // MARK: - Input Sources

    private func loadFromClipboard() -> Bool {
        guard let clip = NSPasteboard.general.string(forType: .string),
              clip.hasPrefix("[start]") else { return false }
        text = String(clip.dropFirst(7))
        index = 0
        segments = []
        return cleanText()
    }

    private func loadFromFile() -> Bool {
        let path = Settings.shared.demoTypeFilePath
        guard !path.isEmpty else { return false }
        guard let data = try? String(contentsOfFile: path, encoding: .utf8) else { return false }
        text = data
        index = 0
        segments = []
        return cleanText()
    }

    private func showInputDialog() {
        targetApp = NSWorkspace.shared.frontmostApplication

        let alert = NSAlert()
        alert.messageText = "DemoType"
        alert.informativeText = "Enter text to type (or set a script file in Settings):"
        alert.addButton(withTitle: "Type")
        alert.addButton(withTitle: "Cancel")

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 150))
        textView.isEditable = true
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 150))
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        alert.accessoryView = scrollView
        alert.window.level = .floating

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn, !textView.string.isEmpty else {
            targetApp?.activate()
            onFinished?()
            return
        }

        text = textView.string
        index = 0
        segments = []
        _ = cleanText()

        targetApp?.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.beginTyping()
        }
    }

    // MARK: - Text Cleaning

    private func cleanText() -> Bool {
        // Strip leading newline
        if text.hasPrefix("\n") { text.removeFirst() }
        // Trim newlines around [end]
        text = text.replacingOccurrences(of: "\n[end]\n", with: "[end]")
        text = text.replacingOccurrences(of: "\n[end]", with: "[end]")
        text = text.replacingOccurrences(of: "[end]\n", with: "[end]")
        return !text.isEmpty
    }

    // MARK: - Typing Engine

    private func beginTyping() {
        guard !text.isEmpty, index < text.count else {
            onFinished?()
            return
        }

        isActive = true
        targetApp = NSWorkspace.shared.frontmostApplication
        installMonitors()

        let baseMs = max(10.0, min(Settings.shared.demoTypeSpeed, 100.0))
        scheduleNextChar(baseMs: baseMs)
    }

    private func scheduleNextChar(baseMs: Double) {
        // Random variance ±50% for natural feel
        let variance = baseMs * 0.5
        let delay = (baseMs - variance + Double.random(in: 0...(variance * 2))) / 1000.0

        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.injectNext()
            }
        }
    }

    private func injectNext() {
        guard isActive, index < text.count else {
            stop()
            return
        }

        let chars = Array(text)

        // Check for control keyword
        if chars[index] == "[" {
            if let result = handleControlKeyword(chars: chars) {
                switch result {
                case .end:
                    segments.append(index)
                    isActive = false
                    timer?.invalidate()
                    // Don't call onFinished — waiting for re-trigger
                    removeMonitors()
                    return
                case .pause(let seconds):
                    let baseMs = max(10.0, min(Settings.shared.demoTypeSpeed, 100.0))
                    timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
                        MainActor.assumeIsolated {
                            self?.scheduleNextChar(baseMs: baseMs)
                        }
                    }
                    return
                case .consumed:
                    let baseMs = max(10.0, min(Settings.shared.demoTypeSpeed, 100.0))
                    scheduleNextChar(baseMs: baseMs)
                    return
                }
            }
        }

        // Inject the character
        let char = chars[index]
        index += 1
        simulateKeyPress(for: char)

        let baseMs = max(10.0, min(Settings.shared.demoTypeSpeed, 100.0))
        scheduleNextChar(baseMs: baseMs)
    }

    // MARK: - Control Keywords

    private enum ControlResult {
        case end
        case pause(TimeInterval)
        case consumed
    }

    private func handleControlKeyword(chars: [Character]) -> ControlResult? {
        let remaining = String(chars[index...])

        if remaining.hasPrefix("[end]") {
            index += 5
            return .end
        }
        if remaining.hasPrefix("[enter]") {
            index += 7
            postKeyEvent(keyCode: UInt16(kVK_Return))
            return .consumed
        }
        if remaining.hasPrefix("[up]") {
            index += 4
            postKeyEvent(keyCode: UInt16(kVK_UpArrow))
            return .consumed
        }
        if remaining.hasPrefix("[down]") {
            index += 6
            postKeyEvent(keyCode: UInt16(kVK_DownArrow))
            return .consumed
        }
        if remaining.hasPrefix("[left]") {
            index += 6
            postKeyEvent(keyCode: UInt16(kVK_LeftArrow))
            return .consumed
        }
        if remaining.hasPrefix("[right]") {
            index += 7
            postKeyEvent(keyCode: UInt16(kVK_RightArrow))
            return .consumed
        }
        // [pause:N]
        if remaining.hasPrefix("[pause:") {
            if let closeIdx = remaining.firstIndex(of: "]") {
                let content = remaining[remaining.index(remaining.startIndex, offsetBy: 7)..<closeIdx]
                if let seconds = Double(content) {
                    let len = remaining.distance(from: remaining.startIndex, to: closeIdx) + 1
                    index += len
                    return .pause(seconds)
                }
            }
        }

        return nil // Not a recognized control keyword — treat '[' as literal
    }

    // MARK: - Segment Navigation

    private func advanceToNextSegment() {
        // Find next [end] from current position
        if let range = text.range(of: "[end]", range: text.index(text.startIndex, offsetBy: index)..<text.endIndex) {
            index = text.distance(from: text.startIndex, to: range.upperBound)
        } else {
            index = 0
            segments = []
        }

        if index < text.count {
            beginTyping()
        } else {
            index = 0
            segments = []
            onFinished?()
        }
    }

    // MARK: - Keystroke Injection

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
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }

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

    // MARK: - Monitors (Escape + Focus)

    private func installMonitors() {
        escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == UInt16(kVK_Escape) {
                MainActor.assumeIsolated { self?.stop() }
            }
        }

        focusObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let self, self.isActive else { return }
            // If a different app gained focus, cancel
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               app.processIdentifier != self.targetApp?.processIdentifier {
                self.stop()
            }
        }
    }

    private func removeMonitors() {
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
        if let observer = focusObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            focusObserver = nil
        }
    }

    // MARK: - Permissions

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
}
