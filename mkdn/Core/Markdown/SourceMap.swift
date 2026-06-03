import Foundation

extension NSAttributedString.Key {
    /// Carries `SourceSpan` (as `[start, end]` UTF-16 source offsets) through into
    /// the built `NSAttributedString`.
    static let mkdnSourceSpan = NSAttributedString.Key("mkdnSourceSpan")
}

/// Maps ranges of the built `NSAttributedString` (UTF-16) to and from UTF-16
/// ranges in the parsed (transformed) source, using the `mkdnSourceSpan` runs.
///
/// Each segment is either **linear** (rendered length == source length, so
/// interior positions map proportionally) or **atomic** (a whole token whose
/// source is longer than what renders — link/inline-code; any touch snaps to the
/// whole token). Builder ranges touching synthetic characters (list bullets,
/// terminator newlines, attachments) or transformed text (escapes, math) have no
/// mapping. Cross-segment selections are rejected (reject-first).
struct SourceMap {
    struct Segment {
        let builderStart: Int
        let builderEnd: Int
        let sourceStart: Int
        let sourceEnd: Int

        /// Atomic when the rendered run differs in length from its source token
        /// (a link/inline-code whose delimiters don't render).
        var isAtomic: Bool { (sourceEnd - sourceStart) != (builderEnd - builderStart) }
    }

    private let segments: [Segment]

    init(segments: [Segment]) {
        self.segments = segments
    }

    /// Build a map from the `mkdnSourceSpan` runs of a finished attributed
    /// string. The default enumeration coalesces to the longest effective range,
    /// re-merging fragments that a later attribute (font, color) split apart but
    /// that share one source span. This relies on the invariant that distinct
    /// source tokens always carry distinct spans, so genuinely different runs
    /// never coalesce into one (mis-mapping) segment.
    init(attributedString: NSAttributedString) {
        var segments: [Segment] = []
        let full = NSRange(location: 0, length: attributedString.length)
        attributedString.enumerateAttribute(.mkdnSourceSpan, in: full, options: []) { value, range, _ in
            guard let pair = value as? [Int], let span = SourceSpan(attributeArray: pair) else { return }
            segments.append(Segment(
                builderStart: range.location,
                builderEnd: range.location + range.length,
                sourceStart: span.start,
                sourceEnd: span.end
            ))
        }
        self.segments = segments
    }

    /// The source UTF-16 range for a builder UTF-16 range, or nil if the range
    /// is empty, escapes a mapped segment, or spans more than one segment. An
    /// atomic segment snaps any sub-range to the whole token.
    func sourceUTF16Range(forBuilder range: Range<Int>) -> Range<Int>? {
        guard range.lowerBound < range.upperBound else { return nil }
        guard let segment = segments.first(where: {
            $0.builderStart <= range.lowerBound && range.upperBound <= $0.builderEnd
        }) else {
            return nil
        }
        guard !segment.isAtomic else { return segment.sourceStart ..< segment.sourceEnd }
        let lo = segment.sourceStart + (range.lowerBound - segment.builderStart)
        let hi = segment.sourceStart + (range.upperBound - segment.builderStart)
        return lo ..< hi
    }

    /// The builder UTF-16 ranges covering a source UTF-16 range — the reverse of
    /// `sourceUTF16Range`, used to place comment highlights. A source range may
    /// map to several builder ranges (e.g. a highlight containing styled text
    /// whose runs are separate segments). An atomic segment the source range
    /// touches paints its whole rendered run.
    func builderUTF16Ranges(forSource sourceRange: Range<Int>) -> [Range<Int>] {
        guard sourceRange.lowerBound < sourceRange.upperBound else { return [] }
        var result: [Range<Int>] = []
        for segment in segments {
            let lo = max(sourceRange.lowerBound, segment.sourceStart)
            let hi = min(sourceRange.upperBound, segment.sourceEnd)
            guard lo < hi else { continue }
            if segment.isAtomic {
                result.append(segment.builderStart ..< segment.builderEnd)
            } else {
                result.append(
                    segment.builderStart + (lo - segment.sourceStart)
                        ..< segment.builderStart + (hi - segment.sourceStart)
                )
            }
        }
        return result
    }
}
