#if os(macOS)
    import AppKit
#else
    import UIKit
#endif
import SwiftMath

/// Renders LaTeX math expressions to images using SwiftMath.
///
/// SwiftMath renders via CoreGraphics drawing commands, producing
/// resolution-independent output that renders crisply on Retina displays.
/// Uses the `MathImage` struct (not a view), so rendering is safe from any thread.
public enum MathRenderer {
    /// Renders a LaTeX expression to a platform image.
    ///
    /// - Parameters:
    ///   - latex: The LaTeX math expression (without delimiters).
    ///   - fontSize: Point size for rendering.
    ///   - textColor: Foreground color for the math glyphs.
    ///   - displayMode: true for display equations (larger, centered operators),
    ///                  false for inline (text-sized operators).
    /// - Returns: A tuple of (image, baseline) on success, nil on parse failure.
    ///   The baseline is the distance from the bottom of the image to the
    ///   mathematical baseline, used for NSTextAttachment alignment.
    public static func renderToImage(
        latex: String,
        fontSize: CGFloat,
        textColor: PlatformTypeConverter.PlatformColor,
        displayMode: Bool = false
    ) -> (image: PlatformTypeConverter.PlatformImage, baseline: CGFloat)? {
        let trimmed = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var mathImage = MathImage(
            latex: trimmed,
            fontSize: fontSize,
            textColor: textColor,
            labelMode: displayMode ? .display : .text,
            textAlignment: displayMode ? .center : .left
        )

        let (error, image, layoutInfo) = mathImage.asImage()

        guard error == nil,
              let image,
              let layoutInfo,
              image.size.width > 0,
              image.size.height > 0
        else {
            return nil
        }

        return (image: image, baseline: layoutInfo.descent)
    }
}
