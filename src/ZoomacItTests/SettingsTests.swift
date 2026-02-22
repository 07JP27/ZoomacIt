import XCTest
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
}
