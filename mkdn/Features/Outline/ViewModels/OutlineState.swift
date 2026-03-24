#if os(macOS)
    import Foundation

    /// Per-window observable state for the document outline navigator.
    ///
    /// Manages heading tree data, scroll-spy output, HUD visibility,
    /// fuzzy filtering, and keyboard selection. Follows the `FindState`
    /// pattern: `@MainActor @Observable`, created as `@State` in
    /// `DocumentWindow`, injected via `.environment()`.
    @MainActor
    @Observable
    public final class OutlineState {
        // MARK: - Heading Data

        /// Tree of headings extracted from the document's indexed blocks.
        public private(set) var headingTree: [HeadingNode] = []

        /// Pre-flattened depth-first traversal of `headingTree`.
        public private(set) var flatHeadings: [HeadingNode] = []

        // MARK: - Scroll-Spy Output

        /// Block index of the heading currently at or above the viewport top.
        public private(set) var currentHeadingIndex: Int?

        /// Ancestor chain from root to the current heading.
        public private(set) var breadcrumbPath: [HeadingNode] = []

        // MARK: - HUD State

        /// Whether the outline HUD is visible.
        public var isHUDVisible = false

        /// The current fuzzy filter query string.
        public var filterQuery = ""

        /// Index of the selected heading in `filteredHeadings`.
        public var selectedIndex = 0

        // MARK: - Breadcrumb Visibility

        /// Whether the breadcrumb bar should be visible (viewport past first heading).
        public private(set) var isBreadcrumbVisible = false

        // MARK: - Filtering (Cached)

        /// Headings filtered by the current `filterQuery`, cached for performance.
        ///
        /// Updated via `applyFilter()`. If the query is empty, contains all
        /// `flatHeadings`. Otherwise, contains fuzzy-matched headings sorted
        /// by score descending, then by original order for ties.
        public private(set) var filteredHeadings: [HeadingNode] = []

        // MARK: - Scroll Target

        /// Block index to scroll to after heading selection; consumed by the Coordinator.
        public var pendingScrollTarget: Int?

        // MARK: - Init

        public init() {}

        // MARK: - Heading Updates

        /// Rebuild the heading tree from the current document's indexed blocks.
        ///
        /// Called by `MarkdownPreviewView` whenever the rendered blocks change.
        public func updateHeadings(from blocks: [IndexedBlock]) {
            headingTree = HeadingTreeBuilder.buildTree(from: blocks)
            flatHeadings = HeadingTreeBuilder.flattenTree(headingTree)
            applyFilter()

            if headingTree.isEmpty {
                isBreadcrumbVisible = false
                isHUDVisible = false
                currentHeadingIndex = nil
                breadcrumbPath = []
            }
        }

        // MARK: - Scroll-Spy

        /// Update the current scroll position for scroll-spy tracking.
        ///
        /// Sets `currentHeadingIndex` to the last heading whose `blockIndex`
        /// is at or before `currentBlockIndex`. Updates `breadcrumbPath` and
        /// `isBreadcrumbVisible` accordingly.
        public func updateScrollPosition(currentBlockIndex: Int) {
            guard !flatHeadings.isEmpty else {
                currentHeadingIndex = nil
                breadcrumbPath = []
                isBreadcrumbVisible = false
                return
            }

            // If before the first heading, hide breadcrumb.
            guard let firstHeading = flatHeadings.first,
                  currentBlockIndex >= firstHeading.blockIndex
            else {
                currentHeadingIndex = nil
                breadcrumbPath = []
                isBreadcrumbVisible = false
                return
            }

            // Find the last heading at or before the current block index.
            let heading = flatHeadings.last { $0.blockIndex <= currentBlockIndex }
            currentHeadingIndex = heading?.blockIndex
            breadcrumbPath = HeadingTreeBuilder.breadcrumbPath(
                to: currentBlockIndex,
                in: headingTree
            )
            isBreadcrumbVisible = currentHeadingIndex != nil
        }

        // MARK: - HUD Lifecycle

        /// Toggle HUD visibility: show if hidden, dismiss if visible.
        public func toggleHUD() {
            if isHUDVisible {
                dismissHUD()
            } else {
                showHUD()
            }
        }

        /// Show the outline HUD, resetting filter and auto-selecting the current heading.
        public func showHUD() {
            isHUDVisible = true
            filterQuery = ""
            applyFilter()

            // Auto-select the current heading in the filtered list.
            if let current = currentHeadingIndex {
                if let matchIndex = filteredHeadings.firstIndex(where: { $0.blockIndex == current }) {
                    selectedIndex = matchIndex
                } else {
                    selectedIndex = 0
                }
            } else {
                selectedIndex = 0
            }
        }

        /// Dismiss the outline HUD and clear the filter query.
        public func dismissHUD() {
            isHUDVisible = false
            filterQuery = ""
            applyFilter()
        }

        // MARK: - Navigation

        /// Scroll to the heading at `selectedIndex` without closing the HUD.
        ///
        /// - Returns: The `blockIndex` of the selected heading, or `nil`
        ///   if `filteredHeadings` is empty.
        public func selectAndNavigate() -> Int? {
            let filtered = filteredHeadings
            guard !filtered.isEmpty else { return nil }
            let clampedIndex = min(selectedIndex, filtered.count - 1)
            let blockIndex = filtered[clampedIndex].blockIndex
            pendingScrollTarget = blockIndex
            return blockIndex
        }

        /// Move selection up, wrapping from first to last.
        public func moveSelectionUp() {
            let count = filteredHeadings.count
            guard count > 0 else { return }
            selectedIndex = (selectedIndex - 1 + count) % count
        }

        /// Move selection down, wrapping from last to first.
        public func moveSelectionDown() {
            let count = filteredHeadings.count
            guard count > 0 else { return }
            selectedIndex = (selectedIndex + 1) % count
        }

        // MARK: - Filtering

        /// Recompute `filteredHeadings` from the current `filterQuery` and
        /// clamp `selectedIndex` to the valid range.
        ///
        /// Call this after mutating `filterQuery`, `flatHeadings`, or any
        /// state that affects the filtered heading list.
        public func applyFilter() {
            if filterQuery.isEmpty {
                filteredHeadings = flatHeadings
            } else {
                let queryChars = Array(filterQuery.lowercased())
                var scored: [(node: HeadingNode, score: Int, originalIndex: Int)] = []

                for (originalIndex, node) in flatHeadings.enumerated() {
                    if let score = fuzzyScore(query: queryChars, target: node.title.lowercased()) {
                        scored.append((node, score, originalIndex))
                    }
                }

                scored.sort { lhs, rhs in
                    if lhs.score != rhs.score {
                        return lhs.score > rhs.score
                    }
                    return lhs.originalIndex < rhs.originalIndex
                }

                filteredHeadings = scored.map(\.node)
            }

            // Clamp selectedIndex to valid range.
            if filteredHeadings.isEmpty {
                selectedIndex = 0
            } else if selectedIndex >= filteredHeadings.count {
                selectedIndex = filteredHeadings.count - 1
            }
        }

        // MARK: - Private Helpers

        /// Compute a fuzzy match score for the query against the target.
        ///
        /// Returns `nil` if the query does not match. Scoring: +2 for
        /// consecutive character matches, +1 for word-boundary matches
        /// (character after space, dash, or at string start), +0 otherwise.
        private func fuzzyScore(query: [Character], target: String) -> Int? {
            let targetChars = Array(target)
            var score = 0
            var targetIndex = 0
            var lastMatchIndex = -2 // -2 so first match is never consecutive

            for queryChar in query {
                var found = false
                while targetIndex < targetChars.count {
                    if targetChars[targetIndex] == queryChar {
                        // Consecutive match bonus.
                        if targetIndex == lastMatchIndex + 1 {
                            score += 2
                        }
                        // Word-boundary bonus.
                        else if targetIndex == 0 ||
                            targetChars[targetIndex - 1] == " " ||
                            targetChars[targetIndex - 1] == "-"
                        {
                            score += 1
                        }
                        lastMatchIndex = targetIndex
                        targetIndex += 1
                        found = true
                        break
                    }
                    targetIndex += 1
                }
                if !found { return nil }
            }
            return score
        }
    }
#endif
