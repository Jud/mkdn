import Foundation

extension NSAttributedString.Key {
    /// Carries `SourceSpanAttribute` (UTF-16 source offset of a run's first
    /// character) through into the built `NSAttributedString`.
    static let mkdnSourceSpan = NSAttributedString.Key("mkdnSourceSpan")
}

/// Maps ranges of the built `NSAttributedString` (UTF-16) back to UTF-16 offsets
/// in the parsed (transformed) source, using the `mkdnSourceSpan` runs.
///
/// Only verbatim 1:1 text carries spans, so a builder range that touches
/// synthetic characters (list bullets, terminator newlines, attachments) or
/// transformed text (escapes, math) has no mapping. Cross-segment ranges are
/// rejected — distinct segments are separated by exactly such unmapped content,
/// so they have no contiguous source counterpart (reject-first).
struct SourceMap {
    struct Segment {
        let builderStart: Int
        let builderEnd: Int
        let sourceStart: Int
    }

    private let segments: [Segment]

    init(segments: [Segment]) {
        self.segments = segments
    }

    /// Build a map from the `mkdnSourceSpan` runs of a finished attributed
    /// string. The default enumeration coalesces to the longest effective range,
    /// re-merging fragments that a later attribute (font, color) split apart but
    /// that share one source span.
    init(attributedString: NSAttributedString) {
        var segments: [Segment] = []
        let full = NSRange(location: 0, length: attributedString.length)
        attributedString.enumerateAttribute(.mkdnSourceSpan, in: full, options: []) { value, range, _ in
            guard let sourceStart = value as? Int else { return }
            segments.append(Segment(
                builderStart: range.location,
                builderEnd: range.location + range.length,
                sourceStart: sourceStart
            ))
        }
        self.segments = segments
    }

    /// The source UTF-16 range for a builder UTF-16 range, or nil if the range
    /// is empty, escapes a mapped segment, or spans more than one segment.
    func sourceUTF16Range(forBuilder range: Range<Int>) -> Range<Int>? {
        guard range.lowerBound < range.upperBound else { return nil }
        guard let segment = segments.first(where: {
            $0.builderStart <= range.lowerBound && range.upperBound <= $0.builderEnd
        }) else {
            return nil
        }
        let lo = segment.sourceStart + (range.lowerBound - segment.builderStart)
        let hi = segment.sourceStart + (range.upperBound - segment.builderStart)
        return lo ..< hi
    }
}
