import CoreGraphics

/// The app's design language, distilled to three small scales.
///
/// Confident minimalism: background tone separates embedded surfaces (code,
/// images, diagrams), hairlines mark structure (tables, cards, floating
/// boxes), and shadow is reserved for elevation (overlays). Spacing sits on a
/// 4pt grid. When adding UI, pick from these scales rather than minting new
/// constants.
public enum DesignTokens {
    /// Corner radii by role.
    public enum Radius {
        /// Inline chips and badges (quote chip, detached badge).
        public static let inline: CGFloat = 4
        /// Embedded content blocks and cards (code, tables, images, diagrams).
        public static let block: CGFloat = 6
        /// Floating overlays (comment box).
        public static let overlay: CGFloat = 10
    }

    /// Hairline strokes, always 1pt — emphasis comes from opacity, not weight.
    public enum Stroke {
        public static let width: CGFloat = 1
        /// Resting hairline.
        public static let resting: CGFloat = 0.4
        /// Hovered / focused hairline.
        public static let engaged: CGFloat = 0.55
    }

    /// Background tint opacities for highlights, in increasing emphasis.
    public enum Tint {
        /// Secondary find matches, quiet washes.
        public static let subtle: CGFloat = 0.15
        /// Persistent highlights (comment spans) and selections.
        public static let resting: CGFloat = 0.3
        /// The current / hovered item (current find match, hover emphasis).
        public static let active: CGFloat = 0.4
    }
}
