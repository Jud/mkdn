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
        /// EOF sidecar, no inline markers. Updates the content (re-renders, marks
        /// dirty); persistence is the normal save flow (not auto-saved). Returns
        /// the new comment's id so the caller can reveal it.
        @discardableResult
        public func addComment(_ selector: CommentSelector, body: String) -> String {
            let id = CommentSidecar.uniqueID(in: markdownContent)
            var entry = CommentSidecar.Entry(id: id, body: body)
            entry.setAnchor(selector)
            markdownContent = CommentSidecar.upsert(entry, into: markdownContent)
            return id
        }

        /// Rewrite a comment's body in the sidecar, looked up by id. False if no
        /// entry has that id.
        @discardableResult
        public func editComment(id: String, newBody: String) -> Bool {
            guard let decoded = CommentSidecar.decode(from: markdownContent),
                  decoded.entries.contains(where: { $0.id == id })
            else {
                return false
            }
            var entries = decoded.entries
            for index in entries.indices where entries[index].id == id {
                entries[index].body = newBody
            }
            var updated = markdownContent
            updated.replaceSubrange(decoded.blockRange, with: CommentSidecar.encode(entries))
            markdownContent = updated
            return true
        }

        /// Delete a comment's sidecar entry by id (works even when the comment is
        /// orphaned). False if no entry has that id.
        @discardableResult
        public func deleteComment(id: String) -> Bool {
            let updated = CommentSidecar.remove(id: id, from: markdownContent)
            guard updated != markdownContent else { return false }
            markdownContent = updated
            return true
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
    }
#endif
