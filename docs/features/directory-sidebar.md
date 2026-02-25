# Directory Sidebar

## Overview

When mkdn is invoked on a folder path (`mkdn ~/docs/`), it displays a Solarized-themed sidebar panel listing the directory's Markdown files in a navigable tree. Users click files to load them in the content area. The sidebar extends mkdn from a single-file viewer into a multi-file navigation experience without adding file management capabilities -- it is strictly a read-only navigation aid.

Single-file invocations (`mkdn file.md`) are unaffected; no sidebar appears.

## User Experience

- **Directory invocation**: `mkdn ~/docs/` opens a window with the sidebar visible and a welcome message ("Select a file from the sidebar") in the content area.
- **File navigation**: Clicking a file in the tree loads it in the viewer. The selected row gets an accent-color highlight; only one file can be selected at a time.
- **Expand/collapse**: Directories show a disclosure chevron. First-level directories are expanded by default; deeper ones start collapsed. Clicking a directory row toggles its state.
- **Sidebar toggle**: Cmd+Shift+L (also in the View menu) hides or shows the sidebar with an animated transition. Content expands to fill the freed space.
- **Resize**: A draggable divider between the sidebar and content area allows width adjustment (160--400 pt range). The cursor changes to a resize indicator on hover.
- **Live updates**: New or deleted Markdown files in the root or first-level subdirectories appear/disappear automatically. Expansion and selection state are preserved across refreshes.
- **Empty directory**: The sidebar shows "No Markdown files found" with a search icon. If files are later added, they appear via live monitoring.
- **Depth truncation**: Scanning stops at 10 levels deep. Directories at the limit show a "..." indicator (non-interactive).

## Architecture

The feature follows the project's Feature-Based MVVM pattern and lives under `Features/Sidebar/`.

**Data flow**: CLI argument parsing (`LaunchContext`) classifies paths as file or directory. The `WindowGroup` routes directory items to `DocumentWindow`, which creates a `DirectoryState` and passes it through the SwiftUI environment. `DirectoryContentView` composes the sidebar alongside `ContentView` in an HStack.

**Core components**:

| Component | Role |
|---|---|
| `DirectoryScanner` | Pure-function recursive scan. Builds a `FileTreeNode` tree filtered to `.md`/`.markdown` files. Prunes empty directories. |
| `FileTreeNode` | Value-type tree node (`Identifiable`, `Hashable`, `Sendable`). URL-based identity for efficient SwiftUI diffing. Carries a `depth` field for indentation and an `isTruncated` flag for depth-limit indicators. |
| `DirectoryWatcher` | Kernel-level filesystem monitoring via `DispatchSource.makeFileSystemObjectSource`. Watches the root directory and each first-level subdirectory with separate file descriptors. Events are bridged to `@MainActor` through `AsyncStream`. |
| `DirectoryState` | Per-window `@Observable` view model. Owns the tree, expansion/selection state, sidebar layout state, and the watcher. Coordinates scan, refresh, and file loading. |

## Implementation Decisions

- **HStack layout, not NavigationSplitView**: The sidebar uses a custom `HStack` composition to maintain consistency with the hidden-title-bar window chrome. `NavigationSplitView` was ruled out because it conflicts with the app's custom window styling.
- **Flat list rendering**: `SidebarView` flattens the recursive tree into a `LazyVStack` of `SidebarRowView` entries based on current expansion state, rather than using recursive SwiftUI views. This keeps scroll performance predictable.
- **Depth-based indentation**: Each `SidebarRowView` computes its leading padding from `node.depth`, giving the flat list visual tree structure.
- **DispatchSource over FSEvents**: `DirectoryWatcher` uses `DispatchSource.makeFileSystemObjectSource` (one per watched directory) rather than FSEvents. This matches the existing `FileWatcher` pattern and provides efficient kernel-level notifications without polling.
- **Watcher scope limited to first level**: v1 watches only the root and its direct subdirectories. Deeper changes require a future enhancement. A 250ms debounce prevents rapid-fire rescans.
- **Observation-based refresh loop**: `DirectoryState` uses `withObservationTracking` on `directoryWatcher.hasChanges` to reactively trigger tree refreshes, avoiding manual KVO or Combine subscriptions.
- **Drag-blocking NSView**: The sidebar divider wraps an `NSView` subclass that returns `mouseDownCanMoveWindow = false`, preventing the window's `isMovableByWindowBackground` from intercepting resize drags.
- **Animation respects Reduce Motion**: The sidebar show/hide transition uses `MotionPreference` to resolve animations, falling back to no animation when the system Reduce Motion preference is enabled.

## Files

**Views** (`mkdn/Features/Sidebar/Views/`):
- `DirectoryContentView.swift` -- HStack wrapper composing sidebar + content area
- `SidebarView.swift` -- Sidebar panel with header, scrollable tree, and empty state
- `SidebarRowView.swift` -- Individual row (file, directory, or truncation indicator)
- `SidebarHeaderView.swift` -- Root directory name header
- `SidebarDivider.swift` -- Draggable divider with drag-blocking NSView
- `SidebarEmptyView.swift` -- Empty-state message

**View Model** (`mkdn/Features/Sidebar/ViewModels/`):
- `DirectoryState.swift` -- Per-window observable state

**Core** (`mkdn/Core/`):
- `DirectoryScanner/DirectoryScanner.swift` -- Recursive scan logic
- `DirectoryScanner/FileTreeNode.swift` -- Tree node value type
- `DirectoryWatcher/DirectoryWatcher.swift` -- Filesystem monitoring

## Dependencies

- **Solarized theme system** (`ThemeColors`, `SolarizedDark`, `SolarizedLight`) -- sidebar colors, accent, and border
- **CLI argument parsing** (`swift-argument-parser`, `FileValidator`, `LaunchContext`) -- directory path handling
- **DocumentState** -- file loading when a sidebar item is selected
- **AnimationConstants / MotionPreference** -- sidebar show/hide animation with Reduce Motion support
- **FileOpenCoordinator** -- `isMarkdownURL()` used by `DirectoryScanner` for extension filtering

## Testing

**Unit tests** (Swift Testing framework, `@testable import mkdnLib`):

- `DirectoryScannerTests` -- Extension filtering (.md/.markdown only), hidden file exclusion, empty directory pruning, sort order (directories first, alphabetical), depth limiting, truncation indicator creation, nonexistent/file path handling, nested structure scanning, depth value correctness.
- `FileTreeNodeTests` -- URL-based identity, equality/inequality, default values, truncation flag, directory children storage, hashable consistency, Set membership.
- `DirectoryStateTests` -- Initial state defaults, sidebar toggle (show/hide/double-toggle), file selection (set/replace/idempotent), expansion state (toggle/multi), static constants (depth=10, width 160--400), sidebar width assignment, watcher initial state.
