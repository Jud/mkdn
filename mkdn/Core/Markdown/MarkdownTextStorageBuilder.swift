#if os(macOS)
    import AppKit
#else
    import UIKit
#endif
import SwiftUI

/// Information about a non-text attachment placeholder in the attributed string.
public struct AttachmentInfo {
    public let blockIndex: Int
    public let block: MarkdownBlock
    public let attachment: NSTextAttachment
}

/// Result of converting `[IndexedBlock]` to an `NSAttributedString`.
public struct TextStorageResult {
    public let attributedString: NSAttributedString
    public let attachments: [AttachmentInfo]

    /// Maps heading block indices to their character offsets in the attributed string.
    public let headingOffsets: [Int: Int]

    /// Per-block spans for mapping document y-positions to blocks (and back).
    public let documentHeightModel: DocumentHeightModel

    /// Maps built attributed-string ranges back to source offsets.
    let sourceMap: SourceMap

    init(
        attributedString: NSAttributedString,
        attachments: [AttachmentInfo],
        headingOffsets: [Int: Int] = [:],
        documentHeightModel: DocumentHeightModel = DocumentHeightModel(blocks: []),
        sourceMap: SourceMap = SourceMap(segments: [])
    ) {
        self.attributedString = attributedString
        self.attachments = attachments
        self.headingOffsets = headingOffsets
        self.documentHeightModel = documentHeightModel
        self.sourceMap = sourceMap
    }
}

/// Resolved platform color values from a ThemeColors palette for text storage building.
struct ResolvedColors {
    let foreground: PlatformTypeConverter.PlatformColor
    let headingColor: PlatformTypeConverter.PlatformColor
    let secondaryColor: PlatformTypeConverter.PlatformColor
    let linkColor: PlatformTypeConverter.PlatformColor

    init(colors: ThemeColors) {
        foreground = PlatformTypeConverter.color(from: colors.foreground)
        headingColor = PlatformTypeConverter.color(from: colors.headingColor)
        secondaryColor = PlatformTypeConverter.color(from: colors.foregroundSecondary)
        linkColor = PlatformTypeConverter.color(from: colors.linkColor)
    }
}

/// Context for recursive list/blockquote rendering.
struct BlockBuildContext {
    let colors: ThemeColors
    let syntaxColors: SyntaxColors
    let resolved: ResolvedColors
    let scaleFactor: CGFloat

    init(colors: ThemeColors, syntaxColors: SyntaxColors, scaleFactor: CGFloat = 1.0) {
        self.colors = colors
        self.syntaxColors = syntaxColors
        self.scaleFactor = scaleFactor
        resolved = ResolvedColors(colors: colors)
    }
}

/// Converts an array of `IndexedBlock` into a single `NSAttributedString`
/// suitable for display in an `NSTextView`, plus a mapping of attachment
/// positions to their source block data.
@MainActor
public enum MarkdownTextStorageBuilder {
    // MARK: - Constants

    // Vertical rhythm sits on a 4pt grid: 4 within an item, 8 within a group,
    // 12 between paragraphs, 16 between blocks, 24 before headings.
    static let blockSpacing: CGFloat = 16
    static let lineSpacing: CGFloat = 2
    static let paragraphBottomMargin: CGFloat = 12
    /// GitHub's CSS uses uniform 1.5rem (24px) top-margin for h1-h6;
    /// per-level prominence comes from font size alone.
    static let headingTopMargin: CGFloat = 24
    static let codeBlockPadding: CGFloat = 12
    static let codeBlockTopPaddingWithLabel: CGFloat = 8
    static let codeLabelSpacing: CGFloat = 4
    static let listItemSpacing: CGFloat = 4
    static let listPrefixWidth: CGFloat = 32
    static let listLeftPadding: CGFloat = 4
    static let blockquoteIndent: CGFloat = 16
    /// On the 4pt grid: bar 0–4, then a 12pt gutter to the text at 16.
    static let blockquoteBarWidth: CGFloat = 4
    static let attachmentPlaceholderHeight: CGFloat = 100
    static let thematicBreakHeight: CGFloat = 17

    /// One quiet glyph per nesting tier — disc, then ring for all deeper levels.
    static let bulletStyles: [String] = [
        "\u{2022}",
        "\u{25E6}",
    ]

    // MARK: - Public API

    public static func build(
        blocks: [IndexedBlock],
        theme: AppTheme,
        scaleFactor: CGFloat = 1.0,
        isPrint: Bool = false,
        appSettings: AppSettings? = nil
    ) -> TextStorageResult {
        build(
            blocks: blocks,
            colors: theme.colors,
            syntaxColors: theme.syntaxColors,
            scaleFactor: scaleFactor,
            isPrint: isPrint,
            appSettings: appSettings
        )
    }

    public static func build(
        blocks: [IndexedBlock],
        colors: ThemeColors,
        syntaxColors: SyntaxColors,
        scaleFactor: CGFloat = 1.0,
        isPrint: Bool = false,
        appSettings: AppSettings? = nil
    ) -> TextStorageResult {
        let session = ProgressiveTextStorageBuild(
            blocks: blocks,
            colors: colors,
            syntaxColors: syntaxColors,
            scaleFactor: scaleFactor,
            isPrint: isPrint,
            appSettings: appSettings
        )
        session.buildRemaining()
        return session.result()
    }

