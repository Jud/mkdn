#if os(macOS)
    import Foundation

    /// Provides git status information for the sidebar.
    ///
    /// Progressive loading: branch name appears immediately (~10ms),
    /// file status badges arrive after the heavier `git status` call (~500ms).
    /// Refresh uses cancel-and-replace — no internal debounce since upstream
    /// FSEvents (300ms) + DirectoryState sleep (250ms) already provides ~550ms.
    @MainActor
    @Observable
    public final class GitStatusProvider {
        // MARK: - State

        /// Current branch name, or nil on detached HEAD / non-git.
        public private(set) var branchName: String?

        /// Per-file git statuses keyed by absolute URL.
        public private(set) var fileStatuses: [URL: GitFileStatus] = [:]

        /// Directory paths (absolute) that contain at least one changed descendant.
        /// Uses path strings to avoid URL trailing-slash comparison issues.
        public private(set) var directoriesWithChanges: Set<String> = []

        /// Whether the sidebar root is inside a git repository.
        public private(set) var isGitRepository = false

        /// User toggle: show only changed files in sidebar.
        public var showOnlyChanged = false

        // MARK: - Computed

        /// Number of changed files (excludes deleted — they have no sidebar row).
        public var changedFileCount: Int {
            fileStatuses.values.reduce(0) { count, status in
                status == .deleted ? count : count + 1
            }
        }

        // MARK: - Private

        @ObservationIgnored private nonisolated(unsafe) var refreshTask: Task<Void, Never>?
        @ObservationIgnored private var repoRoot: URL?
        @ObservationIgnored private var sidebarRoot: URL?

        // MARK: - Public API

        /// Detect the git repo root and perform initial status fetch.
        ///
        /// Fetches branch name first (fast ~10ms) for progressive loading,
        /// then kicks off the heavier status refresh.
        public func configure(sidebarRoot: URL) {
            refreshTask?.cancel()
            self.sidebarRoot = sidebarRoot
            showOnlyChanged = false
            branchName = nil

            fileStatuses = [:]
            directoriesWithChanges = []

            refreshTask = Task { @MainActor [weak self] in
                guard let self else { return }
                guard !Task.isCancelled else { return }

                let root = await GitProcessRunner.repoRoot(for: sidebarRoot)
                guard !Task.isCancelled else { return }

                repoRoot = root
                isGitRepository = root != nil

                guard root != nil else { return }

                // Fast: branch name appears immediately
                let branch = await GitProcessRunner.branchName(in: sidebarRoot)
                guard !Task.isCancelled else { return }

                branchName = branch

                // Heavier: full status
                await performRefresh()
            }
        }

        /// Cancel current refresh and start a new one.
        public func refresh() {
            guard isGitRepository else { return }
            refreshTask?.cancel()
            refreshTask = Task { @MainActor [weak self] in
                await self?.performRefresh()
            }
        }

        /// O(1) lookup for a file's git status.
        public func status(for url: URL) -> GitFileStatus? {
            fileStatuses[url]
        }

        /// O(1) check whether a directory has any changed descendants.
        public func hasChangedDescendants(under url: URL) -> Bool {
            directoriesWithChanges.contains(url.path)
        }

        // MARK: - Internal (for testing)

        /// Apply pre-parsed statuses without hitting git.
        func applyStatuses(
            _ statuses: [String: GitFileStatus],
            repoRoot: URL,
            sidebarRoot: URL
        ) {
            var fileMap: [URL: GitFileStatus] = [:]
            var dirSet: Set<String> = []
            let sidebarPath = sidebarRoot.path

            for (repoRelativePath, status) in statuses {
                let absoluteURL = repoRoot.appendingPathComponent(repoRelativePath)
                fileMap[absoluteURL] = status

                // Walk ancestors up to (but not including) sidebarRoot
                var parent = absoluteURL.deletingLastPathComponent()
                var parentPath = parent.path
                while parentPath.count > sidebarPath.count {
                    if !dirSet.insert(parentPath).inserted { break } // already visited
                    parent = parent.deletingLastPathComponent()
                    parentPath = parent.path
                }
            }

            fileStatuses = fileMap
            directoriesWithChanges = dirSet
        }

        // MARK: - Private

        private func performRefresh() async {
            guard let repoRoot, let sidebarRoot else { return }
            guard !Task.isCancelled else { return }

            async let branchResult = GitProcessRunner.branchName(in: sidebarRoot)
            async let statusResult: Data? = try? GitProcessRunner.status(in: sidebarRoot)

            let branch = await branchResult
            let statusData = await statusResult

            guard !Task.isCancelled else { return }

            branchName = branch

            if let data = statusData {
                let parsed = GitStatusParser.parse(data)
                applyStatuses(parsed, repoRoot: repoRoot, sidebarRoot: sidebarRoot)
            }
        }
    }
#endif
