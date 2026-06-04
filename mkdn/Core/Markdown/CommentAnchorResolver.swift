#if os(macOS)
    import Foundation

    /// Deterministically locates a v2 comment's anchor in the rendered
    /// ``AnchorTape``.
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
    /// deferred to v2.)
    enum CommentAnchorResolver {
        enum Resolution: Equatable {
            /// Builder `NSRange` in the source `NSAttributedString` the tape was built from.
            case resolved(NSRange)
            case orphaned
        }

        static func resolve(_ entry: CommentSidecar.Entry, in tape: AnchorTape) -> Resolution {
            let quote = Array(entry.quote.utf16)
            guard !quote.isEmpty else { return .orphaned }

            let text = Array(tape.text.utf16)
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
            guard matches.count != 1 else { return matches[0] }
            guard matches.count > 1 else { return nil }

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
            guard let hint = entry.start else { return nil }
            let distances = winners.map { abs($0.lowerBound - hint) }
            let nearest = distances.min()!
            let tied = winners.indices.filter { distances[$0] == nearest }
            return tied.count == 1 ? winners[tied[0]] : nil
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
            var n = 0
            var ai = a.startIndex
            while n < b.count, ai < a.endIndex, a[ai] == b[n] {
                n += 1
                ai = a.index(after: ai)
            }
            return n
        }

        private static func commonSuffixLength(_ a: ArraySlice<unichar>, _ b: [unichar]) -> Int {
            var n = 0
            var ai = a.endIndex
            while n < b.count, ai > a.startIndex {
                ai = a.index(before: ai)
                if a[ai] == b[b.count - 1 - n] { n += 1 } else { break }
            }
            return n
        }
    }
#endif
