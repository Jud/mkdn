import AppKit

/// Custom NSAttributedString keys and types for code block container rendering.
///
/// The ``range`` key marks all characters within a code block (label + body +
/// trailing newline) with a unique block identifier. The ``colors`` key carries
/// resolved `NSColor` values so the drawing code can access theme colors without
/// external state. Both keys are consumed by ``CodeBlockBackgroundTextView`` in
/// its `drawBackground(in:)` override.
enum CodeBlockAttributes {
    /// Applied to all characters within a code block (including language label).
    /// Value: a unique `String` identifier per code block instance.
    static let range = NSAttributedString.Key("mkdn.codeBlockRange")

    /// Carries the resolved NSColor values for the code block container.
    /// Value: a ``CodeBlockColorInfo`` instance.
    static let colors = NSAttributedString.Key("mkdn.codeBlockColors")
}

/// Resolved color values for drawing a code block container.
///
/// Stored as an attributed string attribute value so the drawing code
/// can access theme colors without external state. This is a class (not struct)
/// because `NSAttributedString` attribute values must be `NSObject` subclasses
/// or bridged types for reliable attribute enumeration.
final class CodeBlockColorInfo: NSObject {
    let background: NSColor
    let border: NSColor

    init(background: NSColor, border: NSColor) {
        self.background = background
        self.border = border
    }
}
