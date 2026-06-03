import Markdown
import SwiftUI

/// Walks a swift-markdown `Document` and produces `MarkdownBlock` elements.
struct MarkdownVisitor {
    let theme: AppTheme
    private var footnoteIndices: [String: Int] = [:]
    private var footnoteDefinitions: [(label: String, blocks: [MarkdownBlock])] = []

    /// The exact source that was parsed, used to attach `SourceSpanAttribute` to
    /// verbatim text runs. When nil (callers that don't need source mapping),
    /// no spans are attached and rendering is unchanged.
    private let source: String?
    private let converter: SourceLocationConverter?

    init(theme: AppTheme, source: String? = nil) {
        self.theme = theme
        self.source = source
        converter = source.map(SourceLocationConverter.init)
    }

    /// Visit the document and return all top-level blocks.
    mutating func visitDocument(_ document: Document) -> [MarkdownBlock] {
        // First pass: collect footnote definitions and assign indices.
        // cmark assigns numeric IDs to references (e.g. [^note] → footnoteID "2"),
        // so we index by both the original label and the 1-based order.
        var definitionOrder = 0
        for child in document.children {
            if let def = child as? FootnoteDefinition {
                definitionOrder += 1
                footnoteIndices[def.footnoteID] = definitionOrder
                footnoteIndices["\(definitionOrder)"] = definitionOrder
                let defBlocks = def.children.compactMap { convertBlock($0) }
                footnoteDefinitions.append((label: def.footnoteID, blocks: defBlocks))
            }
        }

        // Second pass: convert all non-definition blocks
        var result = document.children.compactMap { child -> MarkdownBlock? in
            if child is FootnoteDefinition { return nil }
            return convertBlock(child)
        }

        // Append footnote section at the end
        if !footnoteDefinitions.isEmpty {
            result.append(.thematicBreak)
            let items = footnoteDefinitions.enumerated().map { offset, def in
                let index = offset + 1
                var blocks = def.blocks
                // Prepend back-link to first paragraph in each definition
                if case var .paragraph(text) = blocks.first {
                    var backLink = AttributedString(" ↩")
                    backLink.link = URL(string: "mkdn-footnote:ref-\(index)")
                    text.append(backLink)
                    blocks[0] = .paragraph(text: text)
                }
                return ListItem(blocks: blocks)
            }
            result.append(.orderedList(items: items))
        }

        return result
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

    private func inlineText(from markup: any Markup, protected: Bool = false) -> AttributedString {
        var result = AttributedString()
        for child in markup.children {
            result.append(convertInline(child, protected: protected))
        }
        return postProcessMathDelimiters(result)
    }

    /// - Parameter protected: true when inside a node the CriticMarkup
    ///   preprocessor shields (a link/image), so descendant text must not be
    ///   tagged with a `SourceSpanAttribute` — a selection there is not
    ///   commentable and tagging it would let a wrap corrupt the node.
    private func convertInline(_ markup: any Markup, protected: Bool = false) -> AttributedString {
        switch markup {
        case let text as Markdown.Text:
            var result = AttributedString(text.string)
            if !protected, let span = linearSpan(for: text) {
                result.sourceSpan = span
            }
            return result

        case let emphasis as Emphasis:
            var result = inlineText(from: emphasis, protected: protected)
            for run in result.runs {
                let existing = result[run.range].inlinePresentationIntent ?? []
                result[run.range].inlinePresentationIntent = existing.union(.emphasized)
            }
            return result

        case let strong as Strong:
            var result = inlineText(from: strong, protected: protected)
            for run in result.runs {
                let existing = result[run.range].inlinePresentationIntent ?? []
                result[run.range].inlinePresentationIntent = existing.union(.stronglyEmphasized)
            }
            return result

        case let strikethrough as Strikethrough:
            var result = inlineText(from: strikethrough, protected: protected)
            result.strikethroughStyle = .single
            return result

        case let code as InlineCode:
            var result = AttributedString(code.code)
            result.inlinePresentationIntent = .code
            // The rendered text drops the backticks, so the whole span is atomic:
            // a selection inside snaps to the full `` `code` `` source token.
            if !protected, let span = atomicSpan(for: code) {
                result.sourceSpan = span
            }
            return result

        case let link as Markdown.Link:
            // Suppress per-node spans on the subtree, then tag the whole label as
            // one atomic token covering the full `[text](url)` source — so a
            // selection on link text snaps to the link and a comment over it
            // highlights the whole label.
            var result = inlineText(from: link, protected: true)
            if let destination = link.destination, let url = URL(string: destination) {
                result.link = url
                result.underlineStyle = .single
            }
            if !protected, let span = atomicSpan(for: link) {
                result.sourceSpan = span
            }
            return result

        case let image as Markdown.Image:
            let alt = plainText(from: image)
            return AttributedString(alt)

        case let footnoteRef as FootnoteReference:
            let index = footnoteIndices[footnoteRef.footnoteID] ?? 0
            var result = AttributedString("[\(index)]")
            result.link = URL(string: "mkdn-footnote:def-\(index)")
            #if os(macOS)
                result.appKit.superscript = 1
            #endif
            return result

        case is SoftBreak:
            return AttributedString(" ")

        case is LineBreak:
            return AttributedString("\n")

        default:
            return inlineText(from: markup, protected: protected)
        }
    }

    /// A 1:1 `SourceSpan` for a text node whose rendered string is a verbatim
    /// copy of its source substring. Returns nil otherwise (escapes, entities —
    /// not 1:1 mappable).
    ///
    /// Text containing `$` is also skipped: `postProcessMathDelimiters` may later
    /// replace an inline `$…$` span, which would leave a stale offset on the
    /// text after it. Dropping the whole run keeps the mapping correct at the
    /// cost of not being able to comment on `$`-bearing prose (a safe v1 trade).
    private func linearSpan(for text: Markdown.Text) -> SourceSpan? {
        guard let source, let converter,
              !text.string.contains("$"),
              let sourceRange = text.range,
              let resolved = converter.range(for: sourceRange),
              source[resolved] == text.string
        else {
            return nil
        }
        return span(for: resolved, in: source)
    }

    /// An atomic `SourceSpan` covering a whole token's source (e.g. a link or
    /// inline code), so a selection inside snaps to the full token.
    private func atomicSpan(for markup: any Markup) -> SourceSpan? {
        guard let source, let converter,
              let sourceRange = markup.range,
              let resolved = converter.range(for: sourceRange)
        else {
            return nil
        }
        return span(for: resolved, in: source)
    }

    private func span(for resolved: Range<String.Index>, in source: String) -> SourceSpan {
        let nsRange = NSRange(resolved, in: source)
        return SourceSpan(start: nsRange.location, end: nsRange.location + nsRange.length)
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