    // MARK: - Block Dispatch

    // swiftlint:disable:next function_parameter_count function_body_length
    static func appendBlock(
        _ indexedBlock: IndexedBlock,
        to result: NSMutableAttributedString,
        colors: ThemeColors,
        syntaxColors: SyntaxColors,
        scaleFactor: CGFloat,
        attachments: inout [AttachmentInfo],
        isPrint: Bool,
        appSettings: AppSettings?
    ) {
        let sf = scaleFactor
        let block = indexedBlock.block
        switch block {
        case let .heading(level, text):
            appendHeading(
                to: result,
                level: level,
                text: text,
                colors: colors,
                scaleFactor: sf
            )
        case let .paragraph(text):
            appendParagraph(to: result, text: text, colors: colors, scaleFactor: sf)
        case let .codeBlock(lang, code):
            appendCodeBlock(
                to: result,
                language: lang,
                code: code,
                colors: colors,
                syntaxColors: syntaxColors,
                scaleFactor: sf
            )
        case .mermaidBlock, .image:
            appendAttachmentPlaceholder(indexedBlock, to: result, attachments: &attachments)
        case let .mathBlock(code):
            if isPrint {
                appendMathBlockInline(
                    to: result, code: code, colors: colors, scaleFactor: sf
                )
            } else {
                // Size the placeholder by typesetting the equation now (math
                // doesn't wrap, so its height is width-independent). The
                // overlay's later height report then matches and no layout
                // shifts under the reader after first paint.
                appendAttachmentBlock(
                    to: result,
                    blockIndex: indexedBlock.index,
                    block: block,
                    height: MathRenderer.displayBlockHeight(
                        latex: code,
                        scaleFactor: sf,
                        textColor: PlatformTypeConverter.color(from: colors.foreground)
                    ),
                    attachments: &attachments
                )
            }
        case let .blockquote(blocks):
            appendBlockquote(
                to: result,
                blocks: blocks,
                colors: colors,
                syntaxColors: syntaxColors,
                depth: 0,
                scaleFactor: sf
            )
        case let .orderedList(items):
            appendOrderedList(
                to: result,
                items: items,
                colors: colors,
                syntaxColors: syntaxColors,
                depth: 0,
                scaleFactor: sf
            )
        case let .unorderedList(items):
            appendUnorderedList(
                to: result,
                items: items,
                colors: colors,
                syntaxColors: syntaxColors,
                depth: 0,
                scaleFactor: sf
            )
        case .thematicBreak:
            appendAttachmentPlaceholder(indexedBlock, to: result, attachments: &attachments)
        case let .table(columns, rows):
            if isPrint {
                appendTablePrintText(
                    to: result,
                    columns: columns,
                    rows: rows,
                    colors: colors,
                    scaleFactor: sf
                )
            } else {
                appendTableAttachment(
                    to: result,
                    blockIndex: indexedBlock.index,
                    block: block,
                    columns: columns,
                    rows: rows,
                    attachments: &attachments,
                    appSettings: appSettings
                )
            }
        case let .htmlBlock(content):
            appendHTMLBlock(to: result, content: content, colors: colors, scaleFactor: sf)
        }
    }

    private static func appendAttachmentPlaceholder(
        _ indexedBlock: IndexedBlock,
        to result: NSMutableAttributedString,
        attachments: inout [AttachmentInfo]
    ) {
        let height: CGFloat = switch indexedBlock.block {
        case .thematicBreak: thematicBreakHeight
        default: attachmentPlaceholderHeight
        }
        appendAttachmentBlock(
            to: result,
            blockIndex: indexedBlock.index,
            block: indexedBlock.block,
            height: height,
            attachments: &attachments
        )
    }

    // MARK: - Table Height Estimation

    static let defaultEstimationContainerWidth: CGFloat = 600

    // MARK: - Inline Content Conversion

    static func convertInlineContent(
        _ content: AttributedString,
        baseFont: PlatformTypeConverter.PlatformFont,
        baseForegroundColor: PlatformTypeConverter.PlatformColor,
        linkColor: PlatformTypeConverter.PlatformColor,
        scaleFactor: CGFloat = 1.0
    ) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()

