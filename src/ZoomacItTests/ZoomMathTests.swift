import XCTest
@testable import ZoomacIt

final class ZoomMathTests: XCTestCase {

    // MARK: - clamp

    func testClampWithinRange() {
        XCTAssertEqual(ZoomMath.clamp(5.0, lower: 0, upper: 10), 5.0)
    }

    func testClampBelowLower() {
        XCTAssertEqual(ZoomMath.clamp(-1.0, lower: 0, upper: 10), 0.0)
    }

    func testClampAboveUpper() {
        XCTAssertEqual(ZoomMath.clamp(15.0, lower: 0, upper: 10), 10.0)
    }

    func testClampAtBoundaries() {
        XCTAssertEqual(ZoomMath.clamp(0.0, lower: 0, upper: 10), 0.0)
        XCTAssertEqual(ZoomMath.clamp(10.0, lower: 0, upper: 10), 10.0)
    }

    // MARK: - clampZoomLevel

    func testClampZoomLevelDefault() {
        XCTAssertEqual(ZoomMath.clampZoomLevel(2.0), 2.0)
        XCTAssertEqual(ZoomMath.clampZoomLevel(0.5), 1.0)
        XCTAssertEqual(ZoomMath.clampZoomLevel(10.0), 8.0)
    }

    func testClampZoomLevelCustomRange() {
        XCTAssertEqual(ZoomMath.clampZoomLevel(0.3, minimum: 0.5, maximum: 4.0), 0.5)
        XCTAssertEqual(ZoomMath.clampZoomLevel(5.0, minimum: 0.5, maximum: 4.0), 4.0)
    }

    // MARK: - defaultPanCenter

    func testDefaultPanCenterIsImageCenter() {
        let size = CGSize(width: 1920, height: 1080)
        let center = ZoomMath.defaultPanCenter(for: size)
        XCTAssertEqual(center.x, 960.0)
        XCTAssertEqual(center.y, 540.0)
    }

    // MARK: - visibleContentsRect

    func testVisibleContentsRectAtZoom1x() {
        let rect = ZoomMath.visibleContentsRect(
            zoomLevel: 1.0,
            panCenter: CGPoint(x: 960, y: 540),
            imageSize: CGSize(width: 1920, height: 1080)
        )
        // At 1x zoom, visible rect should cover the entire image
        XCTAssertEqual(rect.origin.x, 0.0, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, 0.0, accuracy: 0.001)
        XCTAssertEqual(rect.size.width, 1.0, accuracy: 0.001)
        XCTAssertEqual(rect.size.height, 1.0, accuracy: 0.001)
    }

    func testVisibleContentsRectAtZoom2xCenter() {
        let rect = ZoomMath.visibleContentsRect(
            zoomLevel: 2.0,
            panCenter: CGPoint(x: 960, y: 540),
            imageSize: CGSize(width: 1920, height: 1080)
        )
        // At 2x zoom centred, visible rect = 0.5x0.5, origin at (0.25, 0.25)
        XCTAssertEqual(rect.origin.x, 0.25, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, 0.25, accuracy: 0.001)
        XCTAssertEqual(rect.size.width, 0.5, accuracy: 0.001)
        XCTAssertEqual(rect.size.height, 0.5, accuracy: 0.001)
    }

    func testVisibleContentsRectAtZoom4x() {
        let rect = ZoomMath.visibleContentsRect(
            zoomLevel: 4.0,
            panCenter: CGPoint(x: 960, y: 540),
            imageSize: CGSize(width: 1920, height: 1080)
        )
        // At 4x zoom, visible rect = 0.25x0.25
        XCTAssertEqual(rect.size.width, 0.25, accuracy: 0.001)
        XCTAssertEqual(rect.size.height, 0.25, accuracy: 0.001)
    }

    func testVisibleContentsRectClampsToTopLeft() {
        // Pan to top-left corner (0,0)
        let rect = ZoomMath.visibleContentsRect(
            zoomLevel: 2.0,
            panCenter: CGPoint(x: 0, y: 0),
            imageSize: CGSize(width: 1920, height: 1080)
        )
        // Origin must not go below (0,0)
        XCTAssertEqual(rect.origin.x, 0.0, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, 0.0, accuracy: 0.001)
        XCTAssertEqual(rect.size.width, 0.5, accuracy: 0.001)
        XCTAssertEqual(rect.size.height, 0.5, accuracy: 0.001)
    }

    func testVisibleContentsRectClampsToBottomRight() {
        // Pan to bottom-right corner
        let rect = ZoomMath.visibleContentsRect(
            zoomLevel: 2.0,
            panCenter: CGPoint(x: 1920, y: 1080),
            imageSize: CGSize(width: 1920, height: 1080)
        )
        // Origin must not let rect extend beyond (1,1)
        XCTAssertEqual(rect.origin.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, 0.5, accuracy: 0.001)
        XCTAssertEqual(rect.size.width, 0.5, accuracy: 0.001)
        XCTAssertEqual(rect.size.height, 0.5, accuracy: 0.001)
    }

