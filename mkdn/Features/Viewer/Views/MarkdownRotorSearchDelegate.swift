#if os(macOS)
    import AppKit

    /// A heading's place in the rendered text, backing the VoiceOver headings
    /// rotor.
    struct RotorHeading {
        let title: String
        let level: Int
        let range: NSRange
    }

    /// Resolves rotor searches against the text view's current content. One
    /// delegate serves all three rotors, dispatching on the rotor's type.
    @MainActor
    final class MarkdownRotorSearchDelegate: NSObject,
        @preconcurrency NSAccessibilityCustomRotorItemSearchDelegate {
        weak var textView: CodeBlockBackgroundTextView?

        struct Item {
            let label: String
            let range: NSRange
        }

        func rotor(
            _ rotor: NSAccessibilityCustomRotor,
            resultFor searchParameters: NSAccessibilityCustomRotor.SearchParameters
        ) -> NSAccessibilityCustomRotor.ItemResult? {
            guard let textView else { return nil }
            var matches = items(for: rotor, in: textView)
            let filter = searchParameters.filterString
            if !filter.isEmpty {
                matches = matches.filter { $0.label.localizedCaseInsensitiveContains(filter) }
            }
            let current = searchParameters.currentItem?.targetRange
            let found: Item? = switch searchParameters.searchDirection {
            case .next:
                if let current, current.location != NSNotFound {
                    matches.first { $0.range.location > current.location }
                } else {
                    matches.first
                }
            case .previous:
                if let current, current.location != NSNotFound {
                    matches.last { $0.range.location < current.location }
                } else {
                    matches.last
                }
            @unknown default:
                nil
            }
            guard let found else { return nil }
            let result = NSAccessibilityCustomRotor.ItemResult(targetElement: textView)
            result.targetRange = found.range
            result.customLabel = found.label
            return result
        }

        func items(
            for rotor: NSAccessibilityCustomRotor,
            in textView: CodeBlockBackgroundTextView
        ) -> [Item] {
            let items = switch rotor.type {
            case .heading: headingItems(textView)
            case .link: linkItems(textView)
            default: commentItems(textView)
            }
            return items.sorted { $0.range.location < $1.range.location }
        }

        private func headingItems(_ textView: CodeBlockBackgroundTextView) -> [Item] {
            textView.rotorHeadings.map { Item(label: $0.title, range: $0.range) }
        }

        private func linkItems(_ textView: CodeBlockBackgroundTextView) -> [Item] {
            guard let storage = textView.textStorage else { return [] }
            var items: [Item] = []
            storage.enumerateAttribute(
                .link, in: NSRange(location: 0, length: storage.length)
            ) { value, range, _ in
                guard value != nil else { return }
                // swiftlint:disable:next legacy_objc_type
                let text = (storage.string as NSString).substring(with: range)
                items.append(Item(label: text, range: range))
            }
            return items
        }

        private func commentItems(_ textView: CodeBlockBackgroundTextView) -> [Item] {
            (textView.resolvedComments?.active ?? []).map { comment in
                Item(
                    label: comment.entry.quote.isEmpty ? "Comment" : comment.entry.quote,
                    range: comment.range
                )
            }
        }
    }
#endif
