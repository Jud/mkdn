import Foundation

/// Stores validated file URLs from CLI parsing for the App to read at launch.
///
/// Set once in `main.swift` before `MkdnApp.main()` is called, then consumed
/// once by `DocumentWindow.task`. This sequential access pattern has no
/// concurrency concern, so `nonisolated(unsafe)` is appropriate.
public enum LaunchContext {
    /// The validated file URLs, or empty for no-argument launch.
    public nonisolated(unsafe) static var fileURLs: [URL] = []

    /// Returns all `fileURLs` and clears them so they are only consumed once.
    public static func consumeURLs() -> [URL] {
        let urls = fileURLs
        fileURLs = []
        return urls
    }
}
