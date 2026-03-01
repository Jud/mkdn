#if os(macOS)
    import Foundation

    /// Per-window directory state backing the sidebar navigation panel.
    ///
    /// Owns the file tree model, sidebar layout state, expansion/selection
    /// state, and the ``DirectoryWatcher`` that monitors the root directory
    /// and its first-level subdirectories for structural changes.
    ///
    /// Uses lazy scan-on-expand: only the top level is loaded initially,
    /// and subdirectories are scanned on demand when expanded.
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

        /// URLs of directories currently being loaded in the background.
        public private(set) var loadingDirectories: Set<URL> = []

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
        /// Loads only the top level via ``DirectoryScanner/scanSingleLevel(url:depth:)``
        /// on a background task, then expands first-level directories and
        /// lazily loads their children. Starts the ``DirectoryWatcher`` for
        /// live filesystem monitoring.
        public func scan() {
            let url = rootURL
            Task.detached {
                let children = DirectoryScanner.scanSingleLevel(url: url, depth: 0)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    tree = FileTreeNode(
                        name: url.lastPathComponent,
                        url: url,
                        isDirectory: true,
                        depth: 0,
                        children: children
                    )
                    expandFirstLevelDirectories()
                    startWatching()
                    startObservingWatcher()
                }
            }
        }

        /// Refresh expanded directories from disk, preserving expansion and selection state.
        ///
        /// Rescans only the root level and currently expanded directories rather
        /// than rebuilding the entire tree. If the previously selected file has
        /// been deleted, the selection is cleared.
        public func refresh() {
            let previousExpanded = expandedDirectories
            let previousSelected = selectedFileURL
            let url = rootURL

            Task.detached {
                let topLevelChildren = DirectoryScanner.scanSingleLevel(url: url, depth: 0)

                var expandedResults: [(URL, Int, [FileTreeNode])] = []
                for dirURL in previousExpanded {
                    let depth = self.depthForURL(dirURL, rootURL: url)
                    let children = DirectoryScanner.scanSingleLevel(url: dirURL, depth: depth)
                    expandedResults.append((dirURL, depth, children))
                }

                await MainActor.run { [weak self] in
                    guard let self else { return }

                    tree = FileTreeNode(
                        name: url.lastPathComponent,
                        url: url,
                        isDirectory: true,
                        depth: 0,
                        children: topLevelChildren
                    )

                    for (dirURL, _, children) in expandedResults {
                        updateNode(at: dirURL) { node in
                            node.children = children
                        }
                    }

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
            }
        }

        /// Load children for a directory if not yet scanned.
        ///
        /// Finds the node matching the URL in the tree. If its children are
        /// already loaded (`!= nil`), returns immediately. Otherwise dispatches
        /// a background scan and updates the tree on completion.
        public func loadChildrenIfNeeded(for url: URL) {
            guard let tree else { return }

            if let node = findNode(at: url, in: tree), node.isLoaded {
                return
            }

            guard !loadingDirectories.contains(url) else { return }
            loadingDirectories.insert(url)

            let parentDepth = findNode(at: url, in: tree)?.depth ?? 0

            Task.detached {
                let children = DirectoryScanner.scanSingleLevel(url: url, depth: parentDepth)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    updateNode(at: url) { node in
                        node.children = children
                    }
                    loadingDirectories.remove(url)
                }
            }
        }

        /// Select a file and load it in the content area.
        public func selectFile(at url: URL) {
            selectedFileURL = url
            try? documentState?.loadFile(at: url)
        }

        // MARK: - Private

        private func expandFirstLevelDirectories() {
            guard let tree else { return }
            for child in tree.children ?? [] where child.isDirectory {
                expandedDirectories.insert(child.url)
                loadChildrenIfNeeded(for: child.url)
            }
        }

        private func startWatching() {
            let subdirectories = firstLevelSubdirectories()
            directoryWatcher.watch(rootURL: rootURL, subdirectories: subdirectories)
        }

        private func firstLevelSubdirectories() -> [URL] {
            guard let tree else { return [] }
            return (tree.children ?? []).filter(\.isDirectory).map(\.url)
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

        // MARK: - Tree Mutation Helpers

        @discardableResult
        private func updateNode(at url: URL, transform: (inout FileTreeNode) -> Void) -> Bool {
            guard var root = tree else { return false }

            if root.url == url {
                transform(&root)
                tree = root
                return true
            }

            if findAndUpdate(at: url, in: &root.children, transform: transform) {
                tree = root
                return true
            }

            return false
        }

        private func findAndUpdate(
            at url: URL,
            in nodes: inout [FileTreeNode]?, // swiftlint:disable:this discouraged_optional_collection
            transform: (inout FileTreeNode) -> Void
        ) -> Bool {
            guard var unwrapped = nodes else { return false }
            for index in unwrapped.indices {
                if unwrapped[index].url == url {
                    transform(&unwrapped[index])
                    nodes = unwrapped
                    return true
                }
                if unwrapped[index].isDirectory,
                   findAndUpdate(at: url, in: &unwrapped[index].children, transform: transform)
                {
                    nodes = unwrapped
                    return true
                }
            }
            return false
        }

        private func findNode(at url: URL, in node: FileTreeNode) -> FileTreeNode? {
            if node.url == url { return node }
            for child in node.children ?? [] {
                if let found = findNode(at: url, in: child) {
                    return found
                }
            }
            return nil
        }

        private nonisolated func depthForURL(_ url: URL, rootURL: URL) -> Int {
            let rootComponents = rootURL.pathComponents
            let urlComponents = url.pathComponents
            return urlComponents.count - rootComponents.count
        }
    }
#endif
