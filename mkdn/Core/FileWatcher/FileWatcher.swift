#if os(macOS)
    import CoreServices
    import Foundation

    /// Monitors a single file for changes and reports when it becomes outdated.
    ///
    /// Watches the file's **parent directory** with FSEvents and filters the
    /// stream down to the one file we care about. This is deliberately *not* a
    /// `DispatchSource` vnode source bound to the file's descriptor: editors and
    /// AI agents save via write-to-temp-then-atomic-rename, which replaces the
    /// file's inode. An fd-bound vnode watch keeps pointing at the now-unlinked
    /// old inode and goes permanently deaf after the first such save. FSEvents is
    /// path-based, so it keeps reporting changes across inode swaps, deletes, and
    /// recreations. (Mirrors `DirectoryWatcher`.)
    @MainActor
    @Observable
    final class FileWatcher {
        /// Whether the watched file has changed since last acknowledgment.
        private(set) var isOutdated = false

        /// Whether file-change events should be ignored (during app-initiated saves).
        private(set) var isSavePaused = false

        /// The URL currently being watched.
        private(set) var watchedURL: URL?

        @ObservationIgnored private nonisolated(unsafe) var eventStream: FSEventStreamRef?
        @ObservationIgnored private nonisolated(unsafe) var watchTask: Task<Void, Never>?
        @ObservationIgnored private nonisolated(unsafe) var streamContinuation: AsyncStream<Void>.Continuation?
        @ObservationIgnored private nonisolated(unsafe) var matcherBoxPtr: UnsafeMutableRawPointer?
        private let queue = DispatchQueue(label: "com.mkdn.filewatcher", qos: .utility)

        deinit {
            teardownStream()
            watchTask?.cancel()
            streamContinuation?.finish()
        }

        // MARK: - Public API

        /// Start watching a file for changes.
        func watch(url: URL) {
            stopWatching()
            watchedURL = url
            isOutdated = false

            // Resolve symlinks so we watch the *real* file's directory and match
            // its real path: atomic writes act on the resolved inode, and edits
            // can arrive through either the link or the real path.
            let resolved = url.resolvingSymlinksInPath()
            let directory = resolved.deletingLastPathComponent().path(percentEncoded: false)
            let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
            streamContinuation = continuation

            var context = FSEventStreamContext()
            let ptr = Unmanaged.passRetained(
                EventMatcherBox(targetPath: resolved.path, continuation: continuation)
            ).toOpaque()
            matcherBoxPtr = ptr
            context.info = ptr

            // FSEvents fires this on the dispatch queue (utility), off the main
            // actor. Filter the directory's events down to our target file before
            // yielding, so sibling edits don't mark us outdated — but when the
            // kernel coalesced/dropped events or the watched root changed, the
            // reported path can't be trusted, so yield unconditionally to force a
            // re-check (a missed change is the bug we're fixing; a spurious check
            // just no-ops on unchanged content).
            let callback: FSEventStreamCallback = { _, info, count, eventPaths, eventFlags, _ in
                guard let info else { return }
                let box = Unmanaged<EventMatcherBox>.fromOpaque(info).takeUnretainedValue()
                let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
                let untrustworthy = FSEventStreamEventFlags(
                    kFSEventStreamEventFlagMustScanSubDirs
                        | kFSEventStreamEventFlagUserDropped
                        | kFSEventStreamEventFlagKernelDropped
                        | kFSEventStreamEventFlagRootChanged
                )
                for i in 0 ..< count {
                    if eventFlags[i] & untrustworthy != 0
                        || (i < paths.count && box.matches(paths[i]))
                    {
                        box.continuation.yield()
                        return
                    }
                }
            }

            guard let fsStream = FSEventStreamCreate(
                nil,
                callback,
                &context,
                [directory] as CFArray,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                0.3, // 300ms latency (debounce at the OS level)
                UInt32(
                    kFSEventStreamCreateFlagUseCFTypes
                        | kFSEventStreamCreateFlagNoDefer
                        | kFSEventStreamCreateFlagFileEvents
                        | kFSEventStreamCreateFlagWatchRoot
                )
            )
            else {
                Unmanaged<EventMatcherBox>.fromOpaque(ptr).release()
                matcherBoxPtr = nil
                continuation.finish()
                streamContinuation = nil
                return
            }

            eventStream = fsStream
            FSEventStreamSetDispatchQueue(fsStream, queue)
            FSEventStreamStart(fsStream)

            watchTask = Task { [weak self] in
                for await _ in stream {
                    guard !Task.isCancelled, let self else { break }
                    if !self.isSavePaused {
                        self.isOutdated = true
                    }
                }
            }
        }

        /// Stop watching the current file.
        func stopWatching() {
            teardownStream()
            watchTask?.cancel()
            watchTask = nil
            if let continuation = streamContinuation {
                continuation.finish()
                streamContinuation = nil
            }
            watchedURL = nil
            isOutdated = false
        }

        /// Tear down the FSEvents stream and release the callback box.
        ///
        /// `nonisolated` so `deinit` can call it; touches only the
        /// `nonisolated(unsafe)` C-resource handles, never main-actor state.
        private nonisolated func teardownStream() {
            if let stream = eventStream {
                FSEventStreamStop(stream)
                FSEventStreamInvalidate(stream)
                FSEventStreamRelease(stream)
                eventStream = nil
            }
            if let ptr = matcherBoxPtr {
                Unmanaged<EventMatcherBox>.fromOpaque(ptr).release()
                matcherBoxPtr = nil
            }
        }

        /// Acknowledge the outdated state (e.g., after reload).
        func acknowledge() {
            isOutdated = false
        }

        /// Pause file-change detection during an app-initiated save.
        ///
        /// Call before writing to disk so the resulting FSEvents event does not
        /// produce a false outdated signal.
        func pauseForSave() {
            isSavePaused = true
        }

        /// Re-enable file-change detection after an app-initiated save.
        ///
        /// Waits approximately 200ms before clearing the pause flag to allow
        /// any in-flight file-change events to drain.
        func resumeAfterSave() {
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(200))
                self?.isSavePaused = false
            }
        }

        // MARK: - Private

        /// Bridges the `AsyncStream.Continuation` and the target-file filter into
        /// the C callback context.
        private final class EventMatcherBox: @unchecked Sendable {
            let continuation: AsyncStream<Void>.Continuation
            private let targetPath: String

            init(targetPath: String, continuation: AsyncStream<Void>.Continuation) {
                self.continuation = continuation
                self.targetPath = targetPath
            }

            /// True if an FSEvents path refers to the watched file. Both sides are
            /// symlink-resolved, so a same-named file in a sibling/descendant
            /// directory does not match (its resolved path differs). Matching the
            /// full resolved path — not just the filename — avoids a stray match
            /// that could leave the outdated flag stuck.
            func matches(_ eventPath: String) -> Bool {
                URL(fileURLWithPath: eventPath).resolvingSymlinksInPath().path == targetPath
            }
        }
    }
#endif