        for run in content.runs {
            if let mathResult = renderInlineMath(
                from: run,
                content: content,
                baseFont: baseFont,
                baseForegroundColor: baseForegroundColor,
                scaleFactor: scaleFactor
            ) {
                result.append(mathResult)
                continue
            }

            let text = String(content[run.range].characters)
            // No .mkdnSourceSpan here: nothing reads it from the built string
            // (AnchorTape anchors by content), and a per-run-unique value makes
            // every attribute dictionary distinct — AppKit's global attribute-
            // dictionary uniquing table then grows O(runs) and every
            // addAttribute degrades to O(table) rehash probing.
            var attributes: [NSAttributedString.Key: Any] = [:]

            let intent = run.inlinePresentationIntent ?? []
            var font = baseFont

            if intent.contains(.code) {
                font = PlatformTypeConverter.monospacedFont(scaleFactor: scaleFactor)
                attributes[CodeBlockAttributes.inlineCode] = true
            } else {
                let isBold = intent.contains(.stronglyEmphasized)
                let isItalic = intent.contains(.emphasized)
                if isBold || isItalic {
                    var traits: PlatformTypeConverter.FontTrait = []
                    if isBold { traits.insert(.bold) }
                    if isItalic { traits.insert(.italic) }
                    font = PlatformTypeConverter.convertFont(font, toHaveTrait: traits)
                }
            }
            attributes[.font] = font

            var foreground = baseForegroundColor
            if let link = run.link {
                foreground = linkColor
                attributes[.link] = link
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            attributes[.foregroundColor] = foreground

            if run.strikethroughStyle != nil {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }

            #if os(macOS)
                if run.appKit.superscript != nil {
                    let smallerSize = font.pointSize * 0.7
                    attributes[.font] = NSFont.systemFont(ofSize: smallerSize, weight: .medium)
                    attributes[.foregroundColor] = linkColor
                    attributes.removeValue(forKey: .underlineStyle)
                }
            #endif

            result.append(NSAttributedString(string: text, attributes: attributes))
        }

        return result
    }

    // MARK: - Syntax Highlighting

    static func highlightCode(
        _ code: String,
        language: String,
        syntaxColors: SyntaxColors
    ) -> NSMutableAttributedString? {
        SyntaxHighlightEngine.highlight(
            code: code,
            language: language,
            syntaxColors: syntaxColors
        )
    }

    // MARK: - Paragraph Style Helpers

    static func makeParagraphStyle(
        lineSpacing: CGFloat = Self.lineSpacing,
        paragraphSpacing: CGFloat = 0,
        paragraphSpacingBefore: CGFloat = 0,
        headIndent: CGFloat = 0,
        firstLineHeadIndent: CGFloat = 0,
        tailIndent: CGFloat = 0,
        alignment: NSTextAlignment = .left,
        tabStops: [NSTextTab] = []
    ) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.paragraphSpacing = paragraphSpacing
        style.paragraphSpacingBefore = paragraphSpacingBefore
        style.headIndent = headIndent
        style.firstLineHeadIndent = firstLineHeadIndent
        style.tailIndent = tailIndent
        style.alignment = alignment
        if !tabStops.isEmpty {
            style.tabStops = tabStops
        }
        return style
    }

    static func terminator(with style: NSParagraphStyle) -> NSAttributedString {
        NSAttributedString(string: "\n", attributes: [.paragraphStyle: style])
    }

    static func setLastParagraphSpacing(
        _ attrStr: NSMutableAttributedString,
        spacing: CGFloat,
        baseStyle: NSParagraphStyle? = nil
    ) {
        guard attrStr.length > 0 else { return }
        let nsString = attrStr.string as NSString // swiftlint:disable:this legacy_objc_type
        let lastCharLoc = nsString.length - 1
        let lastParaRange = nsString.paragraphRange(
            for: NSRange(location: lastCharLoc, length: 0)
        )

        let existing: NSParagraphStyle = if let base = baseStyle {
            base
        } else if let found = attrStr.attribute(
            .paragraphStyle,
            at: lastParaRange.location,
            effectiveRange: nil
        ) as? NSParagraphStyle {
            found
        } else {
            .default
        }

        // swiftlint:disable:next force_cast
        let mutable = existing.mutableCopy() as! NSMutableParagraphStyle
        mutable.paragraphSpacing = spacing
        attrStr.addAttribute(.paragraphStyle, value: mutable, range: lastParaRange)
    }

    public static func plainText(from block: MarkdownBlock) -> String {
        switch block {
        case let .heading(_, text):
            return String(text.characters)
        case let .paragraph(text):
            return String(text.characters)
        case let .codeBlock(_, code):
            return code.trimmingCharacters(in: .whitespacesAndNewlines)
        case let .mermaidBlock(code):
            return code.trimmingCharacters(in: .whitespacesAndNewlines)
        case let .mathBlock(code):
            return code.trimmingCharacters(in: .whitespacesAndNewlines)
        case let .htmlBlock(content):
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        case let .image(_, alt):
            return alt
        case .thematicBreak:
            return ""
        case let .blockquote(blocks):
            return blocks.map { plainText(from: $0) }.joined(separator: "\n")
        case let .orderedList(items):
            return items
                .map { $0.blocks.map { plainText(from: $0) }.joined(separator: "\n") }
                .joined(separator: "\n")
        case let .unorderedList(items):
            return items
                .map { $0.blocks.map { plainText(from: $0) }.joined(separator: "\n") }
                .joined(separator: "\n")
        case let .table(columns, rows):
            let header = columns.map { String($0.header.characters) }.joined(separator: "\t")
            let body = rows
                .map { row in row.map { String($0.characters) }.joined(separator: "\t") }
                .joined(separator: "\n")
            return [header, body].filter { !$0.isEmpty }.joined(separator: "\n")
        }
    }
}
