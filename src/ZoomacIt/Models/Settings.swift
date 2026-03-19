import AppKit
import Carbon.HIToolbox

/// Font weight options for text input, persistable as raw String.
enum FontWeightOption: String, CaseIterable, Sendable {
    case ultraLight
    case thin
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy
    case black

    var nsFontWeight: NSFont.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin:       return .thin
        case .light:      return .light
        case .regular:    return .regular
        case .medium:     return .medium
        case .semibold:   return .semibold
        case .bold:       return .bold
        case .heavy:      return .heavy
        case .black:      return .black
        }
    }

    var displayName: String {
        switch self {
        case .ultraLight: return "Ultra Light"
        case .thin:       return "Thin"
        case .light:      return "Light"
        case .regular:    return "Regular"
        case .medium:     return "Medium"
        case .semibold:   return "Semibold"
        case .bold:       return "Bold"
        case .heavy:      return "Heavy"
        case .black:      return "Black"
        }
    }
}

/// Centralized settings manager backed by UserDefaults.
/// Thread-safe (UserDefaults is thread-safe).
final class Settings: @unchecked Sendable {

    static let shared = Settings()

    private let defaults = UserDefaults.standard

    private init() {
        registerDefaults()
    }

    // MARK: - Keys

    enum Keys {
        // Hotkeys
        static let zoomHotkeyKeyCode = "hotkeyZoomKeyCode"
        static let zoomHotkeyModifiers = "hotkeyZoomModifiers"
        static let drawHotkeyKeyCode = "hotkeyDrawKeyCode"
        static let drawHotkeyModifiers = "hotkeyDrawModifiers"
        static let breakHotkeyKeyCode = "hotkeyBreakKeyCode"
        static let breakHotkeyModifiers = "hotkeyBreakModifiers"

        // Draw
        static let defaultPenColor = "drawDefaultPenColor"
        static let defaultPenWidth = "drawDefaultPenWidth"
        static let highlighterOpacity = "drawHighlighterOpacity"
        static let highlighterWidthMultiplier = "drawHighlighterWidthMultiplier"

        // Text
        static let defaultFontSize = "textDefaultFontSize"
        static let fontWeight = "textFontWeight"

        // Zoom
        static let defaultZoomLevel = "zoomDefaultLevel"
        static let zoomAnimationEnabled = "zoomAnimationEnabled"

        // Break Timer
        static let breakTimerDefaultDuration = "breakTimerDefaultDuration"
        static let breakTimerColor = "breakTimerColor"
        static let breakTimerOpacity = "breakTimerOpacity"
        static let breakTimerBackground = "breakTimerBackground"
        static let breakTimerShowElapsed = "breakTimerShowElapsed"
        static let breakTimerPlaySound = "breakTimerPlaySound"
        static let breakTimerSoundFile = "breakTimerSoundFile"
        static let breakTimerBackgroundFadeDarkness = "breakTimerBackgroundFadeDarkness"
    }

    // MARK: - Register Defaults

    func registerDefaults() {
        defaults.register(defaults: [
            // Hotkeys
            Keys.zoomHotkeyKeyCode: Int(kVK_ANSI_1),
            Keys.zoomHotkeyModifiers: Int(controlKey),
            Keys.drawHotkeyKeyCode: Int(kVK_ANSI_2),
            Keys.drawHotkeyModifiers: Int(controlKey),
            Keys.breakHotkeyKeyCode: Int(kVK_ANSI_3),
            Keys.breakHotkeyModifiers: Int(controlKey),

            // Draw
            Keys.defaultPenColor: PenColor.red.rawValue,
            Keys.defaultPenWidth: 3.0,
            Keys.highlighterOpacity: 0.35,
            Keys.highlighterWidthMultiplier: 4.0,

            // Text
            Keys.defaultFontSize: 24.0,
            Keys.fontWeight: FontWeightOption.medium.rawValue,

            // Zoom
            Keys.defaultZoomLevel: 2.0,
            Keys.zoomAnimationEnabled: true,

            // Break Timer
            Keys.breakTimerDefaultDuration: 600,
            Keys.breakTimerColor: PenColor.red.rawValue,
            Keys.breakTimerOpacity: 1.0,
            Keys.breakTimerBackground: BreakTimerBackground.black.rawValue,
            Keys.breakTimerShowElapsed: true,
            Keys.breakTimerPlaySound: false,
            Keys.breakTimerBackgroundFadeDarkness: 0.6
        ])
    }

    // MARK: - Hotkeys

