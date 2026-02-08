import AppKit
import SwiftUI

/// `NSViewRepresentable` wrapping a read-only, selectable `NSTextView` backed by
/// TextKit 2 for continuous cross-block text selection in the preview pane.
///
/// The text view displays an `NSAttributedString` produced by
/// ``MarkdownTextStorageBuilder`` and supports native macOS selection behaviors:
/// click-drag, Shift-click, Cmd+A, Cmd+C. Non-text elements (Mermaid diagrams,
/// images) are represented by `NSTextAttachment` placeholders; overlays are
/// positioned by the ``OverlayCoordinator`` (T4).
///
/// The ``Coordinator`` implements `NSTextViewportLayoutControllerDelegate` to
/// provide per-layout-fragment animation hooks used by the entrance animator (T5).
struct SelectableTextView: NSViewRepresentable {
    let attributedText: NSAttributedString
    let attachments: [AttachmentInfo]
    let theme: AppTheme
    let isFullReload: Bool
    let reduceMotion: Bool

    // MARK: - NSViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        Self.configureTextView(textView)
        Self.configureScrollView(scrollView)

        let coordinator = context.coordinator
        coordinator.textView = textView
        Self.installViewportDelegate(on: textView, coordinator: coordinator)

        applyTheme(to: textView, scrollView: scrollView)
        textView.textStorage?.setAttributedString(attributedText)

        coordinator.reduceMotion = reduceMotion
        if isFullReload {
            coordinator.beginEntrance()
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        let coordinator = context.coordinator
        coordinator.reduceMotion = reduceMotion

        applyTheme(to: textView, scrollView: scrollView)
        textView.textStorage?.setAttributedString(attributedText)
        textView.setSelectedRange(NSRange(location: 0, length: 0))

        if isFullReload {
            coordinator.beginEntrance()
        }
    }
}

// MARK: - View Configuration

extension SelectableTextView {
    private static func configureTextView(_ textView: NSTextView) {
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.allowsUndo = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.textContainerInset = NSSize(width: 24, height: 24)
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

    private static func installViewportDelegate(
        on textView: NSTextView,
        coordinator: Coordinator
    ) {
        textView.textLayoutManager?
            .textViewportLayoutController.delegate = coordinator
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
    final class Coordinator: NSObject, @preconcurrency NSTextViewportLayoutControllerDelegate {
        weak var textView: NSTextView?
        var isAnimating = false
        var reduceMotion = false
        private var animatedFragments: Set<ObjectIdentifier> = []

        /// Prepares the coordinator for a full document entrance animation.
        func beginEntrance() {
            animatedFragments.removeAll()
            isAnimating = !reduceMotion
        }

        /// Resets animation state, clearing all fragment tracking.
        func reset() {
            animatedFragments.removeAll()
            isAnimating = false
        }

        // MARK: - NSTextViewportLayoutControllerDelegate

        func viewportBounds(
            for _: NSTextViewportLayoutController
        ) -> CGRect {
            guard let scrollView = textView?.enclosingScrollView else {
                return .zero
            }
            return scrollView.contentView.bounds
        }

        func textViewportLayoutController(
            _: NSTextViewportLayoutController,
            configureRenderingSurfaceFor fragment: NSTextLayoutFragment
        ) {
            let fragmentID = ObjectIdentifier(fragment)
            guard !animatedFragments.contains(fragmentID) else { return }
            animatedFragments.insert(fragmentID)

            // Entrance animation hook. The EntranceAnimator (T5) will add
            // per-fragment CALayer opacity and transform animations here.
            // Currently fragments appear with no animation.
        }
    }
}
