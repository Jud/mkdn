import SwiftUI

/// Full-width Markdown preview (read-only mode).
///
/// Rendering is debounced via `.task(id:)` so that rapid typing in the
/// editor does not trigger a re-render on every keystroke. The initial
/// render on appear is performed without delay.
///
/// Content blocks appear with a staggered entrance animation on initial
/// file load and full content reloads. Each block fades in with a subtle
/// upward drift, offset by ``AnimationConstants/staggerDelay`` per block
/// (capped at ``AnimationConstants/staggerCap``). Incremental changes
/// (e.g. editor typing) update blocks instantly without stagger. With
/// Reduce Motion enabled, all blocks appear immediately.
struct MarkdownPreviewView: View {
    @Environment(DocumentState.self) private var documentState
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var renderedBlocks: [IndexedBlock] = []
    @State private var isInitialRender = true
    @State private var blockAppeared: [String: Bool] = [:]

    private var motion: MotionPreference {
        MotionPreference(reduceMotion: reduceMotion)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(renderedBlocks) { indexedBlock in
                    MarkdownBlockView(block: indexedBlock.block)
                        .opacity(blockAppeared[indexedBlock.id] ?? false ? 1.0 : 0)
                        .offset(y: blockAppeared[indexedBlock.id] ?? false ? 0 : 8)
                        .animation(
                            motion.resolved(.fadeIn)?
                                .delay(min(
                                    Double(indexedBlock.index) * motion.staggerDelay,
                                    AnimationConstants.staggerCap
                                )),
                            value: blockAppeared[indexedBlock.id] ?? false
                        )
                }
            }
            .padding(24)
        }
        .ignoresSafeArea()
        .background(appSettings.theme.colors.background)
        .task(id: documentState.markdownContent) {
            debugLog(
                "[PREVIEW] .task fired, content length=\(documentState.markdownContent.count), isInitial=\(isInitialRender)"
            )
            if isInitialRender {
                isInitialRender = false
            } else {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else {
                    debugLog("[PREVIEW] task cancelled during debounce")
                    return
                }
            }

            let newBlocks = MarkdownRenderer.render(
                text: documentState.markdownContent,
                theme: appSettings.theme
            )
            debugLog("[PREVIEW] rendered \(newBlocks.count) blocks: \(newBlocks.map { type(of: $0) })")
            let mermaidCount = newBlocks.filter { indexedBlock in
                if case .mermaidBlock = indexedBlock.block { return true }
                return false
            }.count
            debugLog("[PREVIEW] mermaid blocks: \(mermaidCount)")

            let anyAlreadyAppeared = newBlocks.contains { blockAppeared[$0.id] == true }
            let shouldStagger = !anyAlreadyAppeared && !reduceMotion && !newBlocks.isEmpty

            if shouldStagger {
                blockAppeared = [:]
                renderedBlocks = newBlocks

                try? await Task.sleep(for: .milliseconds(10))
                guard !Task.isCancelled else { return }

                for block in renderedBlocks {
                    blockAppeared[block.id] = true
                }
                debugLog("[PREVIEW] stagger triggered for \(renderedBlocks.count) blocks")
            } else {
                for block in newBlocks {
                    blockAppeared[block.id] = true
                }
                renderedBlocks = newBlocks
            }

            let currentIDs = Set(renderedBlocks.map(\.id))
            blockAppeared = blockAppeared.filter { currentIDs.contains($0.key) }
        }
        .onChange(of: appSettings.theme) {
            let newBlocks = MarkdownRenderer.render(
                text: documentState.markdownContent,
                theme: appSettings.theme
            )
            for block in newBlocks {
                blockAppeared[block.id] = true
            }
            renderedBlocks = newBlocks
        }
    }
}
