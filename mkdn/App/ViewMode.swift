/// Display modes for the main content area.
public enum ViewMode: String, CaseIterable, Sendable {
    /// Full-width rendered Markdown preview.
    case previewOnly = "Preview"

    /// Side-by-side editor and preview.
    case sideBySide = "Edit + Preview"
}
