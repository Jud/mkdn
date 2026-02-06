import SwiftUI

/// Central application state, observable across the view hierarchy.
@MainActor
@Observable
public final class AppState {
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

    // MARK: - View Mode

    /// Current display mode: preview-only or side-by-side editing.
    public var viewMode: ViewMode = .previewOnly

    // MARK: - Theme

    /// Active color theme.
    public var theme: AppTheme = .solarizedDark

    public init() {}

    // MARK: - Methods

    /// Load a Markdown file from the given URL.
    public func loadFile(at url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        currentFileURL = url
        markdownContent = content
        lastSavedContent = content
        fileWatcher.watch(url: url)
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
}
