import AppKit
import SwiftUI

/// Full-file code viewer for source code and plain text files.
///
/// Wraps a read-only NSTextView in an NSScrollView with both vertical and
/// horizontal scrolling. Applies tree-sitter syntax highlighting for
/// `.sourceCode` files when the language is supported, falling back to
/// plain monospaced rendering.
///
/// A line number gutter is displayed alongside the code using a sibling NSView
/// with scroll-synchronized positioning.
///
/// The view re-highlights when theme, zoom, or content changes.
struct CodeFileView: NSViewRepresentable {
    @Environment(DocumentState.self) private var documentState
    @Environment(AppSettings.self) private var appSettings

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let textView = NSTextView()
        configureTextView(textView)

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        configureScrollView(scrollView)

        let gutter = LineNumberGutterView()
        gutter.textView = textView
        gutter.scrollView = scrollView

        let container = CodeContainerView(gutter: gutter, scrollView: scrollView)

        let coordinator = context.coordinator
        coordinator.textView = textView
        coordinator.scrollView = scrollView
        coordinator.gutter = gutter
        coordinator.container = container

        applyTheme(to: textView, scrollView: scrollView)
        applyContent(to: textView)
        updateGutter(gutter, textView: textView, container: container)

        // Observe scroll changes to keep gutter in sync
        coordinator.scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak gutter] _ in
            MainActor.assumeIsolated {
                gutter?.needsDisplay = true
            }
        }
        scrollView.contentView.postsBoundsChangedNotifications = true

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let coordinator = context.coordinator
        guard let textView = coordinator.textView,
              let scrollView = coordinator.scrollView,
              let gutter = coordinator.gutter,
              let container = coordinator.container
        else { return }

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

        if themeChanged || scaleChanged {
            gutter.updateAppearance(
                theme: theme,
                scaleFactor: scale
            )
        }
        if contentChanged || themeChanged || scaleChanged || kindChanged {
            updateGutter(gutter, textView: textView, container: container)
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

        textView.textContainerInset = NSSize(width: 8, height: 32)

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

    // MARK: - Gutter

    private func updateGutter(
        _ gutter: LineNumberGutterView,
        textView: NSTextView,
        container: CodeContainerView
    ) {
        gutter.updateAppearance(
            theme: appSettings.theme,
            scaleFactor: appSettings.scaleFactor
        )
        let lineCount = textView.string.components(separatedBy: "\n").count
        let thickness = gutter.updateThickness(lineCount: lineCount)
        container.gutterWidth = thickness
        container.needsLayout = true
        gutter.needsDisplay = true
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

// MARK: - CodeContainerView

/// Container that positions the gutter and scroll view side by side.
final class CodeContainerView: NSView {
    let gutter: LineNumberGutterView
    let scrollView: NSScrollView
    var gutterWidth: CGFloat = 35

    override var isFlipped: Bool {
        true
    }

    init(gutter: LineNumberGutterView, scrollView: NSScrollView) {
        self.gutter = gutter
        self.scrollView = scrollView
        super.init(frame: .zero)
        addSubview(gutter)
        addSubview(scrollView)
        autoresizingMask = [.width, .height]
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let w = gutterWidth
        gutter.frame = NSRect(x: 0, y: 0, width: w, height: bounds.height)
        scrollView.frame = NSRect(x: w, y: 0, width: bounds.width - w, height: bounds.height)
    }
}

// MARK: - Coordinator

extension CodeFileView {
    @MainActor
    final class Coordinator {
        var textView: NSTextView?
        var scrollView: NSScrollView?
        var gutter: LineNumberGutterView?
        var container: CodeContainerView?
        nonisolated(unsafe) var scrollObserver: Any?
        var lastTheme: AppTheme?
        var lastScale: CGFloat?
        var lastContent: String?
        var lastFileKind: FileKind?

        deinit {
            if let obs = scrollObserver {
                NotificationCenter.default.removeObserver(obs)
            }
        }
    }
}
