#if os(macOS)
    import Foundation

    /// A document's comments resolved against its rendered ``AnchorTape``: the
    /// id→builder-`NSRange` index joined with the originating sidecar entries, so
    /// consumers read highlight ranges (overlay draw), bodies (popover), and
    /// orphans (sidebar) from one place. The single source the view layer queries,
    /// replacing the baked `.mkdnCommentID` attribute.
    struct ResolvedComments: Equatable {
        let index: CommentAnchorResolver.Index
        private let entriesByID: [String: CommentSidecar.Entry]

        static func resolve(_ entries: [CommentSidecar.Entry], in tape: AnchorTape) -> ResolvedComments {
            let index = CommentAnchorResolver.resolveAll(entries, in: tape)
            let byID = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
            return ResolvedComments(index: index, entriesByID: byID)
        }

        /// Resolved highlight ranges keyed by comment id, for the overlay draw.
        var ranges: [String: NSRange] { index.ranges }

        /// Resolved comments covering `offset`, innermost (smallest span) first —
        /// the stacked-popover order; the first is the natural popover anchor.
        func comments(containing offset: Int) -> [(entry: CommentSidecar.Entry, range: NSRange)] {
            index.comments(containing: offset).compactMap { hit in
                entriesByID[hit.id].map { (entry: $0, range: hit.range) }
            }
        }

        /// Entries whose anchor couldn't be located, for the orphan sidebar.
        var orphans: [CommentSidecar.Entry] {
            index.orphaned.compactMap { entriesByID[$0] }
        }
    }
#endif