    func testVisibleContentsRectPartialPan() {
        // Pan 75% right, 50% down
        let rect = ZoomMath.visibleContentsRect(
            zoomLevel: 2.0,
            panCenter: CGPoint(x: 1440, y: 540),
            imageSize: CGSize(width: 1920, height: 1080)
        )
        // normCenterX = 0.75 → originX = 0.75-0.25 = 0.50
        XCTAssertEqual(rect.origin.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, 0.25, accuracy: 0.001)
    }

    // MARK: - cropRect (Y-flip)

    func testCropRectFlipsYCoordinate() {
        // A contentsRect at top of CALayer (origin.y=0.5, height=0.5)
        // should become a crop at top of image (y=0 in CGImage coords)
        let contentsRect = CGRect(x: 0.0, y: 0.5, width: 1.0, height: 0.5)
        let sourceSize = CGSize(width: 1920, height: 1080)

        let crop = ZoomMath.cropRect(contentsRect: contentsRect, sourceSize: sourceSize)

        // Flipped: imageY = 1.0 - 0.5 - 0.5 = 0.0
        XCTAssertEqual(crop.origin.y, 0.0, accuracy: 1.0)
        XCTAssertEqual(crop.origin.x, 0.0, accuracy: 1.0)
        XCTAssertEqual(crop.size.width, 1920.0, accuracy: 1.0)
        XCTAssertEqual(crop.size.height, 540.0, accuracy: 1.0)
    }

    func testCropRectFullImage() {
        let contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        let sourceSize = CGSize(width: 2560, height: 1440)

        let crop = ZoomMath.cropRect(contentsRect: contentsRect, sourceSize: sourceSize)

        XCTAssertEqual(crop.origin.x, 0.0, accuracy: 1.0)
        XCTAssertEqual(crop.origin.y, 0.0, accuracy: 1.0)
        XCTAssertEqual(crop.size.width, 2560.0, accuracy: 1.0)
        XCTAssertEqual(crop.size.height, 1440.0, accuracy: 1.0)
    }

    func testCropRectBottomLeftQuadrant() {
        // CALayer bottom-left quadrant: origin=(0,0), size=0.5x0.5
        // CGImage: flippedY = 1.0-0.0-0.5 = 0.5 → bottom half in image coords
        let contentsRect = CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        let sourceSize = CGSize(width: 2000, height: 2000)

        let crop = ZoomMath.cropRect(contentsRect: contentsRect, sourceSize: sourceSize)

        XCTAssertEqual(crop.origin.x, 0.0, accuracy: 1.0)
        XCTAssertEqual(crop.origin.y, 1000.0, accuracy: 1.0)
        XCTAssertEqual(crop.size.width, 1000.0, accuracy: 1.0)
        XCTAssertEqual(crop.size.height, 1000.0, accuracy: 1.0)
    }

    func testCropRectCentre2xZoom() {
        // 2x zoom centred: contentsRect = (0.25, 0.25, 0.5, 0.5)
        let contentsRect = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        let sourceSize = CGSize(width: 1920, height: 1080)

        let crop = ZoomMath.cropRect(contentsRect: contentsRect, sourceSize: sourceSize)

        // flippedY = 1.0 - 0.25 - 0.5 = 0.25
        XCTAssertEqual(crop.origin.x, 480.0, accuracy: 1.0)
        XCTAssertEqual(crop.origin.y, 270.0, accuracy: 1.0)
        XCTAssertEqual(crop.size.width, 960.0, accuracy: 1.0)
        XCTAssertEqual(crop.size.height, 540.0, accuracy: 1.0)
    }

    // MARK: - Integration: visibleContentsRect → cropRect round-trip

    func testRoundTripCentered2x() {
        let imageSize = CGSize(width: 3840, height: 2160)
        let center = ZoomMath.defaultPanCenter(for: imageSize)

        let visible = ZoomMath.visibleContentsRect(
            zoomLevel: 2.0,
            panCenter: center,
            imageSize: imageSize
        )
        let crop = ZoomMath.cropRect(contentsRect: visible, sourceSize: imageSize)

        // Centred 2x: should crop the middle quarter
        XCTAssertEqual(crop.origin.x, 960.0, accuracy: 1.0)
        XCTAssertEqual(crop.origin.y, 540.0, accuracy: 1.0)
        XCTAssertEqual(crop.size.width, 1920.0, accuracy: 1.0)
        XCTAssertEqual(crop.size.height, 1080.0, accuracy: 1.0)
    }
}
