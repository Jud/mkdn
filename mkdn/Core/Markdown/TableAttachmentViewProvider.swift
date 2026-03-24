#if os(macOS)
    import AppKit
    import SwiftUI

    /// Provides a SwiftUI-hosted ``TableAttachmentView`` for each
    /// ``TableTextAttachment`` in the text storage.
    ///
    /// TextKit 2 calls ``loadView()`` when the attachment's layout fragment
    /// enters the viewport. The provider reads ``TableTextAttachment/tableData``
    /// and wraps a ``TableAttachmentView`` in an `NSHostingView`, injecting
    /// ``AppSettings`` into the SwiftUI environment so theme and scale factor
    /// resolve correctly outside the main view hierarchy.
    ///
    /// `@preconcurrency` bridges the SDK gap where `NSTextAttachmentViewProvider`
    /// methods are not annotated `@MainActor` even though TextKit 2 always calls
    /// them on the main thread.
    @preconcurrency @MainActor
    final class TableAttachmentViewProvider: NSTextAttachmentViewProvider {
        /// Default container width for initial sizing before the text container
        /// width is known. Matches ``MarkdownTextStorageBuilder/defaultEstimationContainerWidth``.
        nonisolated static let fallbackContainerWidth: CGFloat = 600

        // MARK: - View Loading

        /// TextKit 2 always calls loadView on the main thread.
        override func loadView() {
            guard let tableAttachment = textAttachment as? TableTextAttachment,
                  let data = tableAttachment.tableData
            else {
                view = NSView()
                return
            }

            let tc = textLayoutManager?.textContainer
            let containerWidth: CGFloat = if let tc,
                                             tc.size.width > 0
            {
                tc.size.width
            } else {
                Self.fallbackContainerWidth
            }

            let tableView = TableAttachmentView(
                columns: data.columns,
                rows: data.rows,
                blockIndex: data.blockIndex,
                containerWidth: containerWidth
            )

            let hostingView: NSHostingView<AnyView> = if let appSettings = tableAttachment.appSettings {
                NSHostingView(
                    rootView: AnyView(tableView.environment(appSettings))
                )
            } else {
                NSHostingView(
                    rootView: AnyView(tableView.environment(AppSettings()))
                )
            }

            view = hostingView
        }

        // MARK: - Attachment Bounds

        override func attachmentBounds(
            for _: [NSAttributedString.Key: Any],
            location _: any NSTextLocation,
            textContainer: NSTextContainer?,
            proposedLineFragment: CGRect,
            position _: CGPoint
        ) -> CGRect {
            guard let tableAttachment = textAttachment as? TableTextAttachment,
                  let data = tableAttachment.tableData
            else {
                return .zero
            }

            let lineFragPadding = textContainer?.lineFragmentPadding ?? 0
            let containerWidth = proposedLineFragment.width - lineFragPadding * 2
            let font = PlatformTypeConverter.bodyFont()

            let sizer = TableColumnSizer.computeWidths(
                columns: data.columns,
                rows: data.rows,
                containerWidth: containerWidth,
                font: font
            )

            let height = TableColumnSizer.estimateTableHeight(
                columns: data.columns,
                rows: data.rows,
                columnWidths: sizer.columnWidths,
                font: font
            )

            return CGRect(
                x: 0,
                y: 0,
                width: sizer.totalWidth,
                height: height
            )
        }
    }
#endif
