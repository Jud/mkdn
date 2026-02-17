import Foundation

/// Monitors a directory and its first-level subdirectories for structural changes.
///
/// Uses `DispatchSource.makeFileSystemObjectSource` for efficient kernel-level
/// directory change notifications. Watches the root directory and each first-level
/// subdirectory with separate file descriptors. Events are bridged to `@MainActor`
/// via `AsyncStream`, following the same concurrency pattern as `FileWatcher`.
@MainActor
@Observable
final class DirectoryWatcher {
    /// Whether the watched directory structure has changed since last acknowledgment.
    private(set) var hasChanges = false

    @ObservationIgnored private nonisolated(unsafe) var sources: [any DispatchSourceFileSystemObject] = []
    @ObservationIgnored private nonisolated(unsafe) var watchTask: Task<Void, Never>?
    @ObservationIgnored private nonisolated(unsafe) var streamContinuation: AsyncStream<Void>.Continuation?
    private let queue = DispatchQueue(label: "com.mkdn.directorywatcher", qos: .utility)

    deinit {
        watchTask?.cancel()
        streamContinuation?.finish()
        for source in sources {
            source.cancel()
        }
    }

    // MARK: - Public API

    /// Start watching a directory and its first-level subdirectories.
    ///
    /// - Parameters:
    ///   - rootURL: The root directory to watch.
    ///   - subdirectories: First-level subdirectory URLs to watch alongside the root.
    func watch(rootURL: URL, subdirectories: [URL]) {
        stopWatching()

        let allURLs = [rootURL] + subdirectories
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        streamContinuation = continuation

        for url in allURLs {
            let path = url.path(percentEncoded: false)
            let fileDescriptor = open(path, O_EVTONLY)
            guard fileDescriptor >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileDescriptor,
                eventMask: [.write, .rename, .delete, .link],
                queue: queue
            )

            Self.installHandlers(on: source, fd: fileDescriptor, continuation: continuation)
            source.resume()
            sources.append(source)
        }

        guard !sources.isEmpty else {
            continuation.finish()
            streamContinuation = nil
            return
        }

        watchTask = Task {
            for await _ in stream {
                guard !Task.isCancelled else { break }
                hasChanges = true
            }
        }
    }

    /// Stop all directory watching and release resources.
    func stopWatching() {
        watchTask?.cancel()
        watchTask = nil
        streamContinuation?.finish()
        streamContinuation = nil
        for source in sources {
            source.cancel()
        }
        sources.removeAll()
        hasChanges = false
    }

    /// Acknowledge the change (caller has refreshed the tree).
    func acknowledge() {
        hasChanges = false
    }

    // MARK: - Private

    /// Installs event and cancel handlers on a dispatch source.
    ///
    /// Must be `nonisolated` so that the handler closures do not
    /// inherit `@MainActor` isolation. DispatchSource fires handlers
    /// on its target queue (utility), and Swift 6 strict concurrency
    /// would otherwise insert a runtime MainActor assertion that
    /// crashes when the handler executes off the main thread.
    private nonisolated static func installHandlers(
        on source: any DispatchSourceFileSystemObject,
        fd: Int32,
        continuation: AsyncStream<Void>.Continuation
    ) {
        source.setEventHandler {
            continuation.yield()
        }
        source.setCancelHandler {
            if fd >= 0 {
                close(fd)
            }
        }
    }
}
