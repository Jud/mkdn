import AppKit
import SwiftMath

/// Renders LaTeX math expressions to NSImage using SwiftMath.
///
/// All rendering happens synchronously on @MainActor. SwiftMath renders via
/// CoreGraphics drawing commands into an NSImage with a draw handler, producing
/// resolution-independent output that renders crisply on Retina displays.
@MainActor
enum MathRenderer {
    /// Renders a LaTeX expression to an NSImage.
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
    static func renderToImage(
        latex: String,
        fontSize: CGFloat,
        textColor: NSColor,
        displayMode: Bool = false
    ) -> (image: NSImage, baseline: CGFloat)? {
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
