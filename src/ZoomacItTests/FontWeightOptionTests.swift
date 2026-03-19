import XCTest
@testable import ZoomacIt

final class FontWeightOptionTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(FontWeightOption.allCases.count, 9)
    }

    func testDisplayNames() {
        let expected: [FontWeightOption: String] = [
            .ultraLight: "Ultra Light",
            .thin: "Thin",
            .light: "Light",
            .regular: "Regular",
            .medium: "Medium",
            .semibold: "Semibold",
            .bold: "Bold",
            .heavy: "Heavy",
            .black: "Black"
        ]
        for (option, name) in expected {
            XCTAssertEqual(option.displayName, name, "Display name for \(option) should be \(name)")
        }
    }

    func testNSFontWeightMapping() {
        let expected: [FontWeightOption: NSFont.Weight] = [
            .ultraLight: .ultraLight,
            .thin: .thin,
            .light: .light,
            .regular: .regular,
            .medium: .medium,
            .semibold: .semibold,
            .bold: .bold,
            .heavy: .heavy,
            .black: .black
        ]
        for (option, weight) in expected {
            XCTAssertEqual(option.nsFontWeight, weight, "Font weight for \(option) should match")
        }
    }

    func testRawValueRoundTrip() {
        for option in FontWeightOption.allCases {
            let restored = FontWeightOption(rawValue: option.rawValue)
            XCTAssertEqual(restored, option, "Round-trip failed for \(option)")
        }
    }
}
