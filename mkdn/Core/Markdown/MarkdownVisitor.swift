import Markdown
import SwiftUI

/// Walks a swift-markdown `Document` and produces `MarkdownBlock` elements.
struct MarkdownVisitor {
    let theme: AppTheme

    /// Visit the document and return all top-level blocks.
    func visitDocument(_ document: Document) -> [MarkdownBlock] {
        document.children.compactMap { convertBlock($0) }
    }

    // MARK: - Block Conversion

    private func convertBlock(_ markup: any Markup) -> MarkdownBlock? {
        switch markup {
        case let heading as Heading:
            let text = inlineText(from: heading)
            return .heading(level: heading.level, text: text)

        case let paragraph as Paragraph:
            return convertParagraph(paragraph)

        case let codeBlock as CodeBlock:
            let language = codeBlock.language?.lowercased()
            let code = codeBlock.code

            if language == "mermaid" {
                return .mermaidBlock(code: code)
            }
            return .codeBlock(language: language, code: code)

        case let blockquote as BlockQuote:
            let children = blockquote.children.compactMap { convertBlock($0) }
            return .blockquote(blocks: children)

        case let orderedList as OrderedList:
            let items = orderedList.children.compactMap { child -> ListItem? in
                guard let listItem = child as? Markdown.ListItem else { return nil }
                let itemBlocks = listItem.children.compactMap { convertBlock($0) }
                return ListItem(blocks: itemBlocks)
            }
            return .orderedList(items: items)

        case let unorderedList as UnorderedList:
            let items = unorderedList.children.compactMap { child -> ListItem? in
                guard let listItem = child as? Markdown.ListItem else { return nil }
                let itemBlocks = listItem.children.compactMap { convertBlock($0) }
                return ListItem(blocks: itemBlocks)
            }
            return .unorderedList(items: items)

        case is ThematicBreak:
            return .thematicBreak

        case let table as Markdown.Table:
            return convertTable(table)

        case let htmlBlock as HTMLBlock:
            return .htmlBlock(content: htmlBlock.rawHTML)

        default:
            return nil
        }
    }

    // MARK: - Paragraph Conversion

    /// Converts a paragraph, promoting a standalone image child to a block-level image.
    private func convertParagraph(_ paragraph: Paragraph) -> MarkdownBlock {
        let children = Array(paragraph.children)
        if children.count == 1, let image = children.first as? Markdown.Image {
            let source = image.source ?? ""
            let alt = plainText(from: image)
            return .image(source: source, alt: alt)
        }
        let text = inlineText(from: paragraph)
        return .paragraph(text: text)
    }

    // MARK: - Table Conversion

    private func convertTable(_ table: Markdown.Table) -> MarkdownBlock {
        let columns: [TableColumn] = table.head.cells.enumerated().map { index, cell in
            let alignment: TableColumnAlignment = if index < table.columnAlignments.count {
                switch table.columnAlignments[index] {
                case .center: .center
                case .right: .right
                default: .left
                }
            } else {
                .left
            }
            return TableColumn(header: inlineText(from: cell), alignment: alignment)
        }
        let rows: [[AttributedString]] = table.body.rows.map { row in
            row.cells.map { inlineText(from: $0) }
        }
        return .table(columns: columns, rows: rows)
    }

    // MARK: - Inline Text

    private func inlineText(from markup: any Markup) -> AttributedString {
        var result = AttributedString()
        for child in markup.children {
            result.append(convertInline(child))
        }
        return result
    }

    private func convertInline(_ markup: any Markup) -> AttributedString {
        switch markup {
        case let text as Markdown.Text:
            return AttributedString(text.string)

        case let emphasis as Emphasis:
            var result = inlineText(from: emphasis)
            for run in result.runs {
                let existing = result[run.range].inlinePresentationIntent ?? []
                result[run.range].inlinePresentationIntent = existing.union(.emphasized)
            }
            return result

        case let strong as Strong:
            var result = inlineText(from: strong)
            for run in result.runs {
                let existing = result[run.range].inlinePresentationIntent ?? []
                result[run.range].inlinePresentationIntent = existing.union(.stronglyEmphasized)
            }
            return result

        case let strikethrough as Strikethrough:
            var result = inlineText(from: strikethrough)
            result.strikethroughStyle = .single
            return result

        case let code as InlineCode:
            var result = AttributedString(code.code)
            result.inlinePresentationIntent = .code
            return result

        case let link as Markdown.Link:
            var result = inlineText(from: link)
            if let destination = link.destination, let url = URL(string: destination) {
                result.link = url
                result.foregroundColor = theme.colors.linkColor
                result.underlineStyle = .single
            }
            return result

        case let image as Markdown.Image:
            let alt = plainText(from: image)
            return AttributedString(alt)

        case is SoftBreak:
            return AttributedString(" ")

        case is LineBreak:
            return AttributedString("\n")

        default:
            return inlineText(from: markup)
        }
    }

    private func plainText(from markup: any Markup) -> String {
        var result = ""
        for child in markup.children {
            if let text = child as? Markdown.Text {
                result += text.string
            } else {
                result += plainText(from: child)
            }
        }
        return result
    }
}
