#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Custom NSAttributedString keys and types for code block container rendering.
///
/// The ``range`` key marks all characters within a code block (label + body +
/// trailing newline) with a unique block identifier. The ``colors`` key carries
/// resolved color values so the drawing code can access theme colors without
/// external state. Both keys are consumed by ``CodeBlockBackgroundTextView`` in
/// its `drawBackground(in:)` override.
public enum CodeBlockAttributes {
    /// Applied to all characters within a code block (including language label).
    /// Value: a unique `String` identifier per code block instance.
    public static let range = NSAttributedString.Key("mkdn.codeBlockRange")

    /// Carries the resolved color values for the code block container.
    /// Value: a ``CodeBlockColorInfo`` instance.
    public static let colors = NSAttributedString.Key("mkdn.codeBlockColors")

    /// Stores the raw code string (without language label, trimmed) for clipboard copy.
    /// Value: a `String` containing the unformatted code content.
    public static let rawCode = NSAttributedString.Key("mkdn.codeBlock.rawCode")

    /// Marks an inline-code run. Value: `true` (`NSNumber`).
    ///
    /// The builder lowers the `.code` inline presentation intent to a monospaced
    /// font and otherwise drops the intent, so this attribute is the surviving
    /// signal that a run is inline code — distinct from other monospaced runs
    /// (e.g. the inline-math fallback font).
    public static let inlineCode = NSAttributedString.Key("mkdn.inlineCode")
}

/// Resolved color values for drawing a code block container.
///
/// Stored as an attributed string attribute value so the drawing code
/// can access theme colors without external state. This is a class (not struct)
/// because `NSAttributedString` attribute values must be `NSObject` subclasses
/// or bridged types for reliable attribute enumeration.
public final class CodeBlockColorInfo: NSObject {
    public let background: PlatformTypeConverter.PlatformColor

    public init(background: PlatformTypeConverter.PlatformColor) {
        self.background = background
    }
}
