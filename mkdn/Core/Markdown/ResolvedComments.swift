#if os(macOS)
    import Foundation

    /// A document's comments resolved against its rendered ``AnchorTape``: the
    /// id→builder-`NSRange` index joined with the originating sidecar entries, so
    /// consumers read highlight ranges (overlay draw), bodies (popover), and
    /// orphans (sidebar) from one place.
    struct ResolvedComments: Equatable {
        private let index: CommentAnchorResolver.Index
        private let entriesByID: [String: CommentSidecar.Entry]
        /// id → position in the sidecar (creation order, oldest first). Comment ids are
        /// random, so this is what orders comments that share an anchor.
        private let creationOrder: [String: Int]

        static func resolve(_ entries: [CommentSidecar.Entry], in tape: AnchorTape) -> ResolvedComments {
            // The sidecar is user-editable, so guard against duplicate ids: keep the
            // first per id and resolve that set, so an id lands in exactly one of
            // resolved/orphaned and its entry matches its resolution.
            var seen = Set<String>()
            let unique = entries.filter { seen.insert($0.id).inserted }
            let index = CommentAnchorResolver.resolveAll(unique, in: tape)
            let byID = Dictionary(uniqueKeysWithValues: unique.map { ($0.id, $0) })
            let order = Dictionary(uniqueKeysWithValues: unique.enumerated().map { ($0.element.id, $0.offset) })
            return ResolvedComments(index: index, entriesByID: byID, creationOrder: order)
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

        /// The resolved comments for the given ids, innermost (smallest span) first
        /// — for opening an overlap cluster from its badge, where the ids are known
        /// but no single offset lies inside them all.
        func comments(ids: [String]) -> [(entry: CommentSidecar.Entry, range: NSRange)] {
            ids.compactMap { id in
                guard let range = index.ranges[id], let entry = entriesByID[id] else { return nil }
                return (entry: entry, range: range)
            }
            .sorted { $0.range.length < $1.range.length }
        }

        /// Resolved comments in document order (by range location), ties broken by
        /// creation order — oldest first — so comments sharing an anchor read top-down
        /// as a thread. Drives the sidebar's anchored cards and the gutter marks.
        var active: [(id: String, entry: CommentSidecar.Entry, range: NSRange)] {
            index.ranges.compactMap { id, range in
                entriesByID[id].map { (id: id, entry: $0, range: range) }
            }
            .sorted {
                ($0.range.location, creationOrder[$0.id] ?? .max)
                    < ($1.range.location, creationOrder[$1.id] ?? .max)
            }
        }

        /// Entries whose anchor couldn't be located, for the orphan sidebar.
        var orphans: [CommentSidecar.Entry] {
            index.orphaned.compactMap { entriesByID[$0] }
        }
    }
#endif
