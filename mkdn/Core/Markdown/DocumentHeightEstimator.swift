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
        return ceil(contentHeight(of: attributedString, textWidth: textWidth)) + verticalInset * 2
    }

    /// The document height, taking the fast per-block path when a block model is available.
    /// A whole-document `boundingRect` is super-linear in string length for some content
    /// (font fallback), so with a non-empty model the per-block sum is ~12x cheaper and
    /// lands on the same height; without one (non-markdown content), the whole-document
    /// measure is the only option. Keeping the choice here means callers can't accidentally
    /// reach for the slow path and reintroduce the open-time freeze.
    public static func estimatedHeight(
        of attributedString: NSAttributedString,
        model: DocumentHeightModel?,
        textWidth: CGFloat,
        verticalInset: CGFloat
    ) -> CGFloat {
        if let model, !model.blocks.isEmpty {
            return DocumentBlockOffsets.estimatedHeight(
                of: attributedString,
                model: model,
                textWidth: textWidth,
                verticalInset: verticalInset
            )
        }
        return estimatedHeight(of: attributedString, textWidth: textWidth, verticalInset: verticalInset)
    }

    /// The wrapped text height of `attributedString` at `textWidth` — the Core Text
    /// measure underlying both the document estimate and per-block offsets, without
    /// the vertical inset. Returns 0 for empty input or non-positive width.
    static func contentHeight(of attributedString: NSAttributedString, textWidth: CGFloat) -> CGFloat {
        guard attributedString.length > 0, textWidth > 0 else { return 0 }
        return attributedString.boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).height
    }
}
