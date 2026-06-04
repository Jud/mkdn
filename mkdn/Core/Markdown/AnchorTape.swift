#if os(macOS)
    import AppKit

    /// A normalized, position-mapped view of the rendered text, used to anchor
    /// comments by content rather than by inline markers or per-run source spans.
    ///
    /// Prose runs are normalized — runs of whitespace collapse to a single space
    /// and ASCII letters case-fold — so cosmetic reflow or case changes don't
    /// orphan a comment. Code runs are preserved **verbatim** because code is
    /// whitespace- and case-significant. Code is detected by fenced-block tag
    /// (``CodeBlockAttributes/range``) or inline-code tag
    /// (``CodeBlockAttributes/inlineCode``).
    ///
    /// `builderRange(forNormalized:)` maps a span of the normalized text back to
    /// the `NSRange` it occupies in the source ``NSAttributedString`` (the
    /// "builder"), including any characters collapsed away inside the span. This
    /// is the anchor space the v2 comment resolver searches; unlike the prose-only
    /// `SourceMap`, it covers code, so code blocks become commentable.
    ///
    /// v1 case-folding is ASCII-only (`A`–`Z`); non-ASCII case matches verbatim.
    struct AnchorTape: Equatable {
        /// The version of the normalization scheme `build(from:)` applies. Stamped
        /// onto a comment's selectors when they're recorded (`Entry.norm`) so a
        /// later normalizer change can be detected: a selector recorded under a
        /// different version can't be trusted to exact-match this tape.
        static let normalizationVersion = 1

        let text: String

        /// `builderOffsets[i]` is the builder UTF-16 offset that normalized UTF-16
        /// unit `i` came from. Length is `text.utf16.count + 1`; the final entry is
        /// the builder length so an (end-exclusive) end position maps.
        private let builderOffsets: [Int]

        private init(text: String, builderOffsets: [Int]) {
            self.text = text
            self.builderOffsets = builderOffsets
        }

        /// The builder `NSRange` spanning a normalized UTF-16 range (end-exclusive),
        /// or nil for an empty/out-of-bounds range. The range is contiguous in the
        /// builder, so it covers any source characters that don't appear in the
        /// normalized text inside the span — collapsed whitespace runs and excluded
        /// attachment placeholders alike. A span ending at the last normalized unit
        /// therefore extends through any collapsed/excluded source that trails it.
        func builderRange(forNormalized range: Range<Int>) -> NSRange? {
            guard range.lowerBound >= 0,
                  range.lowerBound < range.upperBound,
                  range.upperBound <= builderOffsets.count - 1
            else { return nil }
            let lo = builderOffsets[range.lowerBound]
            let hi = builderOffsets[range.upperBound]
            return NSRange(location: lo, length: hi - lo)
        }

        /// The normalized UTF-16 range (end-exclusive) for a builder `NSRange`
        /// selection — the inverse of ``builderRange(forNormalized:)``, used to
        /// capture a comment selector from a text selection. Bounds snap to
        /// normalized-unit boundaries (a partially-selected collapsed-whitespace run
        /// or excluded attachment at an edge drops out). Returns nil for an empty
        /// selection or one that maps to no normalized units.
        func normalizedRange(forBuilder range: NSRange) -> Range<Int>? {
            guard range.location >= 0, range.length > 0 else { return nil }
            var lo = normalizedLowerBound(builderOffset: range.location)
            var hi = normalizedLowerBound(builderOffset: range.location + range.length)
            guard lo < hi, hi <= builderOffsets.count - 1 else { return nil }
            // Never split a surrogate pair: a boundary that lands between the high
            // and low halves of an astral character expands outward to keep the
            // pair whole, so the captured quote is valid Unicode (not a U+FFFD that
            // would never match the resolver's intact-surrogate search). TextKit
            // selections are grapheme-aligned, but this is a pure function over an
            // arbitrary NSRange.
            let units = text as NSString
            if lo > 0, UTF16.isTrailSurrogate(units.character(at: lo)) { lo -= 1 }
            if hi < units.length, UTF16.isLeadSurrogate(units.character(at: hi - 1)) { hi += 1 }
            return lo ..< hi
        }

        /// First normalized index whose builder offset is ≥ `target`
        /// (`builderOffsets` is strictly increasing). Returns `builderOffsets.count`
        /// when `target` is past every offset.
        private func normalizedLowerBound(builderOffset target: Int) -> Int {
            var low = 0
            var high = builderOffsets.count
            while low < high {
                let mid = (low + high) / 2
                if builderOffsets[mid] < target { low = mid + 1 } else { high = mid }
            }
            return low
        }

        static func build(from attributed: NSAttributedString) -> AnchorTape {
            let ns = attributed.string as NSString
            let length = ns.length
            var units: [unichar] = []
            var offsets: [Int] = []
            units.reserveCapacity(length)
            offsets.reserveCapacity(length + 1)
            var chars = [unichar](repeating: 0, count: length)
            if length > 0 { ns.getCharacters(&chars, range: NSRange(location: 0, length: length)) }
            var inProseWhitespaceRun = false

            attributed.enumerateAttributes(
                in: NSRange(location: 0, length: length), options: []
            ) { attrs, runRange, _ in
                guard runRange.length > 0 else { return }
                // Attachments (inline math/image/table placeholders) are
                // object-replacement sentinels, not anchor content; the tape is
                // content-addressed text only.
                if attrs[.attachment] != nil { return }
                let isCode = attrs[CodeBlockAttributes.range] != nil
                    || attrs[CodeBlockAttributes.inlineCode] != nil
                for k in 0 ..< runRange.length {
                    let builderOffset = runRange.location + k
                    let unit = chars[builderOffset]
                    if isCode {
                        units.append(unit)
                        offsets.append(builderOffset)
                        inProseWhitespaceRun = false
                    } else if isWhitespace(unit) {
                        if !inProseWhitespaceRun {
                            units.append(0x20)
                            offsets.append(builderOffset)
                            inProseWhitespaceRun = true
                        }
                    } else {
                        units.append(asciiLower(unit))
                        offsets.append(builderOffset)
                        inProseWhitespaceRun = false
                    }
                }
            }
            offsets.append(length)

            let text = units.withUnsafeBufferPointer { buffer -> String in
                guard let base = buffer.baseAddress else { return "" }
                return String(utf16CodeUnits: base, count: buffer.count)
            }
            return AnchorTape(text: text, builderOffsets: offsets)
        }

        private static func isWhitespace(_ unit: unichar) -> Bool {
            switch unit {
            case 0x20, 0x09, 0x0A, 0x0B, 0x0C, 0x0D: true // space, tab, LF, VT, FF, CR
            default: false
            }
        }

        private static func asciiLower(_ unit: unichar) -> unichar {
            (unit >= 0x41 && unit <= 0x5A) ? unit + 0x20 : unit
        }
    }
#endif
