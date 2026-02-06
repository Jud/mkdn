import Foundation

/// View model for the Markdown editor feature.
///
/// Tracks editing state and coordinates with the file system.
@MainActor
@Observable
final class EditorViewModel {
    /// The current text content in the editor.
    var text = ""

    /// Whether the editor has unsaved changes.
    var hasUnsavedChanges = false

    /// The file URL being edited.
    var fileURL: URL?

    // MARK: - Actions

    /// Load content from a file URL.
    func load(from url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        text = content
        fileURL = url
        hasUnsavedChanges = false
    }

    /// Save the current text to the file.
    func save() throws {
        guard let url = fileURL else { return }
        try text.write(to: url, atomically: true, encoding: .utf8)
        hasUnsavedChanges = false
    }

    /// Update text and mark as changed.
    func updateText(_ newText: String) {
        text = newText
        hasUnsavedChanges = true
    }
}
