import SwiftUI

/// Central application state, observable across the view hierarchy.
@MainActor
@Observable
public final class AppState {

    // MARK: - File State

    /// The URL of the currently open Markdown file.
    public var currentFileURL: URL?

    /// Raw Markdown text content of the open file.
    public var markdownContent: String = ""

    /// Whether the on-disk file has changed since last load.
    public var isFileOutdated: Bool = false

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
        isFileOutdated = false
    }

    /// Save the current content back to the file.
    public func saveFile() throws {
        guard let url = currentFileURL else { return }
        try markdownContent.write(to: url, atomically: true, encoding: .utf8)
        isFileOutdated = false
    }

    /// Reload the file from disk.
    public func reloadFile() throws {
        guard let url = currentFileURL else { return }
        try loadFile(at: url)
    }
}
