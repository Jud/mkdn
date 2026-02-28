#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Custom NSAttributedString keys and types for table cross-cell selection.
///
/// The ``range`` key marks all characters within a table's invisible text with
/// a unique table identifier. The ``cellMap`` key carries the cell geometry and
/// lookup data for character-to-cell position mapping. The ``colors`` key
/// carries resolved color values for the table container. The ``isHeader``
/// key distinguishes header row characters from data rows.
///
/// All keys are consumed by ``OverlayCoordinator`` for positioning,
/// ``TableHighlightOverlay`` for selection/find drawing,
/// ``CodeBlockBackgroundTextView`` for copy handling and print rendering,
/// and ``EntranceAnimator`` for table fragment grouping.
public enum TableAttributes {
    /// Marks all characters within a table's invisible text.
    /// Value: a unique `String` identifier per table instance (UUID).
    public static let range = NSAttributedString.Key("mkdn.tableRange")

    /// Carries the cell map for character-to-cell position mapping.
    /// Value: a ``TableCellMap`` instance (same instance on every character).
    public static let cellMap = NSAttributedString.Key("mkdn.tableCellMap")

    /// Carries resolved color values for the table container.
    /// Value: a ``TableColorInfo`` instance.
    public static let colors = NSAttributedString.Key("mkdn.tableColors")

    /// Marks header row characters for differentiated selection highlight.
    /// Value: `NSNumber(booleanLiteral: true)`.
    public static let isHeader = NSAttributedString.Key("mkdn.tableIsHeader")
}

/// Resolved color values for drawing a table container.
///
/// Stored as an attributed string attribute value so the drawing code
/// can access theme colors without external state. This is a class (not struct)
/// because `NSAttributedString` attribute values must be `NSObject` subclasses
/// or bridged types for reliable attribute enumeration.
public final class TableColorInfo: NSObject {
    public let background: PlatformTypeConverter.PlatformColor
    public let backgroundSecondary: PlatformTypeConverter.PlatformColor
    public let border: PlatformTypeConverter.PlatformColor
    public let headerBackground: PlatformTypeConverter.PlatformColor
    public let foreground: PlatformTypeConverter.PlatformColor
    public let headingColor: PlatformTypeConverter.PlatformColor

    public init(
        background: PlatformTypeConverter.PlatformColor,
        backgroundSecondary: PlatformTypeConverter.PlatformColor,
        border: PlatformTypeConverter.PlatformColor,
        headerBackground: PlatformTypeConverter.PlatformColor,
        foreground: PlatformTypeConverter.PlatformColor,
        headingColor: PlatformTypeConverter.PlatformColor
    ) {
        self.background = background
        self.backgroundSecondary = backgroundSecondary
        self.border = border
        self.headerBackground = headerBackground
        self.foreground = foreground
        self.headingColor = headingColor
    }
}
