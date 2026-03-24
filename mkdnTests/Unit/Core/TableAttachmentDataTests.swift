import AppKit
import Testing
@testable import mkdnLib

@Suite("TableAttachmentData")
struct TableAttachmentDataTests {
    // MARK: - TableTextAttachment

    @Test("TableTextAttachment stores and retrieves TableAttachmentData")
    func storesTableData() {
        let columns = [
            TableColumn(header: AttributedString("Name"), alignment: .left),
            TableColumn(header: AttributedString("Age"), alignment: .right),
        ]
        let rows: [[AttributedString]] = [
            [AttributedString("Alice"), AttributedString("30")],
        ]
        let data = TableAttachmentData(
            columns: columns,
            rows: rows,
            blockIndex: 0,
            tableRangeID: "test-id"
        )

        let attachment = TableTextAttachment(tableData: data)

        #expect(attachment.tableData != nil)
        #expect(attachment.tableData?.columns.count == 2)
        #expect(attachment.tableData?.rows.count == 1)
        #expect(attachment.tableData?.blockIndex == 0)
        #expect(attachment.tableData?.tableRangeID == "test-id")
    }

    @Test("TableTextAttachment.allowsTextAttachmentView is true")
    func allowsTextAttachmentView() {
        let attachment = TableTextAttachment(tableData: TableAttachmentData(
            columns: [],
            rows: [],
            blockIndex: 0,
            tableRangeID: "test"
        ))

        #expect(attachment.allowsTextAttachmentView == true)
    }

    @Test("TableTextAttachment without tableData has nil tableData")
    func nilTableDataByDefault() {
        let attachment = TableTextAttachment(data: nil, ofType: nil)
        #expect(attachment.tableData == nil)
    }

    // MARK: - TableAttachmentData

    @Test("TableAttachmentData preserves all fields")
    func preservesFields() {
        let columns = [
            TableColumn(header: AttributedString("Col1"), alignment: .center),
        ]
        let rows: [[AttributedString]] = [
            [AttributedString("val1")],
            [AttributedString("val2")],
        ]

        let data = TableAttachmentData(
            columns: columns,
            rows: rows,
            blockIndex: 3,
            tableRangeID: "uuid-123"
        )

        #expect(data.columns.count == 1)
        #expect(data.rows.count == 2)
        #expect(data.blockIndex == 3)
        #expect(data.tableRangeID == "uuid-123")
        #expect(String(data.columns[0].header.characters) == "Col1")
        #expect(data.columns[0].alignment == .center)
    }
}
