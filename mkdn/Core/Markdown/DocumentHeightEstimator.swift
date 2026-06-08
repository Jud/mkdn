#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Estimates the laid-out height of a markdown document without running the
/// renderer's TextKit fragment layout. A single Core Text measurement
/// (`boundingRect`) over the whole attributed string matches TextKit 2's real
/// layout height to the pixel — at far less cost than realizing every layout
/// fragment — so it can size the scroll view's vertical extent up front,
/// before the document is laid out.
///
/// Per-block summing was measured against the same oracle and over-counts by
/// one phantom trailing-newline line per block; the whole-string measure has
/// no such seam, so the total is taken in one pass.
@MainActor
public enum DocumentHeightEstimator {
    /// - Parameters:
    ///   - textWidth: width available to text — the text container's width
    ///     minus its line-fragment padding on both edges.
    ///   - verticalInset: the text container's vertical inset, added top and bottom.
    public static func estimatedHeight(
        of attributedString: NSAttributedString,
        textWidth: CGFloat,
        verticalInset: CGFloat
    ) -> CGFloat {
        guard attributedString.length > 0, textWidth > 0 else { return 0 }
        let measured = attributedString.boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).height
        return ceil(measured) + verticalInset * 2
    }
}
