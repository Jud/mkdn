import AppKit

/// Line number gutter displayed alongside code in CodeFileView.
///
/// An NSRulerView subclass that draws right-aligned line numbers by enumerating
/// the text view's NSLayoutManager line fragments. Installed as the NSScrollView's
/// vertical ruler view for automatic scroll synchronization.
///
/// Uses theme ``ThemeColors/foregroundSecondary`` at reduced opacity for numbers,
/// ``ThemeColors/background`` for the gutter background, and an optional subtle
/// right border at ``ThemeColors/border`` with very low opacity.
final class LineNumberGutterView: NSRulerView {
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
    private static let numberOpacity: CGFloat = 0.6

    // MARK: - Init

    override var isFlipped: Bool {
        true
    }

    override init(scrollView: NSScrollView?, orientation: NSRulerView.Orientation) {
        super.init(scrollView: scrollView, orientation: orientation)
        ruleThickness = Self.calculateThickness(lineCount: 1, font: lineNumberFont)
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Drawing

    override func drawHashMarksAndLabels(in rect: NSRect) {
        gutterBackgroundColor.setFill()
        rect.fill()

        borderColor.withAlphaComponent(Self.borderOpacity).setFill()
        NSRect(x: bounds.maxX - 1, y: rect.minY, width: 1, height: rect.height).fill()

        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else { return }

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

        guard let scrollView else { return }
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
            let y = fragmentRect.minY + origin.y
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
        return prefix.count(where: { $0 == "\n" }) + 1
    }

    // MARK: - Width Calculation

    /// Calculate the required gutter thickness for a given line count and font.
    static func calculateThickness(lineCount: Int, font: NSFont) -> CGFloat {
        let digitCount = max(String(max(lineCount, 1)).count, minimumDigitCount)
        let sample = String(repeating: "8", count: digitCount)
        let digitWidth = sample.size(withAttributes: [.font: font]).width
        return ceil(leftPadding + digitWidth + rightPadding)
    }

    /// Update the gutter thickness when the line count changes.
    func updateThickness(lineCount: Int) {
        let thickness = Self.calculateThickness(lineCount: lineCount, font: lineNumberFont)
        if abs(ruleThickness - thickness) > 0.5 {
            ruleThickness = thickness
        }
    }

    /// Update colors and font from theme and zoom settings.
    func updateAppearance(theme: AppTheme, scaleFactor: CGFloat) {
        lineNumberColor = PlatformTypeConverter.nsColor(from: theme.colors.foregroundSecondary)
            .withAlphaComponent(Self.numberOpacity)
        gutterBackgroundColor = PlatformTypeConverter.nsColor(from: theme.colors.background)
        borderColor = PlatformTypeConverter.nsColor(from: theme.colors.border)
        lineNumberFont = .monospacedSystemFont(
            ofSize: NSFont.systemFontSize * scaleFactor * 0.85,
            weight: .regular
        )
    }
}
