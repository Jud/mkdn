import SwiftUI

/// UserDefaults key for persisted theme mode preference.
private let themeModeKey = "themeMode"

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

    /// User's theme preference: auto (follows system), or a pinned variant.
    /// Persisted to UserDefaults under the `"themeMode"` key.
    public var themeMode: ThemeMode {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: themeModeKey)
        }
    }

    /// Current system color scheme, bridged from `@Environment(\.colorScheme)`.
    /// Updated by the root view whenever the OS appearance changes.
    public var systemColorScheme: ColorScheme = .dark

    /// Resolved color theme based on the user's mode preference and system appearance.
    /// All views read this to obtain colors and syntax highlighting.
    public var theme: AppTheme {
        themeMode.resolved(for: systemColorScheme)
    }

    // MARK: - Mode Overlay State

    /// Label text for the ephemeral mode transition overlay.
    public var modeOverlayLabel: String?

    public init() {
        if let raw = UserDefaults.standard.string(forKey: themeModeKey),
           let mode = ThemeMode(rawValue: raw)
        {
            themeMode = mode
        } else {
            themeMode = .auto
        }
    }

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

    /// Cycle to the next theme mode (Auto -> Dark -> Light -> Auto).
    public func cycleTheme() {
        let allModes = ThemeMode.allCases
        guard let currentIndex = allModes.firstIndex(of: themeMode) else { return }
        let nextIndex = (currentIndex + 1) % allModes.count
        themeMode = allModes[nextIndex]
        modeOverlayLabel = themeMode.displayName
    }

    /// Switch view mode and trigger the ephemeral overlay.
    public func switchMode(to mode: ViewMode) {
        viewMode = mode
        modeOverlayLabel = mode == .previewOnly ? "Preview" : "Edit"
    }
}
