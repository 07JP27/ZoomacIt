import XCTest
@testable import ZoomacIt

final class CGContextExtensionsTests: XCTestCase {

    func testValidSizeReturnsContext() {
        let ctx = CGContext.createBitmapContext(size: CGSize(width: 100, height: 100))
        XCTAssertNotNil(ctx)
    }

    func testContextProperties() {
        let ctx = CGContext.createBitmapContext(size: CGSize(width: 200, height: 150))!
        XCTAssertEqual(ctx.width, 200)
        XCTAssertEqual(ctx.height, 150)
        XCTAssertEqual(ctx.bitsPerComponent, 8)
        XCTAssertEqual(ctx.bytesPerRow, 200 * 4)
    }

    func testZeroWidthReturnsNil() {
        let ctx = CGContext.createBitmapContext(size: CGSize(width: 0, height: 100))
        XCTAssertNil(ctx)
    }

    func testZeroHeightReturnsNil() {
        let ctx = CGContext.createBitmapContext(size: CGSize(width: 100, height: 0))
        XCTAssertNil(ctx)
    }

    func testNegativeSizeReturnsNil() {
        let ctx = CGContext.createBitmapContext(size: CGSize(width: -10, height: 100))
        XCTAssertNil(ctx)
    }

    func testFractionalSizeTruncates() {
        let ctx = CGContext.createBitmapContext(size: CGSize(width: 99.9, height: 50.1))
        XCTAssertNotNil(ctx)
        XCTAssertEqual(ctx?.width, 99)
        XCTAssertEqual(ctx?.height, 50)
    }
}
