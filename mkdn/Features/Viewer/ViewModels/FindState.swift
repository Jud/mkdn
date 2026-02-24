import Foundation

/// Per-window find state backing the custom find bar.
///
/// Holds the search query, visibility, match ranges, and current match
/// index. Performs case-insensitive text search and provides navigation
/// methods with wrap-around. Written by `FindBarView` and `MkdnCommands`
/// (input state) and by the `SelectableTextView` Coordinator (output state).
@MainActor
@Observable
public final class FindState {
    // MARK: - Input State (written by FindBarView and MkdnCommands)

    /// The current search query string.
    public var query = ""

    /// Whether the find bar is visible.
    public var isVisible = false

    /// Index of the currently highlighted match within `matchRanges`.
    public var currentMatchIndex = 0

    // MARK: - Output State (written by Coordinator, read by FindBarView)

    /// Ranges of all matches in the text view's text storage.
    public private(set) var matchRanges: [NSRange] = []

    /// Total number of matches for the current query.
    public var matchCount: Int {
        matchRanges.count
    }

    // MARK: - Init

    public init() {}

    // MARK: - Navigation

    /// Advance to the next match, wrapping from last to first.
    public func nextMatch() {
        guard matchCount > 0 else { return }
        currentMatchIndex = (currentMatchIndex + 1) % matchCount
    }

    /// Return to the previous match, wrapping from first to last.
    public func previousMatch() {
        guard matchCount > 0 else { return }
        currentMatchIndex = (currentMatchIndex - 1 + matchCount) % matchCount
    }

    // MARK: - Lifecycle

    /// Show the find bar.
    public func show() {
        isVisible = true
    }

    /// Dismiss the find bar and clear all find state.
    ///
    /// - Note: Callers that need an animated exit should set `isVisible = false`
    ///   inside `withAnimation` first, then call ``clearSearch()`` outside it.
    ///   Using `dismiss()` directly inside `withAnimation` causes layout churn
    ///   that kills the exit transition.
    public func dismiss() {
        isVisible = false
        clearSearch()
    }

    /// Clear search state without changing visibility.
    public func clearSearch() {
        query = ""
        matchRanges = []
        currentMatchIndex = 0
    }

    /// Populate the find bar with the given selection and show it.
    public func useSelection(_ text: String) {
        isVisible = true
        query = text
    }

    // MARK: - Search

    /// Perform a case-insensitive search for `query` within `text`.
    ///
    /// Updates `matchRanges` with the found ranges and clamps
    /// `currentMatchIndex` to remain within bounds.
    public func performSearch(in text: String) {
        guard !query.isEmpty else {
            matchRanges = []
            currentMatchIndex = 0
            return
        }

        var ranges: [NSRange] = []
        var searchStart = text.startIndex

        while let foundRange = text.range(
            of: query,
            options: .caseInsensitive,
            range: searchStart ..< text.endIndex
        ) {
            ranges.append(NSRange(foundRange, in: text))
            searchStart = foundRange.upperBound
        }

        matchRanges = ranges

        if matchRanges.isEmpty {
            currentMatchIndex = 0
        } else if currentMatchIndex >= matchRanges.count {
            currentMatchIndex = matchRanges.count - 1
        }
    }
}
