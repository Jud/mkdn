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
            if language == "math" || language == "latex" || language == "tex" {
                return .mathBlock(code: code.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return .codeBlock(language: language, code: code)

        case let blockquote as BlockQuote:
            let children = blockquote.children.compactMap { convertBlock($0) }
            return .blockquote(blocks: children)

        case let orderedList as OrderedList:
            let items = orderedList.children.compactMap { child -> ListItem? in
                guard let listItem = child as? Markdown.ListItem else { return nil }
                let itemBlocks = listItem.children.compactMap { convertBlock($0) }
                let checkboxState = checkboxState(from: listItem)
                return ListItem(blocks: itemBlocks, checkbox: checkboxState)
            }
            return .orderedList(items: items)

        case let unorderedList as UnorderedList:
            let items = unorderedList.children.compactMap { child -> ListItem? in
                guard let listItem = child as? Markdown.ListItem else { return nil }
                let itemBlocks = listItem.children.compactMap { convertBlock($0) }
                let checkboxState = checkboxState(from: listItem)
                return ListItem(blocks: itemBlocks, checkbox: checkboxState)
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

    /// Converts a paragraph, promoting a standalone image child to a block-level image,
    /// or a standalone `$$...$$` paragraph to a block-level math expression.
    private func convertParagraph(_ paragraph: Paragraph) -> MarkdownBlock {
        let children = Array(paragraph.children)
        if children.count == 1, let image = children.first as? Markdown.Image {
            let source = image.source ?? ""
            let alt = plainText(from: image)
            return .image(source: source, alt: alt)
        }

        let rawText = plainText(from: paragraph)
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("$$"), trimmed.hasSuffix("$$"),
           trimmed.count > 4
        {
            let latex = String(trimmed.dropFirst(2).dropLast(2))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !latex.isEmpty {
                return .mathBlock(code: latex)
            }
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
        return postProcessMathDelimiters(result)
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

    // MARK: - Checkbox Extraction

    private func checkboxState(from listItem: Markdown.ListItem) -> CheckboxState? {
        switch listItem.checkbox {
        case .checked: .checked
        case .unchecked: .unchecked
        case nil: nil
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

    // MARK: - Inline Math Detection

    /// Scans the `AttributedString` for `$...$` patterns and marks them
    /// with the `mathExpression` attribute containing the LaTeX source.
    private func postProcessMathDelimiters(
        _ input: AttributedString
    ) -> AttributedString {
        let fullString = String(input.characters)
        guard fullString.contains("$") else { return input }

        let mathRanges = findInlineMathRanges(in: fullString)
        guard !mathRanges.isEmpty else { return input }

        var result = input

        for (range, latex) in mathRanges.reversed() {
            guard let attrRange = attributedStringRange(
                for: range, in: result, fullString: fullString
            )
            else { continue }
            var mathSegment = AttributedString(latex)
            mathSegment.mathExpression = latex
            result.replaceSubrange(attrRange, with: mathSegment)
        }

        return result
    }

    /// Finds valid `$...$` math delimiters following business rules:
    /// - BR-2: `$` followed by whitespace is not a delimiter
    /// - REQ-IDET-2: `\$` is a literal dollar sign
    /// - REQ-IDET-3: `$$` is not an inline delimiter
    /// - REQ-IDET-4: Empty delimiters produce no math
    /// - REQ-IDET-5: Unclosed `$` is literal text
    private func findInlineMathRanges(
        in text: String
    ) -> [(Range<String.Index>, String)] {
        var results: [(Range<String.Index>, String)] = []
        var index = text.startIndex

        while index < text.endIndex {
            let char = text[index]

            if char == "\\" {
                let next = text.index(after: index)
                if next < text.endIndex, text[next] == "$" {
                    index = text.index(after: next)
                    continue
                }
            }

            if char == "$" {
                let next = text.index(after: index)

                if next < text.endIndex, text[next] == "$" {
                    index = text.index(after: next)
                    continue
                }

                if next >= text.endIndex {
                    break
                }

                if text[next].isWhitespace {
                    index = next
                    continue
                }

                if let (closingIndex, latex) = findClosingDollar(in: text, from: next) {
                    let fullRange = index ..< text.index(after: closingIndex)
                    results.append((fullRange, latex))
                    index = text.index(after: closingIndex)
                } else {
                    index = next
                }
            } else {
                index = text.index(after: index)
            }
        }

        return results
    }

    /// Scans forward from `start` looking for a valid closing `$` delimiter.
    /// Returns the index of the closing `$` and the LaTeX content between delimiters,
    /// or nil if no valid closing delimiter is found.
    private func findClosingDollar(
        in text: String,
        from start: String.Index
    ) -> (String.Index, String)? {
        var index = start

        while index < text.endIndex {
            let char = text[index]

            if char == "\\" {
                let next = text.index(after: index)
                if next < text.endIndex, text[next] == "$" {
                    index = text.index(after: next)
                    continue
                }
            }

            if char == "$" {
                let next = text.index(after: index)
                if next < text.endIndex, text[next] == "$" {
                    index = text.index(after: next)
                    continue
                }

                let prev = text.index(before: index)
                if text[prev].isWhitespace {
                    index = text.index(after: index)
                    continue
                }

                let latex = String(text[start ..< index])
                if latex.isEmpty { return nil }
                return (index, latex)
            }

            index = text.index(after: index)
        }

        return nil
    }

    /// Converts a `Range<String.Index>` from the full character string
    /// into the corresponding `Range<AttributedString.Index>`.
    private func attributedStringRange(
        for range: Range<String.Index>,
        in attrStr: AttributedString,
        fullString: String
    ) -> Range<AttributedString.Index>? {
        let startOffset = fullString.distance(
            from: fullString.startIndex, to: range.lowerBound
        )
        let endOffset = fullString.distance(
            from: fullString.startIndex, to: range.upperBound
        )

        let charView = attrStr.characters
        guard startOffset >= 0,
              endOffset <= charView.count,
              startOffset < endOffset
        else {
            return nil
        }

        let attrStart = charView.index(attrStr.startIndex, offsetBy: startOffset)
        let attrEnd = charView.index(attrStr.startIndex, offsetBy: endOffset)
        return attrStart ..< attrEnd
    }
}