    var zoomHotkeyKeyCode: UInt32 {
        get { UInt32(defaults.integer(forKey: Keys.zoomHotkeyKeyCode)) }
        set { defaults.set(Int(newValue), forKey: Keys.zoomHotkeyKeyCode) }
    }

    var zoomHotkeyModifiers: UInt32 {
        get { UInt32(defaults.integer(forKey: Keys.zoomHotkeyModifiers)) }
        set { defaults.set(Int(newValue), forKey: Keys.zoomHotkeyModifiers) }
    }

    var drawHotkeyKeyCode: UInt32 {
        get { UInt32(defaults.integer(forKey: Keys.drawHotkeyKeyCode)) }
        set { defaults.set(Int(newValue), forKey: Keys.drawHotkeyKeyCode) }
    }

    var drawHotkeyModifiers: UInt32 {
        get { UInt32(defaults.integer(forKey: Keys.drawHotkeyModifiers)) }
        set { defaults.set(Int(newValue), forKey: Keys.drawHotkeyModifiers) }
    }

    var breakHotkeyKeyCode: UInt32 {
        get { UInt32(defaults.integer(forKey: Keys.breakHotkeyKeyCode)) }
        set { defaults.set(Int(newValue), forKey: Keys.breakHotkeyKeyCode) }
    }

    var breakHotkeyModifiers: UInt32 {
        get { UInt32(defaults.integer(forKey: Keys.breakHotkeyModifiers)) }
        set { defaults.set(Int(newValue), forKey: Keys.breakHotkeyModifiers) }
    }

    // MARK: - Draw

    var defaultPenColor: PenColor {
        get { PenColor(rawValue: defaults.string(forKey: Keys.defaultPenColor) ?? "") ?? .red }
        set { defaults.set(newValue.rawValue, forKey: Keys.defaultPenColor) }
    }

    var defaultPenWidth: CGFloat {
        get { CGFloat(defaults.double(forKey: Keys.defaultPenWidth)) }
        set { defaults.set(Double(newValue), forKey: Keys.defaultPenWidth) }
    }

    var highlighterOpacity: CGFloat {
        get { CGFloat(defaults.double(forKey: Keys.highlighterOpacity)) }
        set { defaults.set(Double(newValue), forKey: Keys.highlighterOpacity) }
    }

    var highlighterWidthMultiplier: CGFloat {
        get { CGFloat(defaults.double(forKey: Keys.highlighterWidthMultiplier)) }
        set { defaults.set(Double(newValue), forKey: Keys.highlighterWidthMultiplier) }
    }

    // MARK: - Text

    var defaultFontSize: CGFloat {
        get { CGFloat(defaults.double(forKey: Keys.defaultFontSize)) }
        set { defaults.set(Double(newValue), forKey: Keys.defaultFontSize) }
    }

    var fontWeight: FontWeightOption {
        get { FontWeightOption(rawValue: defaults.string(forKey: Keys.fontWeight) ?? "") ?? .medium }
        set { defaults.set(newValue.rawValue, forKey: Keys.fontWeight) }
    }

    // MARK: - Zoom

    var defaultZoomLevel: CGFloat {
        get { CGFloat(defaults.double(forKey: Keys.defaultZoomLevel)) }
        set { defaults.set(Double(newValue), forKey: Keys.defaultZoomLevel) }
    }

    var zoomAnimationEnabled: Bool {
        get { defaults.bool(forKey: Keys.zoomAnimationEnabled) }
        set { defaults.set(newValue, forKey: Keys.zoomAnimationEnabled) }
    }

    // MARK: - Break Timer

    var breakTimerDefaultDuration: Int {
        get { defaults.integer(forKey: Keys.breakTimerDefaultDuration) }
        set { defaults.set(newValue, forKey: Keys.breakTimerDefaultDuration) }
    }

    var breakTimerColor: PenColor {
        get { PenColor(rawValue: defaults.string(forKey: Keys.breakTimerColor) ?? "") ?? .red }
        set { defaults.set(newValue.rawValue, forKey: Keys.breakTimerColor) }
    }

    var breakTimerOpacity: CGFloat {
        get { CGFloat(defaults.double(forKey: Keys.breakTimerOpacity)) }
        set { defaults.set(Double(newValue), forKey: Keys.breakTimerOpacity) }
    }

    var breakTimerBackground: BreakTimerBackground {
        get { BreakTimerBackground(rawValue: defaults.string(forKey: Keys.breakTimerBackground) ?? "") ?? .black }
        set { defaults.set(newValue.rawValue, forKey: Keys.breakTimerBackground) }
    }

