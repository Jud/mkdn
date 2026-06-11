#if os(macOS)
    import AppKit
    @testable import mkdnLib

    /// Lays an attributed string out for real in a TextKit 2 `NSTextView` whose
    /// container matches the markdown preview's config (32pt inset, width =
    /// viewWidth - 64), so height/offset estimates can be checked against the
    /// renderer's ground truth.
    enum LayoutMeasurementHarness {
        /// Returns the laid-out text view (for per-block `boundingRect` queries) and
        /// the text width TextKit used. The window is returned only to keep the view
        /// hierarchy alive for the caller's lifetime.
        @MainActor static func layOut(_ attributed: NSAttributedString, viewWidth: CGFloat)
            -> (textView: CodeBlockBackgroundTextView, window: NSWindow, textWidth: CGFloat) {
            let textContainer = NSTextContainer()
            textContainer.size = NSSize(width: viewWidth - 64, height: .greatestFiniteMagnitude)
            let layoutManager = NSTextLayoutManager()
            layoutManager.textContainer = textContainer
            let contentStorage = NSTextContentStorage()
            contentStorage.addTextLayoutManager(layoutManager)
            let textView = CodeBlockBackgroundTextView(
                frame: NSRect(x: 0, y: 0, width: viewWidth, height: 400),
                textContainer: textContainer
            )
            textView.isVerticallyResizable = true
            textView.textContainerInset = NSSize(width: 32, height: 32)
            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: viewWidth, height: 400))
            scrollView.documentView = textView
            let window = NSWindow(
                contentRect: scrollView.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentView = scrollView
            textView.textStorage?.setAttributedString(attributed)
            window.layoutIfNeeded()
            layoutManager.ensureLayout(for: layoutManager.documentRange)
            let textWidth = textContainer.size.width - 2 * textContainer.lineFragmentPadding
            return (textView, window, textWidth)
        }
    }
#endif
