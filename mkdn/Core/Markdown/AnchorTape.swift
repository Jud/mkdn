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
        /// or nil for an empty/out-of-bounds range. The result covers any source
        /// characters collapsed away inside the span (e.g. a whitespace run
        /// rendered as one normalized space).
        func builderRange(forNormalized range: Range<Int>) -> NSRange? {
            guard range.lowerBound >= 0,
                  range.lowerBound < range.upperBound,
                  range.upperBound <= builderOffsets.count - 1
            else { return nil }
            let lo = builderOffsets[range.lowerBound]
            let hi = builderOffsets[range.upperBound]
            return NSRange(location: lo, length: hi - lo)
        }

        static func build(from attributed: NSAttributedString) -> AnchorTape {
            let ns = attributed.string as NSString
            var units: [unichar] = []
            var offsets: [Int] = []
            units.reserveCapacity(ns.length)
            offsets.reserveCapacity(ns.length + 1)
            var inProseWhitespaceRun = false

            attributed.enumerateAttributes(
                in: NSRange(location: 0, length: attributed.length), options: []
            ) { attrs, runRange, _ in
                guard runRange.length > 0 else { return }
                let isCode = attrs[CodeBlockAttributes.range] != nil
                    || attrs[CodeBlockAttributes.inlineCode] != nil
                var buffer = [unichar](repeating: 0, count: runRange.length)
                ns.getCharacters(&buffer, range: runRange)
                for (k, unit) in buffer.enumerated() {
                    let builderOffset = runRange.location + k
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
            offsets.append(attributed.length)

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
