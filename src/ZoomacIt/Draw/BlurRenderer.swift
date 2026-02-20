import AppKit
import CoreGraphics
import CoreImage

/// Renders blur effects for the X / Shift+X tool.
enum BlurRenderer {

    /// Applies a Gaussian blur to a region of the source image.
    /// - Parameters:
    ///   - sourceImage: The original screen capture or canvas content.
    ///   - region: The region to blur (in image coordinates).
    ///   - strength: Blur radius.
    /// - Returns: A CGImage of the blurred region, or nil on failure.
    static func blurRegion(
        of sourceImage: CGImage,
        region: CGRect,
        strength: BlurStrength
    ) -> CGImage? {
        let ciImage = CIImage(cgImage: sourceImage)

        // Crop to the specified region
        let cropped = ciImage.cropped(to: region)

        // Apply Gaussian blur
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return nil }
        blurFilter.setValue(cropped, forKey: kCIInputImageKey)
        blurFilter.setValue(strength.radius, forKey: kCIInputRadiusKey)

        guard let output = blurFilter.outputImage else { return nil }

        // Clamp to prevent edge expansion from the blur
        let clamped = output.cropped(to: cropped.extent)

        let ciContext = CIContext()
        return ciContext.createCGImage(clamped, from: clamped.extent)
    }
}
