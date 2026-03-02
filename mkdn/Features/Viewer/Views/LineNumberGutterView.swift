#if os(macOS)
    import AppKit

    /// Line number gutter displayed alongside code in CodeFileView.
    ///
    /// A plain NSView that draws right-aligned line numbers by enumerating
    /// the text view's NSLayoutManager line fragments. Positioned as a sibling
    /// to the NSScrollView for explicit layout control and scroll synchronization.
    ///
    /// Uses theme ``ThemeColors/foregroundSecondary`` for numbers,
    /// ``ThemeColors/background`` for the gutter background, and a subtle
    /// right border at ``ThemeColors/border`` with very low opacity.
    final class LineNumberGutterView: NSView {
        // MARK: - Drawing Properties

        var lineNumberColor: NSColor = .secondaryLabelColor
        var gutterBackgroundColor: NSColor = .textBackgroundColor
        var borderColor: NSColor = .separatorColor
        var lineNumberFont: NSFont = .monospacedSystemFont(ofSize: 11, weight: .regular)

        // MARK: - Layout Constants

        static let leftPadding: CGFloat = 8
        static let rightPadding: CGFloat = 6
        static let minimumDigitCount = 2
        private static let borderOpacity: CGFloat = 0.15

        // MARK: - References

        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?

        // MARK: - Init

        override var isFlipped: Bool {
            true
        }

        init() {
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: - Drawing

        override func draw(_ dirtyRect: NSRect) {
            gutterBackgroundColor.setFill()
            bounds.fill()

            borderColor.withAlphaComponent(Self.borderOpacity).setFill()
            NSRect(x: bounds.maxX - 1, y: dirtyRect.minY, width: 1, height: dirtyRect.height).fill()

            guard let textView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer,
                  let scrollView
            else {
                return
            }

            let origin = textView.textContainerOrigin
            let attrs: [NSAttributedString.Key: Any] = [
                .font: lineNumberFont,
                .foregroundColor: lineNumberColor,
            ]

            guard layoutManager.numberOfGlyphs > 0 else {
                drawLineNumber(
                    1,
                    atY: origin.y,
                    lineHeight: lineNumberFont.pointSize * 1.5,
                    attributes: attrs
                )
                return
            }

            let visibleRect = scrollView.contentView.bounds
            let containerRect = visibleRect.offsetBy(dx: -origin.x, dy: -origin.y)
            let visibleGlyphs = layoutManager.glyphRange(
                forBoundingRect: containerRect,
                in: textContainer
            )

            var lineNumber = lineNumberForGlyph(
                at: visibleGlyphs.location,
                layoutManager: layoutManager,
                string: textView.string
            )

            layoutManager.enumerateLineFragments(forGlyphRange: visibleGlyphs) { fragmentRect, _, _, _, _ in
                let y = fragmentRect.minY + origin.y - visibleRect.origin.y
                self.drawLineNumber(
                    lineNumber,
                    atY: y,
                    lineHeight: fragmentRect.height,
                    attributes: attrs
                )
                lineNumber += 1
            }
        }

        // MARK: - Drawing Helpers

        private func drawLineNumber(
            _ number: Int,
            atY yPosition: CGFloat,
            lineHeight: CGFloat,
            attributes: [NSAttributedString.Key: Any]
        ) {
            let label = "\(number)"
            let size = label.size(withAttributes: attributes)
            let x = bounds.maxX - Self.rightPadding - size.width
            let y = yPosition + (lineHeight - size.height) / 2
            label.draw(at: NSPoint(x: x, y: y), withAttributes: attributes)
        }

        private func lineNumberForGlyph(
            at glyphIndex: Int,
            layoutManager: NSLayoutManager,
            string: String
        ) -> Int {
            guard glyphIndex > 0 else { return 1 }

            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            let prefix = string.prefix(charIndex)
            return prefix.count { $0 == "\n" } + 1
        }

        // MARK: - Width Calculation

        /// Calculate the required gutter thickness for a given line count and font.
        static func calculateThickness(lineCount: Int, font: NSFont) -> CGFloat {
            let digitCount = max(String(max(lineCount, 1)).count, minimumDigitCount)
            let sample = String(repeating: "8", count: digitCount)
            let digitWidth = sample.size(withAttributes: [.font: font]).width
            return ceil(leftPadding + digitWidth + rightPadding)
        }

        /// Update the gutter width when the line count changes.
        /// Returns the new thickness so the caller can adjust layout.
        @discardableResult
        func updateThickness(lineCount: Int) -> CGFloat {
            let thickness = Self.calculateThickness(lineCount: lineCount, font: lineNumberFont)
            if abs(frame.width - thickness) > 0.5 {
                frame.size.width = thickness
            }
            return thickness
        }

        /// Update colors and font from theme and zoom settings.
        func updateAppearance(theme: AppTheme, scaleFactor: CGFloat) {
            lineNumberColor = Self.resolveColor(
                PlatformTypeConverter.color(from: theme.colors.foregroundSecondary)
            )
            gutterBackgroundColor = Self.resolveColor(
                PlatformTypeConverter.color(from: theme.colors.background)
            )
            borderColor = Self.resolveColor(
                PlatformTypeConverter.color(from: theme.colors.border)
            )
            lineNumberFont = .monospacedSystemFont(
                ofSize: NSFont.systemFontSize * scaleFactor * 0.85,
                weight: .regular
            )
        }

        /// Convert a potentially dynamic NSColor (from SwiftUI) to a concrete sRGB color.
        private static func resolveColor(_ color: NSColor) -> NSColor {
            color.usingColorSpace(.sRGB) ?? color
        }
    }
#endif
