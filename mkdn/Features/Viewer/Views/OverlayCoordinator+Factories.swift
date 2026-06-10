#if os(macOS)
    import AppKit
    import SwiftUI

    // MARK: - Attachment Overlay Factories

    extension OverlayCoordinator {
        private func makeLayerBackedHost(
            _ rootView: some View
        ) -> NSHostingView<some View> {
            // Pin content to the top of the host. During a width gesture the
            // host frame tracks the eased placeholder height while the
            // SwiftUI content has already rewrapped to its final height;
            // NSHostingView centers a root that doesn't match its bounds,
            // which makes the content bob vertically (a table's header and
            // last row both slide out of the clip) as the placeholder
            // catches up. GeometryReader is the one wrapper that always
            // adopts the proposed size — a flexible frame never shrinks
            // below its child, so the root would still mismatch and center —
            // and it places its child top-leading, so the mismatch only
            // ever shows at the bottom edge.
            let host = NSHostingView(rootView: GeometryReader { _ in rootView })
            host.wantsLayer = true
            host.layerContentsRedrawPolicy = .onSetNeedsDisplay
            return host
        }

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
            return makeLayerBackedHost(rootView)
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
            return makeLayerBackedHost(rootView)
        }

        func makeThematicBreakOverlay(
            appSettings: AppSettings
        ) -> NSView {
            let borderColor = appSettings.theme.colors.border
            let rootView = borderColor
                .frame(height: 1)
                .padding(.vertical, 8)
            return makeLayerBackedHost(rootView)
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
            return makeLayerBackedHost(rootView)
        }

        func makeTableAttachmentOverlay(
            columns: [TableColumn],
            rows: [[AttributedString]],
            blockIndex: Int,
            appSettings: AppSettings,
            findState: FindState?
        ) -> NSView {
            let containerWidth = textView.map { textContainerWidth(in: $0) } ?? 600
            let rootView = TableAttachmentView(
                columns: columns,
                rows: rows,
                blockIndex: blockIndex,
                containerWidth: containerWidth
            )
            .environment(appSettings)
            .environment(containerState)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { [weak self] newSize in
                self?.updateAttachmentHeight(
                    blockIndex: blockIndex,
                    newHeight: newSize.height
                )
            }
            // Use NSHostingView (not PassthroughHostingView) so mouse events
            // reach the TableAttachmentView's gesture handlers for cell
            // selection and onCopyCommand.
            let host: NSView = if let findState {
                makeLayerBackedHost(rootView.environment(findState))
            } else {
                makeLayerBackedHost(rootView)
            }
            // During a width gesture the rewrapped table renders a frame ahead
            // of its placeholder height; clip so the overflow trims at the
            // stale bound instead of painting over the text below. At rest the
            // placeholder matches the content, so this is a no-op.
            host.clipsToBounds = true
            return host
        }
    }
#endif
