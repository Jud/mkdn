import Foundation

/// Block identity comparison for overlay recycling in ``OverlayCoordinator``.
///
/// When the document is re-rendered, `blocksMatch` determines whether an
/// existing overlay view can be reused (avoiding teardown/rebuild) or must
/// be replaced. Tables use deep content comparison including column
/// alignments and all row cell text.
extension OverlayCoordinator {
    func blocksMatch(_ lhs: MarkdownBlock, _ rhs: MarkdownBlock) -> Bool {
        switch (lhs, rhs) {
        case let (.mermaidBlock(code1), .mermaidBlock(code2)):
            code1 == code2
        case let (.image(src1, _), .image(src2, _)):
            src1 == src2
        case (.thematicBreak, .thematicBreak):
            true
        case let (.table(cols1, rows1), .table(cols2, rows2)):
            tablesMatch(cols1: cols1, rows1: rows1, cols2: cols2, rows2: rows2)
        case let (.mathBlock(code1), .mathBlock(code2)):
            code1 == code2
        default:
            false
        }
    }

    private func tablesMatch(
        cols1: [TableColumn],
        rows1: [[AttributedString]],
        cols2: [TableColumn],
        rows2: [[AttributedString]]
    ) -> Bool {
        guard cols1.count == cols2.count, rows1.count == rows2.count else {
            return false
        }
        let headersMatch = cols1.map { String($0.header.characters) }
            == cols2.map { String($0.header.characters) }
        let alignmentsMatch = cols1.map(\.alignment) == cols2.map(\.alignment)
        guard headersMatch, alignmentsMatch else { return false }
        return zip(rows1, rows2).allSatisfy { row1, row2 in
            guard row1.count == row2.count else { return false }
            return zip(row1, row2).allSatisfy { cell1, cell2 in
                String(cell1.characters) == String(cell2.characters)
            }
        }
    }
}
