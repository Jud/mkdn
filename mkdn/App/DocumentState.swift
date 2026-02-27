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

    /// Raw Markdown text content of the open file.
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

    // MARK: - View Mode

    /// Current display mode: preview-only or side-by-side editing.
    public var viewMode: ViewMode = .previewOnly

    // MARK: - Mode Overlay State

    /// Label text for the ephemeral mode transition overlay.
    public var modeOverlayLabel: String?

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

    /// Load a Markdown file from the given URL.
    public func loadFile(at url: URL) throws {
        loadGeneration &+= 1
        let content = try String(contentsOf: url, encoding: .utf8)
        if currentFileURL == url, markdownContent == content {
            // Same file, unchanged content — skip to avoid overlay flash
            return
        }
        currentFileURL = url
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
