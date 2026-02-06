import Foundation

/// Monitors a file for changes and reports when it becomes outdated.
///
/// Uses `DispatchSource.makeFileSystemObjectSource` for efficient
/// kernel-level file change notifications.
@MainActor
@Observable
final class FileWatcher {
    /// Whether the watched file has changed since last acknowledgment.
    private(set) var isOutdated = false

    /// Whether file-change events should be ignored (during app-initiated saves).
    private(set) var isSavePaused = false

    /// The URL currently being watched.
    private(set) var watchedURL: URL?

    @ObservationIgnored private nonisolated(unsafe) var dispatchSource: (any DispatchSourceFileSystemObject)?
    @ObservationIgnored private nonisolated(unsafe) var fileDescriptor: Int32 = -1
    private let queue = DispatchQueue(label: "com.mkdn.filewatcher", qos: .utility)

    deinit {
        // Cancel the dispatch source — its cancel handler will close the fd.
        dispatchSource?.cancel()
    }

    // MARK: - Public API

    /// Start watching a file for changes.
    func watch(url: URL) {
        stopWatching()
        watchedURL = url
        isOutdated = false

        let path = url.path(percentEncoded: false)
        fileDescriptor = open(path, O_EVTONLY)

        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, !self.isSavePaused else { return }
                self.isOutdated = true
            }
        }

        let fd = fileDescriptor
        source.setCancelHandler {
            if fd >= 0 {
                close(fd)
            }
        }

        source.resume()
        dispatchSource = source
    }

    /// Stop watching the current file.
    func stopWatching() {
        dispatchSource?.cancel()
        dispatchSource = nil
        watchedURL = nil
        isOutdated = false
        fileDescriptor = -1
    }

    /// Acknowledge the outdated state (e.g., after reload).
    func acknowledge() {
        isOutdated = false
    }

    /// Pause file-change detection during an app-initiated save.
    ///
    /// Call before writing to disk so the resulting DispatchSource event
    /// does not produce a false outdated signal.
    func pauseForSave() {
        isSavePaused = true
    }

    /// Re-enable file-change detection after an app-initiated save.
    ///
    /// Waits approximately 200ms before clearing the pause flag to allow
    /// any in-flight DispatchSource events to drain.
    func resumeAfterSave() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            self.isSavePaused = false
        }
    }
}
