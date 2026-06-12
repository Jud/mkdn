#if os(macOS)
    /// How the comment rail arranges its active cards.
    public enum CommentRailLayout: String, CaseIterable, Sendable {
        /// Cards float beside the text they annotate and follow it on scroll.
        case anchored

        /// Cards compress into a list at the top of the rail, one after another
        /// in document order, independent of the scroll position.
        case stacked

        /// Segment title in the rail's layout picker.
        public var label: String {
            switch self {
            case .anchored: "Anchored"
            case .stacked: "Stacked"
            }
        }
    }
#endif
