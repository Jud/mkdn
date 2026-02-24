import SwiftUI

/// Renders a single `MarkdownBlock` as a native SwiftUI view.
struct MarkdownBlockView: View {
    let block: MarkdownBlock
    var depth = 0

    @Environment(AppSettings.self) private var appSettings

    private static let bulletStyles: [String] = [
        "\u{2022}", // bullet (level 0)
        "\u{25E6}", // white bullet (level 1)
        "\u{25AA}", // small black square (level 2)
        "\u{25AB}", // small white square (level 3+)
    ]

    private var colors: ThemeColors {
        appSettings.theme.colors
    }

    var body: some View {
        switch block {
        case let .heading(level, text):
            headingView(level: level, text: text)

        case let .paragraph(text):
            Text(text)
                .font(.body)
                .foregroundColor(colors.foreground)
                .tint(colors.linkColor)
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

        case let .table(columns, rows):
            TableBlockView(columns: columns, rows: rows)

        case let .image(source, alt):
            ImageBlockView(source: source, alt: alt)

        case let .htmlBlock(content):
            Text(content)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(colors.codeForeground)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colors.codeBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
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
            .tint(colors.linkColor)
            .textSelection(.enabled)
            .padding(.top, level <= 2 ? 8 : 4)
    }

    // MARK: - Blockquote

    private func blockquoteView(blocks: [MarkdownBlock]) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(colors.blockquoteBorder)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(blocks) { child in
                    Self(block: child, depth: depth)
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 4)
        }
        .padding(.leading, 4)
    }

    // MARK: - Lists

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
                            Self(block: block, depth: depth + 1)
                        }
                    }
                }
            }
        }
        .padding(.leading, 4)
    }

    @ViewBuilder
    private func unorderedListView(items: [ListItem]) -> some View {
        let bulletIndex = min(depth, Self.bulletStyles.count - 1)
        let bullet = Self.bulletStyles[bulletIndex]

        VStack(alignment: .leading, spacing: 4) {
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 8) {
                    if let checkbox = item.checkbox {
                        Image(systemName: checkbox == .checked ? "checkmark.square.fill" : "square")
                            .font(.body)
                            .foregroundColor(colors.foregroundSecondary)
                            .frame(width: 24, alignment: .trailing)
                    } else {
                        Text(bullet)
                            .font(.body)
                            .foregroundColor(colors.foregroundSecondary)
                            .frame(width: 24, alignment: .trailing)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(item.blocks) { block in
                            Self(block: block, depth: depth + 1)
                        }
                    }
                }
            }
        }
        .padding(.leading, 4)
    }
}
