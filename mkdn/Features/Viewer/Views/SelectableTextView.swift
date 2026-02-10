import AppKit
import SwiftUI

/// `NSViewRepresentable` wrapping a read-only, selectable `NSTextView` backed by
/// TextKit 2 for continuous cross-block text selection in the preview pane.
///
/// The text view displays an `NSAttributedString` produced by
/// ``MarkdownTextStorageBuilder`` and supports native macOS selection behaviors:
/// click-drag, Shift-click, Cmd+A, Cmd+C. Non-text elements (Mermaid diagrams,
/// images) are represented by `NSTextAttachment` placeholders; overlays are
/// positioned by the ``OverlayCoordinator``.
///
/// The ``Coordinator`` owns an ``EntranceAnimator`` that enumerates layout
/// fragments after content is set to apply staggered cover-layer animations.
struct SelectableTextView: NSViewRepresentable {
    let attributedText: NSAttributedString
    let attachments: [AttachmentInfo]
    let theme: AppTheme
    let isFullReload: Bool
    let reduceMotion: Bool
    let appSettings: AppSettings
    let documentState: DocumentState

    // MARK: - NSViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let (scrollView, textView) = Self.makeScrollableCodeBlockTextView()

        Self.configureTextView(textView)
        Self.configureScrollView(scrollView)

        let coordinator = context.coordinator
        coordinator.textView = textView
        coordinator.animator.textView = textView

        applyTheme(to: textView, scrollView: scrollView)

        if isFullReload {
            coordinator.animator.beginEntrance(reduceMotion: reduceMotion)
        }

        textView.textStorage?.setAttributedString(attributedText)
        coordinator.animator.animateVisibleFragments()

        coordinator.overlayCoordinator.updateOverlays(
            attachments: attachments,
            appSettings: appSettings,
            documentState: documentState,
            in: textView
        )
        coordinator.lastAppliedText = attributedText
        RenderCompletionSignal.shared.signalRenderComplete()

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        let coordinator = context.coordinator

        applyTheme(to: textView, scrollView: scrollView)

        let isNewContent = coordinator.lastAppliedText !== attributedText
        if isNewContent {
            if isFullReload {
                coordinator.animator.beginEntrance(reduceMotion: reduceMotion)
            } else {
                coordinator.animator.reset()
            }

            textView.textStorage?.setAttributedString(attributedText)
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            coordinator.animator.animateVisibleFragments()

            coordinator.overlayCoordinator.updateOverlays(
                attachments: attachments,
                appSettings: appSettings,
                documentState: documentState,
                in: textView
            )
            coordinator.lastAppliedText = attributedText
            RenderCompletionSignal.shared.signalRenderComplete()
        }
    }
}

// MARK: - View Configuration

extension SelectableTextView {
    private static func makeScrollableCodeBlockTextView() -> (
        NSScrollView, CodeBlockBackgroundTextView
    ) {
        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true

        let layoutManager = NSTextLayoutManager()
        layoutManager.textContainer = textContainer

        let contentStorage = NSTextContentStorage()
        contentStorage.addTextLayoutManager(layoutManager)

        let textView = CodeBlockBackgroundTextView(
            frame: .zero,
            textContainer: textContainer
        )
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        let scrollView = NSScrollView()
        scrollView.documentView = textView

        return (scrollView, textView)
    }

    private static func configureTextView(_ textView: NSTextView) {
        textView.wantsLayer = true
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.allowsUndo = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.textContainerInset = NSSize(width: 32, height: 32)
        textView.isRichText = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
    }

    private static func configureScrollView(_ scrollView: NSScrollView) {
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
    }

    private func applyTheme(
        to textView: NSTextView,
        scrollView: NSScrollView
    ) {
        let colors = theme.colors
        let bgColor = PlatformTypeConverter.nsColor(from: colors.background)
        let accentColor = PlatformTypeConverter.nsColor(from: colors.accent)
        let fgColor = PlatformTypeConverter.nsColor(from: colors.foreground)

        textView.backgroundColor = bgColor
        scrollView.backgroundColor = bgColor
        scrollView.drawsBackground = true

        textView.selectedTextAttributes = [
            .backgroundColor: accentColor.withAlphaComponent(0.3),
            .foregroundColor: fgColor,
        ]

        textView.insertionPointColor = accentColor
    }
}

// MARK: - Coordinator

extension SelectableTextView {
    @MainActor
    final class Coordinator: NSObject {
        weak var textView: NSTextView?
        let animator = EntranceAnimator()
        let overlayCoordinator = OverlayCoordinator()
        var lastAppliedText: NSAttributedString?
    }
}
