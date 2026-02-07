import Foundation

/// Bridges system file-open events from the AppKit delegate into SwiftUI window management.
///
/// The ``AppDelegate`` pushes incoming URLs into ``pendingURLs``. The SwiftUI
/// `App` body observes changes and calls ``consumeAll()`` to drain the queue,
/// opening a new window for each URL.
@MainActor
@Observable
public final class FileOpenCoordinator {
    /// Shared singleton used by both the AppDelegate (producer) and MkdnApp (consumer).
    public static let shared = FileOpenCoordinator()

    /// URLs waiting to be opened in new windows.
    public var pendingURLs: [URL] = []

    /// Returns all pending URLs and clears the queue.
    public func consumeAll() -> [URL] {
        let urls = pendingURLs
        pendingURLs.removeAll()
        return urls
    }

    /// Whether the given URL has a Markdown file extension (`.md` or `.markdown`, case-insensitive).
    public nonisolated static func isMarkdownURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "md" || ext == "markdown"
    }
}
