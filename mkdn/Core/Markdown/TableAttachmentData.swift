#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Pure data carrier for table content within an attachment pipeline.
///
/// Holds the column definitions, row data, block index, and a unique identifier
/// for the table range. Used by ``TableTextAttachment`` to pass table data
/// through the `NSTextAttachment` system.
public struct TableAttachmentData: Sendable {
    public let columns: [TableColumn]
    public let rows: [[AttributedString]]
    public let blockIndex: Int
    public let tableRangeID: String

    public init(
        columns: [TableColumn],
        rows: [[AttributedString]],
        blockIndex: Int,
        tableRangeID: String
    ) {
        self.columns = columns
        self.rows = rows
        self.blockIndex = blockIndex
        self.tableRangeID = tableRangeID
    }
}

// MARK: - TableTextAttachment (macOS)

#if os(macOS)

    /// NSTextAttachment subclass that carries table data for attachment-based
    /// rendering via the ``OverlayCoordinator``.
    ///
    /// When inserted into an `NSAttributedString`, the overlay coordinator
    /// creates a ``TableAttachmentView`` hosted in an `NSHostingView` and
    /// positions it over the attachment placeholder. The
    /// `allowsTextAttachmentView` flag is set defensively for forward
    /// compatibility with `NSTextAttachmentViewProvider`.
    public class TableTextAttachment: NSTextAttachment {
        public var tableData: TableAttachmentData?

        /// Weak reference to the app-wide settings, injected by the builder
        /// so the overlay factory can pass it into the SwiftUI environment.
        public weak var appSettings: AppSettings?

        override public init(data contentData: Data?, ofType uti: String?) {
            super.init(data: contentData, ofType: uti)
            allowsTextAttachmentView = true
        }

        public convenience init(tableData: TableAttachmentData) {
            self.init(data: nil, ofType: nil)
            self.tableData = tableData
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not supported")
        }
    }

#endif
