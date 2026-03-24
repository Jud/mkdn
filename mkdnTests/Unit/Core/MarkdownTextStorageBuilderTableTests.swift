import AppKit
import Testing
@testable import mkdnLib

@Suite("MarkdownTextStorageBuilder Table Attachment")
struct MarkdownTextStorageBuilderTableTests {
    let theme: AppTheme = .solarizedDark

    // MARK: - Helpers

    @MainActor private func buildSingle(_ block: MarkdownBlock) -> TextStorageResult {
        let indexed = IndexedBlock(index: 0, block: block)
        return MarkdownTextStorageBuilder.build(blocks: [indexed], theme: theme)
    }

    private var tableColumns: [TableColumn] {
        [
            TableColumn(header: AttributedString("Name"), alignment: .left),
            TableColumn(header: AttributedString("Age"), alignment: .right),
        ]
    }

    private var tableRows: [[AttributedString]] {
        [
            [AttributedString("Alice"), AttributedString("30")],
            [AttributedString("Bob"), AttributedString("25")],
        ]
    }

    // MARK: - Attachment-Based Table

    @Test("Table block produces an attachment, not inline text")
    @MainActor func tableProducesAttachment() {
        let result = buildSingle(.table(columns: tableColumns, rows: tableRows))
        #expect(!result.attachments.isEmpty)
        // The attributed string should NOT contain cell content as visible text.
        let plainText = result.attributedString.string
        #expect(!plainText.contains("Alice"))
        #expect(!plainText.contains("Bob"))
        #expect(!plainText.contains("Name"))
    }

    @Test("Table attachment is a TableTextAttachment with correct tableData")
    @MainActor func tableAttachmentHasData() {
        let result = buildSingle(.table(columns: tableColumns, rows: tableRows))
        #expect(result.attachments.count == 1)
        let attachment = result.attachments[0].attachment
        #expect(attachment is TableTextAttachment)
        let tableAttachment = attachment as? TableTextAttachment
        #expect(tableAttachment?.tableData != nil)
    }

    @Test("TableAttachmentData columns match input")
    @MainActor func tableDataColumnsMatch() throws {
        let result = buildSingle(.table(columns: tableColumns, rows: tableRows))
        let tableAttachment = result.attachments[0].attachment as? TableTextAttachment
        let data = tableAttachment?.tableData
        #expect(data?.columns.count == 2)
        #expect(try String(#require(data?.columns[0].header.characters)) == "Name")
        #expect(try String(#require(data?.columns[1].header.characters)) == "Age")
        #expect(data?.columns[0].alignment == .left)
        #expect(data?.columns[1].alignment == .right)
    }

    @Test("TableAttachmentData rows match input")
    @MainActor func tableDataRowsMatch() throws {
        let result = buildSingle(.table(columns: tableColumns, rows: tableRows))
        let tableAttachment = result.attachments[0].attachment as? TableTextAttachment
        let data = tableAttachment?.tableData
        #expect(data?.rows.count == 2)
        #expect(try String(#require(data?.rows[0][0].characters)) == "Alice")
        #expect(try String(#require(data?.rows[0][1].characters)) == "30")
        #expect(try String(#require(data?.rows[1][0].characters)) == "Bob")
        #expect(try String(#require(data?.rows[1][1].characters)) == "25")
    }

    @Test("TableAttachmentData blockIndex matches the indexed block")
    @MainActor func tableDataBlockIndex() {
        let indexed = IndexedBlock(index: 7, block: .table(columns: tableColumns, rows: tableRows))
        let result = MarkdownTextStorageBuilder.build(blocks: [indexed], theme: theme)
        let tableAttachment = result.attachments[0].attachment as? TableTextAttachment
        #expect(tableAttachment?.tableData?.blockIndex == 7)
    }

    @Test("TableAttachmentData has non-empty tableRangeID")
    @MainActor func tableDataHasRangeID() {
        let result = buildSingle(.table(columns: tableColumns, rows: tableRows))
        let tableAttachment = result.attachments[0].attachment as? TableTextAttachment
        #expect(tableAttachment?.tableData?.tableRangeID.isEmpty == false)
    }

    @Test("Multiple tables produce separate attachments with distinct range IDs")
    @MainActor func multipleTablesProduceSeparateAttachments() {
        let columns = [TableColumn(header: AttributedString("A"), alignment: .left)]
        let blocks = [
            IndexedBlock(index: 0, block: .table(columns: columns, rows: [[AttributedString("1")]])),
            IndexedBlock(index: 1, block: .table(columns: columns, rows: [[AttributedString("2")]])),
        ]
        let result = MarkdownTextStorageBuilder.build(blocks: blocks, theme: theme)
        #expect(result.attachments.count == 2)

        let att0 = result.attachments[0].attachment as? TableTextAttachment
        let att1 = result.attachments[1].attachment as? TableTextAttachment
        #expect(att0?.tableData?.tableRangeID != att1?.tableData?.tableRangeID)
    }

    @Test("Table with no rows produces attachment with empty rows")
    @MainActor func tableEmptyRowsAttachment() {
        let columns = [TableColumn(header: AttributedString("Col"), alignment: .left)]
        let result = buildSingle(.table(columns: columns, rows: []))
        #expect(result.attachments.count == 1)
        let tableAttachment = result.attachments[0].attachment as? TableTextAttachment
        #expect(tableAttachment?.tableData?.rows.isEmpty == true)
        #expect(tableAttachment?.tableData?.columns.count == 1)
    }

    @Test("Table attachment has non-zero bounds")
    @MainActor func tableAttachmentHasBounds() {
        let result = buildSingle(.table(columns: tableColumns, rows: tableRows))
        let attachment = result.attachments[0].attachment
        #expect(attachment.bounds.width > 0)
        #expect(attachment.bounds.height > 0)
    }

    @Test("TableTextAttachment allowsTextAttachmentView is true")
    @MainActor func tableAttachmentAllowsView() {
        let result = buildSingle(.table(columns: tableColumns, rows: tableRows))
        let attachment = result.attachments[0].attachment
        #expect(attachment.allowsTextAttachmentView == true)
    }

    // MARK: - Print Mode

    @Test("Print mode table uses inline text, not attachment")
    @MainActor func printModeUsesInlineText() {
        let indexed = IndexedBlock(
            index: 0,
            block: .table(columns: tableColumns, rows: tableRows)
        )
        let result = MarkdownTextStorageBuilder.build(
            blocks: [indexed],
            theme: theme,
            isPrint: true
        )
        // Print mode should NOT produce a TableTextAttachment.
        let hasTableAttachment = result.attachments.contains { info in
            info.attachment is TableTextAttachment
        }
        #expect(!hasTableAttachment)
        // Print mode should contain visible cell content.
        let plainText = result.attributedString.string
        #expect(plainText.contains("Name"))
        #expect(plainText.contains("Alice"))
    }
}
