#if os(iOS)
    import SwiftUI
    import UIKit

    /// `UIViewRepresentable` that wraps a read-only `UITextView` configured with
    /// TextKit 2 for displaying attributed strings produced by the mkdnLib
    /// rendering pipeline on iOS.
    ///
    /// The text view is non-editable and selectable, supporting native iOS text
    /// selection (long-press, drag handles). Link taps are intercepted via the
    /// iOS 17 text item interaction API and routed through the
    /// ``MarkdownInteraction/onLinkTapped`` environment closure.
    ///
    /// - Important: This view never accesses `textView.layoutManager`, which
    ///   would trigger a permanent fallback to TextKit 1. All layout queries
    ///   use `textView.textLayoutManager`.
    struct MarkdownTextViewiOS: UIViewRepresentable {
        let attributedString: NSAttributedString
        let theme: AppTheme

        @Environment(\.markdownInteraction) private var interaction

        // MARK: - UIViewRepresentable

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        func makeUIView(context: Context) -> UITextView {
            let textView = UITextView()
            textView.isEditable = false
            textView.isSelectable = true
            textView.isScrollEnabled = false
            textView.textContainerInset = .zero
            textView.textContainer.lineFragmentPadding = 0
            textView.adjustsFontForContentSizeCategory = false
            textView.dataDetectorTypes = []

            let coordinator = context.coordinator
            coordinator.onLinkTapped = interaction.onLinkTapped
            textView.delegate = coordinator

            applyTheme(to: textView)
            textView.attributedText = attributedString

            return textView
        }

        func updateUIView(_ textView: UITextView, context: Context) {
            let coordinator = context.coordinator
            coordinator.onLinkTapped = interaction.onLinkTapped

            applyTheme(to: textView)

            if textView.attributedText != attributedString {
                textView.attributedText = attributedString
            }
        }

        func sizeThatFits(
            _ proposal: ProposedViewSize,
            uiView textView: UITextView,
            context _: Context
        ) -> CGSize? {
            let width = proposal.width ?? UIScreen.main.bounds.width
            let constraintSize = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            let fittingSize = textView.sizeThatFits(constraintSize)
            return CGSize(width: width, height: fittingSize.height)
        }

        // MARK: - Theme

        private func applyTheme(to textView: UITextView) {
            let colors = theme.colors
            textView.backgroundColor = PlatformTypeConverter.color(from: colors.background)
            textView.tintColor = PlatformTypeConverter.color(from: colors.linkColor)
        }

        // MARK: - Coordinator

        @MainActor
        final class Coordinator: NSObject, UITextViewDelegate {
            var onLinkTapped: ((URL, LinkNavigationHandler.LinkDestination) -> Bool)?

            // MARK: iOS 17 Text Item Interaction

            @available(iOS 17.0, *)
            func textView(
                _: UITextView,
                primaryActionFor textItem: UITextItem,
                defaultAction: UIAction
            ) -> UIAction? {
                guard case let .link(url) = textItem.content else {
                    return defaultAction
                }

                guard let handler = onLinkTapped else {
                    return defaultAction
                }

                return UIAction { _ in
                    let destination = LinkNavigationHandler.classify(url: url, relativeTo: nil)
                    _ = handler(url, destination)
                }
            }

            @available(iOS 17.0, *)
            func textView(
                _: UITextView,
                menuConfigurationFor _: UITextItem,
                defaultMenu: UIMenu
            ) -> UITextItem.MenuConfiguration? {
                UITextItem.MenuConfiguration(menu: defaultMenu)
            }
        }
    }
#endif
