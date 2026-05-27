import XCTest
import Carbon.HIToolbox
@testable import ZoomacIt

final class SettingsTests: XCTestCase {

    /// These tests exercise `Settings.shared` which uses `UserDefaults.standard`.
    /// `resetToDefaults()` in `tearDown()` prevents state leaking between tests.

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        // Reset shared Settings to registered defaults
        Settings.shared.resetToDefaults()
        super.tearDown()
    }

    // MARK: - Default Values

    func testDefaultPenColor() {
        XCTAssertEqual(Settings.shared.defaultPenColor, .red)
    }

    func testDefaultPenWidth() {
        XCTAssertEqual(Settings.shared.defaultPenWidth, 3.0)
    }

    func testDefaultHighlighterOpacity() {
        XCTAssertEqual(Settings.shared.highlighterOpacity, 0.35)
    }

    func testDefaultHighlighterWidthMultiplier() {
        XCTAssertEqual(Settings.shared.highlighterWidthMultiplier, 4.0)
    }

    func testDefaultSpotlightDarkness() {
        XCTAssertEqual(Settings.shared.spotlightDarkness, 0.6, accuracy: 0.001)
    }

    func testSpotlightDarknessRoundTrip() {
        Settings.shared.spotlightDarkness = 0.4
        XCTAssertEqual(Settings.shared.spotlightDarkness, 0.4, accuracy: 0.001)
    }

    func testDefaultFontSize() {
        XCTAssertEqual(Settings.shared.defaultFontSize, 24.0)
    }

    func testDefaultFontWeight() {
        XCTAssertEqual(Settings.shared.fontWeight, .medium)
    }

    func testDefaultZoomLevel() {
        XCTAssertEqual(Settings.shared.defaultZoomLevel, 2.0)
    }

    func testDefaultZoomAnimation() {
        XCTAssertTrue(Settings.shared.zoomAnimationEnabled)
    }

    func testDefaultBreakTimer() {
        XCTAssertEqual(Settings.shared.breakTimerDefaultDuration, 600)
        XCTAssertEqual(Settings.shared.breakTimerColor, .red)
        XCTAssertEqual(Settings.shared.breakTimerOpacity, 1.0)
        XCTAssertEqual(Settings.shared.breakTimerBackground, .black)
        XCTAssertTrue(Settings.shared.breakTimerShowElapsed)
        XCTAssertFalse(Settings.shared.breakTimerPlaySound)
        XCTAssertNil(Settings.shared.breakTimerSoundFile)
        XCTAssertEqual(Settings.shared.breakTimerBackgroundFadeDarkness, 0.6, accuracy: 0.001)
    }

    // MARK: - Round-trip

    func testPenColorRoundTrip() {
        Settings.shared.defaultPenColor = .blue
        XCTAssertEqual(Settings.shared.defaultPenColor, .blue)
    }

    func testPenWidthRoundTrip() {
        Settings.shared.defaultPenWidth = 10.0
        XCTAssertEqual(Settings.shared.defaultPenWidth, 10.0)
    }

    func testZoomLevelRoundTrip() {
        Settings.shared.defaultZoomLevel = 4.5
        XCTAssertEqual(Settings.shared.defaultZoomLevel, 4.5)
    }

    func testBreakTimerDurationRoundTrip() {
        Settings.shared.breakTimerDefaultDuration = 300
        XCTAssertEqual(Settings.shared.breakTimerDefaultDuration, 300)
    }

    func testBreakTimerBackgroundRoundTrip() {
        Settings.shared.breakTimerBackground = .fadedDesktop
        XCTAssertEqual(Settings.shared.breakTimerBackground, .fadedDesktop)
    }

    func testFontWeightRoundTrip() {
        Settings.shared.fontWeight = .bold
        XCTAssertEqual(Settings.shared.fontWeight, .bold)
    }

    func testSoundFileRoundTrip() {
        let url = URL(fileURLWithPath: "/tmp/test.wav")
        Settings.shared.breakTimerSoundFile = url
        XCTAssertEqual(Settings.shared.breakTimerSoundFile, url)

        // Setting nil
        Settings.shared.breakTimerSoundFile = nil
        XCTAssertNil(Settings.shared.breakTimerSoundFile)
    }

    // MARK: - Reset

    func testResetToDefaults() {
        // Change some values
        Settings.shared.defaultPenColor = .green
        Settings.shared.defaultPenWidth = 20.0
        Settings.shared.breakTimerDefaultDuration = 120

        // Reset
        Settings.shared.resetToDefaults()

        // Verify defaults restored
        XCTAssertEqual(Settings.shared.defaultPenColor, .red)
        XCTAssertEqual(Settings.shared.defaultPenWidth, 3.0)
        XCTAssertEqual(Settings.shared.breakTimerDefaultDuration, 600)
    }

    // MARK: - Display Utilities

    func testHotkeyDisplayString() {
        // ⌃1
        let display = Settings.hotkeyDisplayString(keyCode: 18, modifiers: 4096)
        XCTAssertEqual(display, "⌃1")
    }

    func testHotkeyDisplayStringMultipleModifiers() {
        // ⌃⌥A (controlKey | optionKey, keyCode 0)
        let display = Settings.hotkeyDisplayString(keyCode: 0, modifiers: 4096 | 2048)
        XCTAssertEqual(display, "⌃⌥A")
    }

    func testKeyCodeToString() {
        XCTAssertEqual(Settings.keyCodeToString(18), "1")
        XCTAssertEqual(Settings.keyCodeToString(0), "A")
        XCTAssertEqual(Settings.keyCodeToString(126), "↑")
    }

    // MARK: - Enum Raw Values

    func testPenColorRawValue() {
        XCTAssertEqual(PenColor.red.rawValue, "red")
        XCTAssertEqual(PenColor(rawValue: "blue"), .blue)
        XCTAssertNil(PenColor(rawValue: "invalid"))
    }

    func testBreakTimerBackgroundRawValue() {
        XCTAssertEqual(BreakTimerBackground.black.rawValue, "black")
        XCTAssertEqual(BreakTimerBackground.fadedDesktop.rawValue, "fadedDesktop")
        XCTAssertEqual(BreakTimerBackground(rawValue: "fadedDesktop"), .fadedDesktop)
    }

    func testFontWeightOptionRawValue() {
        XCTAssertEqual(FontWeightOption.medium.rawValue, "medium")
        XCTAssertEqual(FontWeightOption(rawValue: "bold"), .bold)
        XCTAssertNil(FontWeightOption(rawValue: "nonexistent"))
    }

    // MARK: - Modifier Conversion

    func testCarbonToNSModifiersControl() {
        let flags = Settings.carbonToNSEventModifiers(UInt32(controlKey))
        XCTAssertTrue(flags.contains(.control))
        XCTAssertFalse(flags.contains(.option))
        XCTAssertFalse(flags.contains(.shift))
        XCTAssertFalse(flags.contains(.command))
    }

    func testCarbonToNSModifiersOption() {
        let flags = Settings.carbonToNSEventModifiers(UInt32(optionKey))
        XCTAssertTrue(flags.contains(.option))
    }

    func testCarbonToNSModifiersShift() {
        let flags = Settings.carbonToNSEventModifiers(UInt32(shiftKey))
        XCTAssertTrue(flags.contains(.shift))
    }

    func testCarbonToNSModifiersCommand() {
        let flags = Settings.carbonToNSEventModifiers(UInt32(cmdKey))
        XCTAssertTrue(flags.contains(.command))
    }

    func testCarbonToNSModifiersCombined() {
        let carbon = UInt32(controlKey) | UInt32(shiftKey)
        let flags = Settings.carbonToNSEventModifiers(carbon)
        XCTAssertTrue(flags.contains(.control))
        XCTAssertTrue(flags.contains(.shift))
        XCTAssertFalse(flags.contains(.option))
        XCTAssertFalse(flags.contains(.command))
    }

    func testCarbonToNSModifiersEmpty() {
        let flags = Settings.carbonToNSEventModifiers(0)
        XCTAssertTrue(flags.isEmpty)
    }

    func testNSEventToCarbonModifiersControl() {
        let carbon = Settings.nsEventToCarbonModifiers(.control)
        XCTAssertNotEqual(carbon & UInt32(controlKey), 0)
    }

    func testNSEventToCarbonModifiersCombined() {
        let flags: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
        let carbon = Settings.nsEventToCarbonModifiers(flags)
        XCTAssertNotEqual(carbon & UInt32(controlKey), 0)
        XCTAssertNotEqual(carbon & UInt32(optionKey), 0)
        XCTAssertNotEqual(carbon & UInt32(shiftKey), 0)
        XCTAssertNotEqual(carbon & UInt32(cmdKey), 0)
    }

    func testNSEventToCarbonModifiersEmpty() {
        let carbon = Settings.nsEventToCarbonModifiers([])
        XCTAssertEqual(carbon, 0)
    }

    func testModifierConversionRoundTrip() {
        let originalCarbon = UInt32(controlKey) | UInt32(shiftKey)
        let nsFlags = Settings.carbonToNSEventModifiers(originalCarbon)
        let roundTripped = Settings.nsEventToCarbonModifiers(nsFlags)
        XCTAssertEqual(roundTripped, originalCarbon)
    }

    func testModifierConversionRoundTripAllModifiers() {
        let allCarbon = UInt32(controlKey) | UInt32(optionKey) | UInt32(shiftKey) | UInt32(cmdKey)
        let nsFlags = Settings.carbonToNSEventModifiers(allCarbon)
        let roundTripped = Settings.nsEventToCarbonModifiers(nsFlags)
        XCTAssertEqual(roundTripped, allCarbon)
    }

    // MARK: - keyCodeToMenuCharacter

    func testKeyCodeToMenuCharacterLetter() {
        let char = Settings.keyCodeToMenuCharacter(0) // kVK_ANSI_A
        XCTAssertEqual(char, "a")
    }

    func testKeyCodeToMenuCharacterNumber() {
        let char = Settings.keyCodeToMenuCharacter(18) // kVK_ANSI_1
        XCTAssertEqual(char, "1")
    }

    func testKeyCodeToMenuCharacterSpecial() {
        let char = Settings.keyCodeToMenuCharacter(126) // kVK_UpArrow
        XCTAssertEqual(char, "↑")
    }

    func testKeyCodeToMenuCharacterFunctionKey() {
        let char = Settings.keyCodeToMenuCharacter(122) // kVK_F1
        XCTAssertEqual(char, "f1")
    }

    // MARK: - Hotkey Independence

    func testHotkeyIndependentPersistence() {
        Settings.shared.zoomHotkeyKeyCode = 0  // A
        Settings.shared.drawHotkeyKeyCode = 11 // B
        Settings.shared.breakHotkeyKeyCode = 8 // C

        XCTAssertEqual(Settings.shared.zoomHotkeyKeyCode, 0)
        XCTAssertEqual(Settings.shared.drawHotkeyKeyCode, 11)
        XCTAssertEqual(Settings.shared.breakHotkeyKeyCode, 8)
    }

    // MARK: - Live Zoom Hotkey

    func testDefaultLiveZoomHotkey() {
        // Default: ⌃4 (keyCode 21 = kVK_ANSI_4, modifiers = controlKey)
        XCTAssertEqual(Settings.shared.liveZoomHotkeyKeyCode, UInt32(kVK_ANSI_4))
        XCTAssertEqual(Settings.shared.liveZoomHotkeyModifiers, UInt32(controlKey))
    }

    func testLiveZoomHotkeyRoundTrip() {
        Settings.shared.liveZoomHotkeyKeyCode = UInt32(kVK_ANSI_L)
        Settings.shared.liveZoomHotkeyModifiers = UInt32(controlKey | optionKey)

        XCTAssertEqual(Settings.shared.liveZoomHotkeyKeyCode, UInt32(kVK_ANSI_L))
        XCTAssertEqual(Settings.shared.liveZoomHotkeyModifiers, UInt32(controlKey | optionKey))
    }

    func testLiveZoomHotkeyIndependentOfOtherHotkeys() {
        Settings.shared.liveZoomHotkeyKeyCode = UInt32(kVK_ANSI_5)
        Settings.shared.zoomHotkeyKeyCode = UInt32(kVK_ANSI_9)

        XCTAssertEqual(Settings.shared.liveZoomHotkeyKeyCode, UInt32(kVK_ANSI_5))
        XCTAssertEqual(Settings.shared.zoomHotkeyKeyCode, UInt32(kVK_ANSI_9))
    }

    func testLiveZoomHotkeyResetToDefaults() {
        Settings.shared.liveZoomHotkeyKeyCode = UInt32(kVK_ANSI_X)
        Settings.shared.liveZoomHotkeyModifiers = UInt32(cmdKey)

        Settings.shared.resetToDefaults()

        XCTAssertEqual(Settings.shared.liveZoomHotkeyKeyCode, UInt32(kVK_ANSI_4))
        XCTAssertEqual(Settings.shared.liveZoomHotkeyModifiers, UInt32(controlKey))
    }
}
