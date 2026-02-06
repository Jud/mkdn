import Foundation

/// Stores the validated file URL from CLI parsing for the App to read at launch.
///
/// Set once in `main.swift` before `MkdnApp.main()` is called, then read once
/// during `MkdnApp.init()`. This sequential access pattern has no concurrency
/// concern, so `nonisolated(unsafe)` is appropriate.
public enum LaunchContext {
    /// The validated file URL, or `nil` for no-argument launch.
    public nonisolated(unsafe) static var fileURL: URL?
}
