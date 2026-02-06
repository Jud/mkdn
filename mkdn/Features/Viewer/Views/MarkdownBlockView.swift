import SwiftUI

/// Renders a single `MarkdownBlock` as a native SwiftUI view.
struct MarkdownBlockView: View {
    let block: MarkdownBlock

    @Environment(AppState.self) private var appState

    private var colors: ThemeColors {
        appState.theme.colors
    }

    var body: some View {
        switch block {
        case let .heading(level, text):
            headingView(level: level, text: text)

        case let .paragraph(text):
            Text(text)
                .font(.body)
                .foregroundColor(colors.foreground)
                .textSelection(.enabled)

        case let .codeBlock(language, code):
            CodeBlockView(language: language, code: code)

        case let .mermaidBlock(code):
            MermaidBlockView(code: code)

        case let .blockquote(blocks):
            blockquoteView(blocks: blocks)

        case let .orderedList(items):
            orderedListView(items: items)

        case let .unorderedList(items):
            unorderedListView(items: items)

        case .thematicBreak:
            Divider()
                .background(colors.border)
                .padding(.vertical, 8)

        case let .table(headers, rows):
            TableBlockView(headers: headers, rows: rows)
        }
    }

    // MARK: - Heading

    @ViewBuilder
    private func headingView(level: Int, text: AttributedString) -> some View {
        let font: Font = switch level {
        case 1: .system(size: 28, weight: .bold)
        case 2: .system(size: 24, weight: .bold)
        case 3: .system(size: 20, weight: .semibold)
        case 4: .system(size: 18, weight: .semibold)
        case 5: .system(size: 16, weight: .medium)
        default: .system(size: 14, weight: .medium)
        }

        Text(text)
            .font(font)
            .foregroundColor(colors.headingColor)
            .textSelection(.enabled)
            .padding(.top, level <= 2 ? 8 : 4)
    }

    // MARK: - Blockquote

    @ViewBuilder
    private func blockquoteView(blocks: [MarkdownBlock]) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(colors.blockquoteBorder)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(blocks) { child in
                    MarkdownBlockView(block: child)
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 4)
        }
        .padding(.leading, 4)
    }

    // MARK: - Lists

    @ViewBuilder
    private func orderedListView(items: [ListItem]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.body.monospacedDigit())
                        .foregroundColor(colors.foregroundSecondary)
                        .frame(width: 24, alignment: .trailing)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(item.blocks) { block in
                            MarkdownBlockView(block: block)
                        }
                    }
                }
            }
        }
        .padding(.leading, 4)
    }

    @ViewBuilder
    private func unorderedListView(items: [ListItem]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("\u{2022}")
                        .font(.body)
                        .foregroundColor(colors.foregroundSecondary)
                        .frame(width: 24, alignment: .trailing)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(item.blocks) { block in
                            MarkdownBlockView(block: block)
                        }
                    }
                }
            }
        }
        .padding(.leading, 4)
    }
}
