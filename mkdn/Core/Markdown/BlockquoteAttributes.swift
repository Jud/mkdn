#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Custom NSAttributedString key for blockquote bar rendering.
///
/// The builder marks every character of a blockquote's content (including
/// paragraph terminators) with a ``BlockquoteBarInfo``; the text view's
/// `drawBackground(in:)` draws a vertical bar per nesting level beside the
/// indented text, mirroring the code-block container pattern.
public enum BlockquoteAttributes {
    /// Applied to all characters within a blockquote's content.
    /// Value: a ``BlockquoteBarInfo`` instance (shared per blockquote level so
    /// consecutive paragraphs coalesce into one continuous bar).
    public static let bar = NSAttributedString.Key("mkdn.blockquoteBar")
}

/// Resolved values for drawing a blockquote's bars.
///
/// A class (not struct) for the same reason as ``CodeBlockColorInfo``:
/// attribute values must be `NSObject` subclasses for reliable enumeration,
/// and identity equality lets consecutive runs coalesce.
public final class BlockquoteBarInfo: NSObject {
    public let color: PlatformTypeConverter.PlatformColor
    /// Nesting depth (0 = outermost); a bar is drawn for every level `0...depth`.
    public let depth: Int

    public init(color: PlatformTypeConverter.PlatformColor, depth: Int) {
        self.color = color
        self.depth = depth
    }
}