    var breakTimerShowElapsed: Bool {
        get { defaults.bool(forKey: Keys.breakTimerShowElapsed) }
        set { defaults.set(newValue, forKey: Keys.breakTimerShowElapsed) }
    }

    var breakTimerPlaySound: Bool {
        get { defaults.bool(forKey: Keys.breakTimerPlaySound) }
        set { defaults.set(newValue, forKey: Keys.breakTimerPlaySound) }
    }

    var breakTimerSoundFile: URL? {
        get {
            guard let path = defaults.string(forKey: Keys.breakTimerSoundFile), !path.isEmpty else { return nil }
            return URL(fileURLWithPath: path)
        }
        set { defaults.set(newValue?.path ?? "", forKey: Keys.breakTimerSoundFile) }
    }

    var breakTimerBackgroundFadeDarkness: CGFloat {
        get { CGFloat(defaults.double(forKey: Keys.breakTimerBackgroundFadeDarkness)) }
        set { defaults.set(Double(newValue), forKey: Keys.breakTimerBackgroundFadeDarkness) }
    }

    // MARK: - Reset

    func resetToDefaults() {
        let allKeys: [String] = [
            Keys.zoomHotkeyKeyCode, Keys.zoomHotkeyModifiers,
            Keys.drawHotkeyKeyCode, Keys.drawHotkeyModifiers,
            Keys.breakHotkeyKeyCode, Keys.breakHotkeyModifiers,
            Keys.defaultPenColor, Keys.defaultPenWidth,
            Keys.highlighterOpacity, Keys.highlighterWidthMultiplier,
            Keys.defaultFontSize, Keys.fontWeight,
            Keys.defaultZoomLevel, Keys.zoomAnimationEnabled,
            Keys.breakTimerDefaultDuration, Keys.breakTimerColor,
            Keys.breakTimerOpacity, Keys.breakTimerBackground,
            Keys.breakTimerShowElapsed, Keys.breakTimerPlaySound,
            Keys.breakTimerSoundFile, Keys.breakTimerBackgroundFadeDarkness
        ]
        for key in allKeys {
            defaults.removeObject(forKey: key)
        }
        NotificationCenter.default.post(name: .settingsDidReset, object: nil)
    }

    // MARK: - Display Utilities

    /// Converts a Carbon key code and modifier mask to a human-readable shortcut string.
    static func hotkeyDisplayString(keyCode: UInt32, modifiers: UInt32) -> String {
        var parts = ""
        if modifiers & UInt32(controlKey) != 0 { parts += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { parts += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { parts += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { parts += "⌘" }
        parts += keyCodeToString(keyCode)
        return parts
    }

    private static let keyCodeDisplayNames: [Int: String] = [
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
        kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
        kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
        kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
        kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
        kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
        kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
        kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
        kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
        kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
        kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥",
        kVK_Delete: "⌫", kVK_Escape: "⎋",
        kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=",
        kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]",
        kVK_ANSI_Backslash: "\\", kVK_ANSI_Semicolon: ";",
        kVK_ANSI_Quote: "'", kVK_ANSI_Comma: ",",
        kVK_ANSI_Period: ".", kVK_ANSI_Slash: "/", kVK_ANSI_Grave: "`"
    ]

    /// Converts a Carbon virtual key code to a display string.
    static func keyCodeToString(_ keyCode: UInt32) -> String {
        keyCodeDisplayNames[Int(keyCode)] ?? "Key\(keyCode)"
    }

    /// Converts a Carbon key code to a character suitable for NSMenuItem.keyEquivalent.
    static func keyCodeToMenuCharacter(_ keyCode: UInt32) -> String {
        keyCodeToString(keyCode).lowercased()
    }

    /// Converts Carbon modifier flags to NSEvent.ModifierFlags.
    static func carbonToNSEventModifiers(_ carbonModifiers: UInt32) -> NSEvent.ModifierFlags {
        var flags = NSEvent.ModifierFlags()
        if carbonModifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if carbonModifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if carbonModifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if carbonModifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        return flags
    }

    /// Converts NSEvent.ModifierFlags to Carbon modifier flags.
    static func nsEventToCarbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        return carbon
    }
}

// MARK: - Notification

extension Notification.Name {
    static let settingsDidReset = Notification.Name("settingsDidReset")
    static let hotkeysDidChange = Notification.Name("hotkeysDidChange")
}
