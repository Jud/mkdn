import Foundation

/// Per-window directory state backing the sidebar navigation panel.
///
/// Owns the file tree model, sidebar layout state, expansion/selection
/// state, and the ``DirectoryWatcher`` that monitors the root directory
/// and its first-level subdirectories for structural changes.
///
/// Created by ``DocumentWindow`` when a `.directory` launch item is
/// received. Holds a weak reference to the per-window ``DocumentState``
/// so that file selections in the sidebar can load content into the
/// existing viewer pipeline.
@MainActor
@Observable
public final class DirectoryState {
    // MARK: - Tree State

    /// Root directory URL.
    public let rootURL: URL

    /// The file tree model, rebuilt on scan/refresh.
    public private(set) var tree: FileTreeNode?

    /// URLs of directories currently expanded in the sidebar.
    public var expandedDirectories: Set<URL> = []

    // MARK: - Selection State

    /// The currently selected file URL in the sidebar.
    public var selectedFileURL: URL?

    // MARK: - Scanning Configuration

    /// Maximum depth for recursive directory scanning.
    static let maxScanDepth = 10

    // MARK: - Directory Watcher

    let directoryWatcher = DirectoryWatcher()

    // MARK: - DocumentState Reference

    /// Weak reference to the per-window DocumentState for file loading.
    public weak var documentState: DocumentState?

    // MARK: - Private

    @ObservationIgnored private nonisolated(unsafe) var observationTask: Task<Void, Never>?

    // MARK: - Init

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    deinit {
        observationTask?.cancel()
    }

    // MARK: - Public API

    /// Perform initial directory scan and start watching.
    ///
    /// Scans the root directory via ``DirectoryScanner``, expands
    /// first-level directories by default, and starts the
    /// ``DirectoryWatcher`` for live filesystem monitoring.
    public func scan() {
        tree = DirectoryScanner.scan(url: rootURL, maxDepth: Self.maxScanDepth)
        expandFirstLevelDirectories()
        startWatching()
        startObservingWatcher()
    }

    /// Refresh the tree from disk, preserving expansion and selection state.
    ///
    /// If the previously selected file has been deleted, the selection is
    /// cleared and the ``DocumentState`` is reset to show the welcome view.
    /// The watcher is restarted with the updated subdirectory list.
    public func refresh() {
        let previousExpanded = expandedDirectories
        let previousSelected = selectedFileURL

        tree = DirectoryScanner.scan(url: rootURL, maxDepth: Self.maxScanDepth)

        expandedDirectories = previousExpanded

        if let selected = previousSelected {
            if FileManager.default.fileExists(atPath: selected.path) {
                selectedFileURL = selected
            } else {
                selectedFileURL = nil
                documentState?.currentFileURL = nil
                documentState?.markdownContent = ""
            }
        }

        directoryWatcher.acknowledge()
        startWatching()
    }

    /// Select a file and load it in the content area.
    public func selectFile(at url: URL) {
        selectedFileURL = url
        try? documentState?.loadFile(at: url)
    }

    // MARK: - Private

    private func expandFirstLevelDirectories() {
        guard let tree else { return }
        for child in tree.children where child.isDirectory {
            expandedDirectories.insert(child.url)
        }
    }

    private func startWatching() {
        let subdirectories = firstLevelSubdirectories()
        directoryWatcher.watch(rootURL: rootURL, subdirectories: subdirectories)
    }

    private func firstLevelSubdirectories() -> [URL] {
        guard let tree else { return [] }
        return tree.children.filter(\.isDirectory).map(\.url)
    }

    private func startObservingWatcher() {
        observationTask?.cancel()
        observationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                if !directoryWatcher.hasChanges {
                    await withCheckedContinuation { continuation in
                        withObservationTracking {
                            _ = self.directoryWatcher.hasChanges
                        } onChange: {
                            continuation.resume()
                        }
                    }
                }

                guard !Task.isCancelled else { break }

                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { break }

                if directoryWatcher.hasChanges {
                    refresh()
                }
            }
        }
    }
}
