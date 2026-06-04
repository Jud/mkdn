#if os(macOS)
    import Foundation

    /// Deterministically locates v2 comment anchors in the rendered ``AnchorTape``.
    ///
    /// The entry's `quote`/`prefix`/`suffix` are assumed already normalized by the
    /// same shared normalizer that built the tape, so resolution is exact-substring
    /// search over the normalized text — no re-normalization here:
    /// - **0 matches** → orphaned.
    /// - **1 match** → resolved to its builder `NSRange` (context is never a hard
    ///   requirement, so a lone match anchors even if its surroundings changed).
    /// - **>1 matches** → disambiguate by `prefix`/`suffix` context (soft score),
    ///   then by nearest `start` position hint. Still ambiguous → orphaned.
    ///
    /// A comment is *about* specific text: if the quote can't be located uniquely we
    /// orphan rather than mis-place. (Fuzzy re-attachment through small edits is
    /// deferred to v2.) This is the v2 successor to the prose-only, hard-context
    /// `CriticMarkup.reanchorRange`; the two differ deliberately (soft vs. hard
    /// context, tape `unichar` space vs. transformed source) and should not be merged.
    enum CommentAnchorResolver {
        enum Resolution: Equatable {
            /// Builder `NSRange` in the source `NSAttributedString` the tape was built from.
            case resolved(NSRange)
            case orphaned
        }

        /// The resolved-range index for a document: comment id → builder `NSRange`
        /// for every entry that anchored, plus the ids that orphaned. This is the
        /// single source for highlight drawing, hit-testing, and the overlap sweep.
        struct Index: Equatable {
            var ranges: [String: NSRange] = [:]
            var orphaned: [String] = []
        }

        /// Resolve every entry against one tape, converting the tape text to its
        /// UTF-16 search form once for the whole batch.
        static func resolveAll(_ entries: [CommentSidecar.Entry], in tape: AnchorTape) -> Index {
            let text = Array(tape.text.utf16)
            var index = Index()
            for entry in entries {
                switch resolve(entry, text: text, tape: tape) {
                case let .resolved(range): index.ranges[entry.id] = range
                case .orphaned: index.orphaned.append(entry.id)
                }
            }
            return index
        }

        static func resolve(_ entry: CommentSidecar.Entry, in tape: AnchorTape) -> Resolution {
            resolve(entry, text: Array(tape.text.utf16), tape: tape)
        }

        private static func resolve(
            _ entry: CommentSidecar.Entry, text: [unichar], tape: AnchorTape
        ) -> Resolution {
            // A selector recorded under a different normalizer can't be trusted to
            // exact-match this tape; orphan (surfaced in the sidebar) rather than
            // silently mismatch. Re-anchoring across versions is deferred to v2.
            guard entry.norm == AnchorTape.normalizationVersion else { return .orphaned }
            let quote = Array(entry.quote.utf16)
            guard !quote.isEmpty else { return .orphaned }

            let matches = occurrences(of: quote, in: text)
            guard let chosen = disambiguate(matches, entry: entry, text: text),
                  let builder = tape.builderRange(forNormalized: chosen)
            else { return .orphaned }
            return .resolved(builder)
        }

        /// Pick the single normalized range that best matches the entry, or nil when
        /// no match exists or the candidates can't be reduced to one.
        private static func disambiguate(
            _ matches: [Range<Int>], entry: CommentSidecar.Entry, text: [unichar]
        ) -> Range<Int>? {
            guard !matches.isEmpty else { return nil }
            guard matches.count > 1 else { return matches[0] }

            let prefix = Array(entry.prefix.utf16)
            let suffix = Array(entry.suffix.utf16)
            let scored = matches.map { match -> (range: Range<Int>, score: Int) in
                let before = commonSuffixLength(text[0 ..< match.lowerBound], prefix)
                let after = commonPrefixLength(text[match.upperBound...], suffix)
                return (match, before + after)
            }
            let best = scored.map(\.score).max()!
            let winners = scored.filter { $0.score == best }.map(\.range)
            if winners.count == 1 { return winners[0] }

            // Context tied: fall back to the position hint, biasing to the nearest
            // candidate. No hint, or two candidates equidistant from it, is a true
            // tie — orphan rather than guess.
            // A position hint outside the tape is stale or corrupt (the sidecar is
            // untrusted input): ignore it rather than let it pick an edge candidate,
            // and avoid overflow in the distance math below.
            guard let hint = entry.start, hint >= 0, hint <= text.count else { return nil }
            let nearest = winners.map { abs($0.lowerBound - hint) }.min()!
            let tied = winners.filter { abs($0.lowerBound - hint) == nearest }
            return tied.count == 1 ? tied[0] : nil
        }

        /// All (possibly overlapping) start-aligned occurrences of `pattern` in `text`.
        private static func occurrences(of pattern: [unichar], in text: [unichar]) -> [Range<Int>] {
            guard pattern.count <= text.count else { return [] }
            var result: [Range<Int>] = []
            let lastStart = text.count - pattern.count
            var i = 0
            while i <= lastStart {
                var k = 0
                while k < pattern.count, text[i + k] == pattern[k] { k += 1 }
                if k == pattern.count { result.append(i ..< (i + pattern.count)) }
                i += 1
            }
            return result
        }

        private static func commonPrefixLength(_ a: ArraySlice<unichar>, _ b: [unichar]) -> Int {
            zip(a, b).prefix { $0.0 == $0.1 }.count
        }

        private static func commonSuffixLength(_ a: ArraySlice<unichar>, _ b: [unichar]) -> Int {
            zip(a.reversed(), b.reversed()).prefix { $0.0 == $0.1 }.count
        }
    }
#endif
