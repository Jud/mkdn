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
            let text = inlineText(from: paragraph)
            return .paragraph(text: text)

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

        default:
            return nil
        }
    }

    // MARK: - Table Conversion

    private func convertTable(_ table: Markdown.Table) -> MarkdownBlock {
        let headers: [String] = Array(table.head.cells.map { plainText(from: $0) })
        let rows: [[String]] = Array(table.body.rows.map { row in
            Array(row.cells.map { plainText(from: $0) })
        })
        return .table(headers: headers, rows: rows)
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
            result.inlinePresentationIntent = .emphasized
            return result

        case let strong as Strong:
            var result = inlineText(from: strong)
            result.inlinePresentationIntent = .stronglyEmphasized
            return result

        case let code as InlineCode:
            var result = AttributedString(code.code)
            result.inlinePresentationIntent = .code
            return result

        case let link as Markdown.Link:
            var result = inlineText(from: link)
            if let destination = link.destination, let url = URL(string: destination) {
                result.link = url
            }
            return result

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
