import AppKit

/// Inline math rendering for `MarkdownTextStorageBuilder`.
///
/// Detects the `mathExpression` attribute on `AttributedString` runs
/// and renders them as `NSTextAttachment` images with baseline alignment,
/// falling back to styled monospace text on parse failure.
extension MarkdownTextStorageBuilder {
    /// Checks if an `AttributedString` run contains a math expression and
    /// renders it to an `NSTextAttachment` image. Returns nil if the run
    /// is not a math expression.
    static func renderInlineMath(
        from run: AttributedString.Runs.Run,
        content: AttributedString,
        baseFont: NSFont,
        baseForegroundColor: NSColor,
        scaleFactor: CGFloat
    ) -> NSAttributedString? {
        guard let latex = content[run.range].mathExpression else {
            return nil
        }

        if let result = MathRenderer.renderToImage(
            latex: latex,
            fontSize: baseFont.pointSize,
            textColor: baseForegroundColor,
            displayMode: false
        ) {
            let attachment = NSTextAttachment()
            attachment.image = result.image

            let height = result.image.size.height
            let width = result.image.size.width
            let yOffset = -(result.baseline)
            attachment.bounds = CGRect(
                x: 0,
                y: yOffset,
                width: width,
                height: height
            )

            return NSAttributedString(attachment: attachment)
        }

        let monoFont = PlatformTypeConverter.monospacedFont(scaleFactor: scaleFactor)
        let secondaryColor = baseForegroundColor.withAlphaComponent(0.6)
        return NSAttributedString(
            string: latex,
            attributes: [
                .font: monoFont,
                .foregroundColor: secondaryColor,
            ]
        )
    }
}
