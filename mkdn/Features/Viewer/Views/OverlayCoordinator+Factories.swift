#if os(macOS)
    import AppKit
    import SwiftUI

    // MARK: - Attachment Overlay Factories

    extension OverlayCoordinator {
        func makeMermaidOverlay(
            code: String,
            blockIndex: Int,
            appSettings: AppSettings
        ) -> NSView {
            let rootView = MermaidBlockView(code: code) { [weak self] height, _ in
                guard let self else { return }
                updateAttachmentHeight(blockIndex: blockIndex, newHeight: max(height, 100))
            }
            .environment(appSettings)
            .environment(containerState)
            return NSHostingView(rootView: rootView)
        }

        func makeImageOverlay(
            source: String,
            alt: String,
            blockIndex: Int,
            appSettings: AppSettings,
            documentState: DocumentState
        ) -> NSView {
            let containerWidth = textView.map { textContainerWidth(in: $0) } ?? 600
            let rootView = ImageBlockView(
                source: source,
                alt: alt,
                containerWidth: containerWidth
            ) { [weak self] renderedWidth, renderedHeight in
                guard let self else { return }
                let preferredWidth = renderedWidth < containerWidth ? renderedWidth : nil
                updateAttachmentSize(
                    blockIndex: blockIndex,
                    newWidth: preferredWidth,
                    newHeight: renderedHeight
                )
            }
            .environment(appSettings)
            .environment(documentState)
            .environment(containerState)
            return NSHostingView(rootView: rootView)
        }

        func makeThematicBreakOverlay(
            appSettings: AppSettings
        ) -> NSView {
            let borderColor = appSettings.theme.colors.border
            let rootView = borderColor
                .frame(height: 1)
                .padding(.vertical, 8)
            return NSHostingView(rootView: rootView)
        }

        func makeMathBlockOverlay(
            code: String,
            blockIndex: Int,
            appSettings: AppSettings
        ) -> NSView {
            let rootView = MathBlockView(code: code) { [weak self] newHeight in
                self?.updateAttachmentHeight(
                    blockIndex: blockIndex,
                    newHeight: newHeight
                )
            }
            .environment(appSettings)
            return NSHostingView(rootView: rootView)
        }

        func makeTableAttachmentOverlay(
            columns: [TableColumn],
            rows: [[AttributedString]],
            blockIndex: Int,
            appSettings: AppSettings
        ) -> NSView {
            let containerWidth = textView.map { textContainerWidth(in: $0) } ?? 600
            let rootView = TableAttachmentView(
                columns: columns,
                rows: rows,
                blockIndex: blockIndex,
                containerWidth: containerWidth
            )
            .environment(appSettings)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { [weak self] newSize in
                self?.updateAttachmentHeight(
                    blockIndex: blockIndex,
                    newHeight: newSize.height
                )
            }
            return PassthroughHostingView(rootView: rootView)
        }
    }
#endif
