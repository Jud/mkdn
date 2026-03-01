import SwiftUI

/// Composed Markdown rendering view that displays an array of parsed blocks
/// with full fidelity using platform-appropriate hosting views.
///
/// On iOS, renders blocks in a ``ScrollViewReader`` > ``ScrollView`` >
/// ``LazyVStack`` hierarchy, dispatching each block to its type-specific
/// renderer via ``BlockWrapperView``. On macOS, provides a simplified
/// rendering path since the Mac app uses ``MarkdownPreviewView`` directly.
///
/// Interaction behavior is layered on via view modifiers from
/// ``View+MarkdownInteraction``:
///
/// ```swift
/// MarkdownContentView(blocks: blocks, theme: .solarizedDark)
///     .onBlockTapped { context in ... }
///     .blockContextMenu { context in ... }
///     .scrollTarget($scrollTarget)
/// ```
public struct MarkdownContentView: View {
    public let blocks: [IndexedBlock]
    public let theme: AppTheme
    public let scaleFactor: CGFloat

    @Environment(\.markdownInteraction) private var interaction

    public init(blocks: [IndexedBlock], theme: AppTheme, scaleFactor: CGFloat = 1.0) {
        self.blocks = blocks
        self.theme = theme
        self.scaleFactor = scaleFactor
    }

    public var body: some View {
        #if os(iOS)
            iOSBody
        #else
            macOSBody
        #endif
    }

    // MARK: - iOS Body

    #if os(iOS)
        private var iOSBody: some View {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(blocks) { block in
                            BlockWrapperView(
                                indexedBlock: block,
                                theme: theme,
                                scaleFactor: scaleFactor
                            )
                            .id(block.id)
                        }
                    }
                    .padding()
                }
                .coordinateSpace(name: "markdownContent")
                .onChange(of: interaction.scrollTarget?.wrappedValue) { _, target in
                    guard let target else { return }
                    withAnimation {
                        proxy.scrollTo(
                            blocks.first { $0.index == target.blockIndex }?.id,
                            anchor: target.anchor
                        )
                    }
                    interaction.scrollTarget?.wrappedValue = nil
                }
            }
        }
    #endif

    // MARK: - macOS Body

    #if os(macOS)
        private var macOSBody: some View {
            let result = MarkdownTextStorageBuilder.build(
                blocks: blocks,
                theme: theme,
                scaleFactor: scaleFactor
            )
            return ScrollView {
                Text(AttributedString(result.attributedString))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
    #endif
}

// MARK: - Block Wrapper (iOS)

#if os(iOS)
    /// Internal view that dispatches each block to its type-specific iOS renderer
    /// and applies interaction handlers from the environment.
    ///
    /// When ``MarkdownInteraction/blockViewWrapperClosure`` is set, the default
    /// block view is passed to the wrapper **without** library gesture modifiers.
    /// The wrapper is responsible for adding its own interactions, though
    /// ``MarkdownInteraction/onBlockTapped`` still fires through via a tap gesture
    /// applied outside the wrapper.
    ///
    /// When no wrapper is set, the library applies default interactions including
    /// ``MarkdownInteraction/blockContextMenuBuilder`` and tap gestures.
    struct BlockWrapperView: View {
        let indexedBlock: IndexedBlock
        let theme: AppTheme
        let scaleFactor: CGFloat

        @Environment(\.markdownInteraction) private var interaction
        @State private var context: BlockInteractionContext
        @State private var cachedSize: CGSize = .zero

        init(indexedBlock: IndexedBlock, theme: AppTheme, scaleFactor: CGFloat) {
            self.indexedBlock = indexedBlock
            self.theme = theme
            self.scaleFactor = scaleFactor
            _context = State(initialValue: BlockInteractionContext(block: indexedBlock))
        }

        var body: some View {
            let defaultView = blockView(for: indexedBlock)

            Group {
                if let wrapper = interaction.blockViewWrapperClosure {
                    wrapper(context, AnyView(defaultView))
                } else {
                    defaultView
                        .applyContextMenu(
                            context: context,
                            builder: interaction.blockContextMenuBuilder
                        )
                }
            }
            .applyTapGesture(
                context: context,
                handler: interaction.onBlockTapped
            )
            .applySizeReporting(
                cachedSize: $cachedSize,
                blockIndex: indexedBlock.index,
                handler: interaction.onBlockSizeChanged
            )
        }

        // MARK: - Block Dispatch

        @ViewBuilder
        private func blockView(for block: IndexedBlock) -> some View {
            switch block.block {
            case let .codeBlock(language, code):
                CodeBlockViewiOS(
                    language: language,
                    code: code,
                    theme: theme,
                    scaleFactor: scaleFactor
                )

            case let .mermaidBlock(code):
                MermaidBlockViewiOS(code: code, theme: theme)

            case let .mathBlock(code):
                MathBlockViewiOS(
                    code: code,
                    theme: theme,
                    scaleFactor: scaleFactor,
                    context: context
                )

            case let .table(columns, rows):
                TableBlockViewiOS(
                    columns: columns,
                    rows: rows,
                    theme: theme,
                    scaleFactor: scaleFactor
                )

            case let .image(source, alt):
                ImageBlockViewiOS(
                    source: source,
                    alt: alt,
                    theme: theme,
                    baseURL: nil,
                    context: context
                )

            case .heading, .paragraph, .blockquote, .orderedList, .unorderedList,
                 .thematicBreak, .htmlBlock:
                TextBlockViewiOS(
                    indexedBlock: block,
                    theme: theme,
                    scaleFactor: scaleFactor
                )
            }
        }
    }

    // MARK: - Interaction Helpers

    private extension View {
        @ViewBuilder
        func applyTapGesture(
            context: BlockInteractionContext,
            handler: ((BlockInteractionContext) -> Void)?
        ) -> some View {
            if let handler {
                onTapGesture {
                    handler(context)
                }
            } else {
                self
            }
        }

        @ViewBuilder
        func applyContextMenu(
            context: BlockInteractionContext,
            builder: ((BlockInteractionContext) -> AnyView)?
        ) -> some View {
            if let builder {
                contextMenu {
                    builder(context)
                }
            } else {
                self
            }
        }

        func applySizeReporting(
            cachedSize: Binding<CGSize>,
            blockIndex: Int,
            handler: ((_ blockIndex: Int, _ size: CGSize) -> Void)?
        ) -> some View {
            background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            let size = geometry.size
                            if size != cachedSize.wrappedValue {
                                cachedSize.wrappedValue = size
                                handler?(blockIndex, size)
                            }
                        }
                        .onChange(of: geometry.size) { _, newSize in
                            if newSize != cachedSize.wrappedValue {
                                cachedSize.wrappedValue = newSize
                                handler?(blockIndex, newSize)
                            }
                        }
                }
            )
        }
    }
#endif
