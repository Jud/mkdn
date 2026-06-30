#if os(macOS)
    import AppKit
    import SwiftUI
    import UniformTypeIdentifiers

    /// Per-window document state, observable across the view hierarchy.
    ///
    /// Each window creates its own `DocumentState` instance to manage the
    /// lifecycle of a single Markdown document: file I/O, editing, view mode,
    /// and file-change detection.
    @MainActor
    @Observable
    public final class DocumentState {
        // MARK: - File State

        /// The URL of the currently open Markdown file.
        public var currentFileURL: URL?

        /// The kind of file currently loaded (markdown, source code, or plain text).
        public var fileKind: FileKind = .markdown

        /// Raw text content of the open file.
        public var markdownContent = ""

        /// Baseline text from the last load or save, used for unsaved-changes detection.
        public private(set) var lastSavedContent = ""

        /// Whether the editor text diverges from the last-saved content.
        public var hasUnsavedChanges: Bool {
            markdownContent != lastSavedContent
        }

        /// Whether the on-disk file has changed since last load.
        public var isFileOutdated: Bool {
            fileWatcher.isOutdated
        }

        /// Owned file watcher instance; started on load, paused around saves.
        let fileWatcher = FileWatcher()

        // MARK: - Load Generation

        /// Monotonic counter incremented on each `loadFile()` call.
        /// Used to disambiguate block IDs across document loads.
        public private(set) var loadGeneration: UInt64 = 0

        // MARK: - View Rebuild Generation

        /// Identity nonce for the markdown preview's NSView. Bumped only by the
        /// test harness (see ``rebuildDocumentView()``) to force a cold
        /// `makeNSView`; stays `0` in normal use so production view identity is
        /// stable.
        public private(set) var viewRebuildGeneration: UInt64 = 0

        // MARK: - View Mode

        /// Current display mode: preview-only or side-by-side editing.
        public var viewMode: ViewMode = .previewOnly

        // MARK: - Mode Overlay State

        /// Label text for the ephemeral mode transition overlay.
        public var modeOverlayLabel: String?

        // MARK: - Entrance Gate

        /// Whether the loading gate is active (waiting for viewport overlays).
        var isLoadingGateActive = false

        // MARK: - Sidebar Layout State

        /// Whether the sidebar panel is visible.
        public var isSidebarVisible = false

        /// Whether the comment sidebar (right-docked) is visible.
        public var isCommentSidebarVisible = false

        /// Whether the comment sidebar can mount: a loaded markdown document in
        /// preview-only mode. The toggle command's enablement and the view's
        /// mount condition both derive from this, so they can't drift apart.
        public var canShowCommentSidebar: Bool {
            currentFileURL != nil && fileKind == .markdown && viewMode == .previewOnly
        }

        /// Whether the document minimap replaces the slim marker track in the gutter.
        public var isMinimapVisible = false

        /// Whether the minimap toggle is meaningful: a markdown document is loaded.
        public var canShowMinimap: Bool {
            currentFileURL != nil && fileKind == .markdown
        }

        /// Current sidebar width in points.
        public var sidebarWidth: CGFloat = 240

        /// Minimum sidebar width in points.
        static let minSidebarWidth: CGFloat = 160

        /// Maximum sidebar width in points.
        static let maxSidebarWidth: CGFloat = 400

        public init() {}

        // MARK: - Methods

        /// Force the markdown preview's `NSViewRepresentable` to be torn down and
        /// recreated — a fresh `makeNSView` / cold first paint — by changing its
        /// SwiftUI identity. Used by the test harness to reproduce cold
        /// first-paint rendering bugs in-session; not called in normal operation.
        public func rebuildDocumentView() {
            viewRebuildGeneration &+= 1
        }

        /// Load a file from the given URL.
        public func loadFile(at url: URL) throws {
            loadGeneration &+= 1
            let content = try String(contentsOf: url, encoding: .utf8)
            if currentFileURL == url, markdownContent == content {
                // Same file, unchanged content — skip to avoid overlay flash
                return
            }
            currentFileURL = url
            fileKind = url.fileKind ?? .plainText
            markdownContent = content
            lastSavedContent = content
            fileWatcher.watch(url: url)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        }

        /// Save the current content back to the file.
        public func saveFile() throws {
            guard let url = currentFileURL else { return }
            fileWatcher.pauseForSave()
            defer { fileWatcher.resumeAfterSave() }
            try markdownContent.write(to: url, atomically: true, encoding: .utf8)
            lastSavedContent = markdownContent
        }

        // MARK: - Comments

        /// Add a comment anchored by content: store `selector` (a normalized
        /// quote + context captured against the rendered text) and `body` in the
        /// EOF sidecar, no inline markers. Updates the content (re-renders) and
        /// auto-persists the sidecar (see ``persistCommentChange()``). Returns
        /// the new comment's id so the caller can reveal it.
        @discardableResult
        public func addComment(_ selector: CommentSelector, body: String) -> String {
            let id = CommentSidecar.uniqueID(in: markdownContent)
            var entry = CommentSidecar.Entry(id: id, body: body)
            entry.setAnchor(selector)
            // Capture `entry` so the same id lands in memory and on disk.
            mutateComments { CommentSidecar.upsert(entry, into: $0) }
            return id
        }

        /// Rewrite a comment's body in the sidecar, looked up by id. False if no
        /// entry has that id.
        @discardableResult
        public func editComment(id: String, newBody: String) -> Bool {
            mutateComments { content in
                guard let decoded = CommentSidecar.decode(from: content),
                      let index = decoded.entries.firstIndex(where: { $0.id == id })
                else { return nil }
                var entries = decoded.entries
                entries[index].body = newBody
                var updated = content
                updated.replaceSubrange(decoded.blockRange, with: CommentSidecar.encode(entries))
                return updated
            }
        }

        /// Append a reply to a comment's thread. In-app replies carry no author
        /// (rendered as "You"); agent replies arrive through `mkdn comments reply`
        /// with a name. False if no entry has that id.
        @discardableResult
        public func addReply(toCommentID id: String, body: String) -> Bool {
            // Mint the reply id once so the in-memory and on-disk writes are
            // identical (CommentSidecar.addReply would generate a fresh id per
            // call, and this edit runs against both the memory and disk copies).
            let reply = CommentSidecar.Reply(
                id: CommentSidecar.uniqueID(in: markdownContent), body: body, author: nil
            )
            return mutateComments { content in
                guard let decoded = CommentSidecar.decode(from: content),
                      let index = decoded.entries.firstIndex(where: { $0.id == id })
                else { return nil }
                var entries = decoded.entries
                entries[index].replies = (entries[index].replies ?? []) + [reply]
                var updated = content
                updated.replaceSubrange(decoded.blockRange, with: CommentSidecar.encode(entries))
                return updated
            }
        }

        /// Delete a comment's sidecar entry by id (works even when the comment is
        /// orphaned). False if no entry has that id.
        @discardableResult
        public func deleteComment(id: String) -> Bool {
            mutateComments { content in
                let updated = CommentSidecar.remove(id: id, from: content)
                return updated != content ? updated : nil
            }
        }

        /// Apply a comment-sidecar edit to the in-memory document (so the rail
        /// re-renders) and persist it durably — but persist by re-applying the
        /// SAME edit to the file's *current on-disk* content, never our in-memory
        /// copy. Comments are annotations, so writing the whole in-memory document
        /// would (a) commit body edits the user hasn't saved and (b) clobber an
        /// external change that landed since we loaded. Re-applying only the
        /// sidecar delta to the latest disk content avoids both: the body stays
        /// the user's to save, and a concurrent agent/editor write survives (the
        /// still-pending reload reconciles in-memory afterward). Returns false
        /// when the edit doesn't apply in memory (e.g. unknown id).
        @discardableResult
        private func mutateComments(_ edit: (String) -> String?) -> Bool {
            guard let next = edit(markdownContent) else { return false }
            markdownContent = next
            persistSidecarEdit(edit)
            return true
        }

        /// Persist a sidecar edit by re-applying it to the file's current on-disk
        /// content. No-op when no file is open or the edit doesn't apply there;
        /// surfaces a failed write instead of dropping it silently.
        private func persistSidecarEdit(_ edit: (String) -> String?) {
            guard let url = currentFileURL else { return }
            do {
                let onDisk = try String(contentsOf: url, encoding: .utf8)
                guard let written = edit(onDisk) else { return }
                fileWatcher.pauseForSave()
                defer { fileWatcher.resumeAfterSave() }
                try written.write(to: url, atomically: true, encoding: .utf8)
                // When nothing else diverges (no unsaved body edits, no external
                // change) the write equals our in-memory doc — keep the saved
                // baseline current so it doesn't read as dirty.
                if markdownContent == written { lastSavedContent = written }
            } catch {
                modeOverlayLabel = "Save failed"
            }
        }

        /// Reload the file from disk.
        public func reloadFile() throws {
            guard let url = currentFileURL else { return }
            try loadFile(at: url)
        }

        /// Save the current content to a new file location chosen by the user.
        public func saveAs() {
            let panel = NSSavePanel()
            if let mdType = UTType(filenameExtension: "md") {
                panel.allowedContentTypes = [mdType]
            }
            panel.canCreateDirectories = true

            if let currentURL = currentFileURL {
                panel.directoryURL = currentURL.deletingLastPathComponent()
                panel.nameFieldStringValue = currentURL.lastPathComponent
            }

            guard panel.runModal() == .OK, let url = panel.url else { return }

            fileWatcher.pauseForSave()
            defer { fileWatcher.resumeAfterSave() }

            do {
                try markdownContent.write(to: url, atomically: true, encoding: .utf8)
                currentFileURL = url
                lastSavedContent = markdownContent
                fileWatcher.watch(url: url)
                NSDocumentController.shared.noteNewRecentDocumentURL(url)
            } catch {
                modeOverlayLabel = "Save failed"
            }
        }

        /// Switch view mode and trigger the ephemeral overlay.
        public func switchMode(to mode: ViewMode) {
            viewMode = mode
            modeOverlayLabel = mode == .previewOnly ? "Preview" : "Edit"
        }

        /// Toggle sidebar visibility.
        public func toggleSidebar() {
            isSidebarVisible.toggle()
        }

        /// Toggle the comment sidebar's visibility.
        public func toggleCommentSidebar() {
            isCommentSidebarVisible.toggle()
        }

        /// Toggle the document minimap (it swaps in for the marker track).
        public func toggleMinimap() {
            isMinimapVisible.toggle()
        }
    }
#endif
