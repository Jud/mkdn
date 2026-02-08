import SwiftUI

/// Column alignment matching Markdown table syntax.
enum TableColumnAlignment: Sendable {
    case left
    case center
    case right
}

/// Column definition for a Markdown table.
struct TableColumn: Sendable {
    let header: AttributedString
    let alignment: TableColumnAlignment
}

/// Represents a rendered Markdown block element.
enum MarkdownBlock: Identifiable {
    case heading(level: Int, text: AttributedString)
    case paragraph(text: AttributedString)
    case codeBlock(language: String?, code: String)
    case mermaidBlock(code: String)
    case blockquote(blocks: [Self])
    case orderedList(items: [ListItem])
    case unorderedList(items: [ListItem])
    case thematicBreak
    case table(columns: [TableColumn], rows: [[AttributedString]])
    case image(source: String, alt: String)
    case htmlBlock(content: String)

    var id: String {
        switch self {
        case let .heading(level, text):
            "heading-\(level)-\(stableHash(String(text.characters)))"
        case let .paragraph(text):
            "paragraph-\(stableHash(String(text.characters)))"
        case let .codeBlock(language, code):
            "code-\(language ?? "none")-\(stableHash(code))"
        case let .mermaidBlock(code):
            "mermaid-\(stableHash(code))"
        case let .blockquote(blocks):
            "blockquote-\(blocks.map(\.id).joined(separator: "-"))"
        case let .orderedList(items):
            "ol-\(items.count)-\(stableHash(items.map { $0.blocks.first?.id ?? "" }.joined()))"
        case let .unorderedList(items):
            "ul-\(items.count)-\(stableHash(items.map { $0.blocks.first?.id ?? "" }.joined()))"
        case .thematicBreak:
            "hr"
        case let .table(columns, _):
            "table-\(stableHash(columns.map { String($0.header.characters) }.joined()))"
        case let .image(source, _):
            "image-\(stableHash(source))"
        case let .htmlBlock(content):
            "html-\(stableHash(content))"
        }
    }
}

/// Pairs a MarkdownBlock with its position in the rendered document,
/// producing a unique ID for SwiftUI view identity.
struct IndexedBlock: Identifiable {
    let index: Int
    let block: MarkdownBlock

    var id: String {
        "\(index)-\(block.id)"
    }
}

/// A list item containing child blocks.
struct ListItem: Identifiable {
    let blocks: [MarkdownBlock]

    var id: String {
        "li-\(blocks.map(\.id).joined(separator: "-"))"
    }
}

/// DJB2 hash producing a stable, deterministic integer for a given string.
/// Unlike `.hashValue`, this returns the same value across process launches.
private func stableHash(_ string: String) -> UInt64 {
    var hash: UInt64 = 5_381
    for byte in string.utf8 {
        hash = hash &* 33 &+ UInt64(byte)
    }
    return hash
}
