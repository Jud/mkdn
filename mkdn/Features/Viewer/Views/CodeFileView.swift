import AppKit
import SwiftUI

/// Full-file code viewer for source code and plain text files.
///
/// Wraps a read-only NSTextView in an NSScrollView with both vertical and
/// horizontal scrolling. Applies tree-sitter syntax highlighting for
/// `.sourceCode` files when the language is supported, falling back to
/// plain monospaced rendering.
///
/// The view re-highlights when theme, zoom, or content changes.
struct CodeFileView: NSViewRepresentable {
    @Environment(DocumentState.self) private var documentState
    @Environment(AppSettings.self) private var appSettings

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        configureTextView(textView)

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        configureScrollView(scrollView)

        let coordinator = context.coordinator
        coordinator.textView = textView

        applyTheme(to: textView, scrollView: scrollView)
        applyContent(to: textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        let coordinator = context.coordinator
        let theme = appSettings.theme
        let scale = appSettings.scaleFactor
        let content = documentState.markdownContent
        let fileKind = documentState.fileKind

        let themeChanged = coordinator.lastTheme != theme
        let scaleChanged = coordinator.lastScale != scale
        let contentChanged = coordinator.lastContent != content
        let kindChanged = coordinator.lastFileKind != fileKind

        if themeChanged || scaleChanged {
            applyTheme(to: textView, scrollView: scrollView)
        }

        if contentChanged || themeChanged || scaleChanged || kindChanged {
            let preserveScroll = !contentChanged && !kindChanged
            let savedOrigin = preserveScroll ? scrollView.contentView.bounds.origin : nil

            applyContent(to: textView)

            if let origin = savedOrigin {
                scrollView.contentView.scroll(to: origin)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }

        coordinator.lastTheme = theme
        coordinator.lastScale = scale
        coordinator.lastContent = content
        coordinator.lastFileKind = fileKind
    }

    // MARK: - Configuration

    private func configureTextView(_ textView: NSTextView) {
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.allowsUndo = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isRichText = true
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false

        textView.textContainerInset = NSSize(width: 32, height: 32)

        // Horizontal scrolling: text view and container must not wrap
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width, .height]
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
    }

    private func configureScrollView(_ scrollView: NSScrollView) {
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
    }

    // MARK: - Theme

    private func applyTheme(to textView: NSTextView, scrollView: NSScrollView) {
        let colors = appSettings.theme.colors
        let bgColor = PlatformTypeConverter.nsColor(from: colors.background)
        let accentColor = PlatformTypeConverter.nsColor(from: colors.accent)

        textView.backgroundColor = bgColor
        scrollView.backgroundColor = bgColor
        scrollView.drawsBackground = true

        textView.selectedTextAttributes = [
            .backgroundColor: accentColor.withAlphaComponent(0.3),
        ]
        textView.insertionPointColor = accentColor
    }

    // MARK: - Content

    private func applyContent(to textView: NSTextView) {
        let theme = appSettings.theme
        let scale = appSettings.scaleFactor
        let content = documentState.markdownContent
        let fileKind = documentState.fileKind
        let font = PlatformTypeConverter.monospacedFont(scaleFactor: scale)

        let attributedString: NSAttributedString

        switch fileKind {
        case let .sourceCode(language):
            if let highlighted = SyntaxHighlightEngine.highlight(
                code: content,
                language: language,
                syntaxColors: theme.syntaxColors
            ) {
                highlighted.addAttribute(
                    .font,
                    value: font,
                    range: NSRange(location: 0, length: highlighted.length)
                )
                let paragraphStyle = makeParagraphStyle(font: font)
                highlighted.addAttribute(
                    .paragraphStyle,
                    value: paragraphStyle,
                    range: NSRange(location: 0, length: highlighted.length)
                )
                attributedString = highlighted
            } else {
                attributedString = makePlainAttributedString(
                    content: content, font: font, theme: theme
                )
            }

        case .plainText, .markdown:
            attributedString = makePlainAttributedString(
                content: content, font: font, theme: theme
            )
        }

        textView.textStorage?.setAttributedString(attributedString)
    }

    private func makePlainAttributedString(
        content: String,
        font: NSFont,
        theme: AppTheme
    ) -> NSAttributedString {
        let foregroundColor = PlatformTypeConverter.nsColor(
            from: theme.colors.foreground
        )
        let paragraphStyle = makeParagraphStyle(font: font)
        return NSAttributedString(
            string: content,
            attributes: [
                .font: font,
                .foregroundColor: foregroundColor,
                .paragraphStyle: paragraphStyle,
            ]
        )
    }

    private func makeParagraphStyle(font: NSFont) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        // Comfortable line spacing for reading code
        style.lineSpacing = font.pointSize * 0.3
        return style
    }
}

// MARK: - Coordinator

extension CodeFileView {
    @MainActor
    final class Coordinator {
        var textView: NSTextView?
        var lastTheme: AppTheme?
        var lastScale: CGFloat?
        var lastContent: String?
        var lastFileKind: FileKind?
    }
}
