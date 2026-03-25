#if os(macOS)
    import CoreServices
    import Foundation

    /// Recursively monitors a directory tree for structural changes using FSEvents.
    ///
    /// A single `FSEventStream` watches the entire directory tree rooted at
    /// `rootURL`. Changes at any depth trigger the `hasChanges` flag, which
    /// `DirectoryState` observes to refresh expanded directories.
    @MainActor
    @Observable
    final class DirectoryWatcher {
        /// Whether the watched directory structure has changed since last acknowledgment.
        private(set) var hasChanges = false

        @ObservationIgnored private nonisolated(unsafe) var eventStream: FSEventStreamRef?
        @ObservationIgnored private nonisolated(unsafe) var watchTask: Task<Void, Never>?
        @ObservationIgnored private nonisolated(unsafe) var streamContinuation: AsyncStream<Void>.Continuation?
        @ObservationIgnored private nonisolated(unsafe) var continuationBoxPtr: UnsafeMutableRawPointer?

        deinit {
            if let stream = eventStream {
                FSEventStreamStop(stream)
                FSEventStreamInvalidate(stream)
                FSEventStreamRelease(stream)
            }
            if let ptr = continuationBoxPtr {
                Unmanaged<ContinuationBox>.fromOpaque(ptr).release()
            }
            watchTask?.cancel()
            streamContinuation?.finish()
        }

        // MARK: - Public API

        /// Start recursively watching a directory tree.
        ///
        /// Monitors all subdirectories at any depth. The `subdirectories` parameter
        /// is accepted for API compatibility but ignored — FSEvents watches the
        /// entire tree from `rootURL`.
        func watch(rootURL: URL, subdirectories _: [URL] = []) {
            stopWatching()

            let path = rootURL.path(percentEncoded: false)
            let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
            streamContinuation = continuation

            var context = FSEventStreamContext()
            let ptr = Unmanaged.passRetained(
                ContinuationBox(continuation)
            ).toOpaque()
            continuationBoxPtr = ptr
            context.info = ptr

            let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
                guard let info else { return }
                let box = Unmanaged<ContinuationBox>.fromOpaque(info)
                    .takeUnretainedValue()
                box.continuation.yield()
            }

            guard let fsStream = FSEventStreamCreate(
                nil,
                callback,
                &context,
                [path] as CFArray,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                0.3, // 300ms latency (debounce at the OS level)
                UInt32(
                    kFSEventStreamCreateFlagUseCFTypes
                        | kFSEventStreamCreateFlagNoDefer
                        | kFSEventStreamCreateFlagFileEvents
                )
            ) else {
                Unmanaged<ContinuationBox>.fromOpaque(ptr).release()
                continuationBoxPtr = nil
                continuation.finish()
                streamContinuation = nil
                return
            }

            eventStream = fsStream
            FSEventStreamSetDispatchQueue(fsStream, DispatchQueue.global(qos: .utility))
            FSEventStreamStart(fsStream)

            watchTask = Task {
                for await _ in stream {
                    guard !Task.isCancelled else { break }
                    hasChanges = true
                }
            }
        }

        /// Stop watching and release all resources.
        func stopWatching() {
            if let stream = eventStream {
                FSEventStreamStop(stream)
                FSEventStreamInvalidate(stream)
                FSEventStreamRelease(stream)
                eventStream = nil
            }
            if let ptr = continuationBoxPtr {
                Unmanaged<ContinuationBox>.fromOpaque(ptr).release()
                continuationBoxPtr = nil
            }
            watchTask?.cancel()
            watchTask = nil
            if let continuation = streamContinuation {
                continuation.finish()
                streamContinuation = nil
            }
            hasChanges = false
        }

        /// Acknowledge the change (caller has refreshed the tree).
        func acknowledge() {
            hasChanges = false
        }

        // MARK: - Private

        /// Box to bridge the `AsyncStream.Continuation` into the C callback context.
        private final class ContinuationBox: @unchecked Sendable {
            let continuation: AsyncStream<Void>.Continuation
            init(_ continuation: AsyncStream<Void>.Continuation) {
                self.continuation = continuation
            }
        }
    }
#endif
