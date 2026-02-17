# Development Tasks: Directory Sidebar Navigation

**Feature ID**: directory-sidebar
**Status**: In Progress
**Progress**: 35% (6 of 17 tasks)
**Estimated Effort**: 7 days
**Started**: 2026-02-16

## Overview

Extends mkdn from a single-file viewer into a folder-browsable navigation experience. When invoked with a directory path, mkdn opens a window containing a Solarized-themed sidebar panel showing a filtered tree of Markdown files. Users click files in the sidebar to load them in the content area. The sidebar is toggleable, resizable, and updates via directory watching.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1, T2, T3] - CLI changes, data model, and directory watcher are independent of each other
2. [T4, T5] - Window routing needs no prior tasks but T5 needs T2 (FileTreeNode) and T3 (DirectoryWatcher); T4 needs T1 (LaunchContext changes) for full integration but the LaunchItem type itself is independent
3. [T6, T8] - Sidebar views need T5 (DirectoryState) and T2 (FileTreeNode); menu commands need T5
4. [T7] - Layout integration needs T6 (SidebarView) and T4 (DocumentWindow changes)
5. [T9] - Tests need T2, T3, T5

**Dependencies**:

- T4 -> T1 (data: main.swift consumes LaunchContext changes from T1)
- T5 -> T2 (data: DirectoryState holds FileTreeNode tree from T2)
- T5 -> T3 (data: DirectoryState owns DirectoryWatcher from T3)
- T6 -> T2 (data: SidebarView renders FileTreeNode)
- T6 -> T5 (interface: SidebarView reads DirectoryState)
- T8 -> T5 (interface: MkdnCommands uses FocusedValue for DirectoryState)
- T7 -> T4 (build: DirectoryContentView integrates into DocumentWindow from T4)
- T7 -> T6 (build: DirectoryContentView embeds SidebarView from T6)
- T9 -> [T2, T3, T5] (build: tests import types from these tasks)

**Critical Path**: T2 -> T5 -> T6 -> T7

## Task Breakdown

### Independent Foundation (Group 1)

- [x] **T1**: CLI layer -- argument routing for directory paths `[complexity:medium]`

    **Reference**: [design.md#t1-cli-layer--argument-routing](design.md#t1-cli-layer--argument-routing)

    **Effort**: 5 hours

    **Acceptance Criteria**:

    - [x] `DirectoryValidator` created at `mkdn/Core/CLI/DirectoryValidator.swift` with `validate(path:)` method performing tilde expansion, path resolution, symlink resolution, directory existence check, and readability check
    - [x] `CLIError` extended with `directoryNotFound(resolvedPath:)` and `directoryNotReadable(resolvedPath:reason:)` cases with LocalizedError descriptions and non-zero exit codes
    - [x] `LaunchContext` extended with `directoryURLs` storage and `consumeDirectoryURLs()` drain method
    - [x] `main.swift` updated to detect file vs directory arguments using `FileManager.fileExists(atPath:isDirectory:)`, validate each with the appropriate validator, and set `MKDN_LAUNCH_DIR` env var alongside `MKDN_LAUNCH_FILE`
    - [x] `main.swift` re-launch path reads both `MKDN_LAUNCH_FILE` and `MKDN_LAUNCH_DIR` into `LaunchContext`
    - [x] Argument help text updated to mention directories alongside files

    **Implementation Summary**:

    - **Files**: `mkdn/Core/CLI/DirectoryValidator.swift`, `mkdn/Core/CLI/CLIError.swift`, `mkdn/Core/CLI/LaunchContext.swift`, `mkdn/Core/CLI/FileValidator.swift`, `mkdn/Core/CLI/MkdnCLI.swift`, `mkdnEntry/main.swift`
    - **Approach**: Created DirectoryValidator following FileValidator pattern (reuses FileValidator.resolvePath). Extended CLIError with directory cases. Extended LaunchContext with directoryURLs storage. Updated main.swift to detect file vs directory arguments via FileManager.fileExists(isDirectory:), route to appropriate validator, set MKDN_LAUNCH_DIR env var, and read both env vars on re-launch. Paths with trailing slash that don't exist are routed to DirectoryValidator for proper error messages.
    - **Deviations**: Made FileValidator.resolvePath public (was internal) so main.swift in the mkdn executable target can call it for argument routing. This is a minimal interface change required because main.swift is in a separate target.
    - **Tests**: 27/27 existing CLI tests passing

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

- [x] **T2**: Data model -- FileTreeNode and DirectoryScanner `[complexity:medium]`

    **Reference**: [design.md#t2-data-model--filetreenode--directoryscanner](design.md#t2-data-model--filetreenode--directoryscanner)

    **Effort**: 5 hours

    **Acceptance Criteria**:

    - [x] `FileTreeNode` struct created at `mkdn/Core/DirectoryScanner/FileTreeNode.swift` with `Identifiable`, `Hashable`, `Sendable` conformance and properties: `id` (URL), `name`, `url`, `isDirectory`, `children`, `depth`, `isTruncated`
    - [x] `DirectoryScanner` enum created at `mkdn/Core/DirectoryScanner/DirectoryScanner.swift` with `scan(url:maxDepth:)` pure static function
    - [x] Scanner filters to `.md` and `.markdown` extensions only
    - [x] Scanner excludes hidden files and directories (names starting with `.`)
    - [x] Scanner prunes empty directories (directories whose recursive children contain no Markdown files)
    - [x] Scanner sorts directories first, then files, alphabetically case-insensitive within each group
    - [x] Scanner respects `maxDepth` parameter (default 10) and creates truncation indicator nodes at the limit
    - [x] Scanner returns `nil` for nonexistent or unreadable directories

    **Implementation Summary**:

    - **Files**: `mkdn/Core/DirectoryScanner/FileTreeNode.swift`, `mkdn/Core/DirectoryScanner/DirectoryScanner.swift`
    - **Approach**: FileTreeNode is a recursive value-type struct with URL-based identity. DirectoryScanner is a pure static enum using FileManager.contentsOfDirectory with .skipsHiddenFiles, recursive descent with depth tracking, empty-directory pruning, and directories-first alphabetical sorting. At the depth limit, directories with Markdown content get a truncation indicator child node. Refactored scanChildren into smaller helpers (scanDirectory, truncatedDirectoryNode, isMarkdownFile) to satisfy SwiftLint function body length rule.
    - **Deviations**: None
    - **Tests**: 0 new (T9 handles unit tests); all existing tests pass

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

- [x] **T3**: DirectoryWatcher -- filesystem monitoring `[complexity:medium]`

    **Reference**: [design.md#t3-directorywatcher](design.md#t3-directorywatcher)

    **Effort**: 7 hours

    **Acceptance Criteria**:

    - [x] `DirectoryWatcher` class created at `mkdn/Core/DirectoryWatcher/DirectoryWatcher.swift` with `@MainActor` and `@Observable` annotations
    - [x] Watches root directory and first-level subdirectories using `DispatchSource.makeFileSystemObjectSource` with `O_EVTONLY` file descriptors
    - [x] Event mask includes `.write`, `.rename`, `.delete`, `.link`
    - [x] All sources share a single serial `DispatchQueue`
    - [x] Events bridged to `@MainActor` via `AsyncStream` (following `FileWatcher` pattern)
    - [x] `nonisolated static func installHandlers` pattern used for Swift 6 concurrency compliance
    - [x] `hasChanges` observable property set to `true` on filesystem events
    - [x] `watch(rootURL:subdirectories:)` method starts monitoring
    - [x] `stopWatching()` cancels all sources and closes file descriptors
    - [x] `acknowledge()` resets `hasChanges` to `false`
    - [x] File descriptor cleanup in cancel handlers; `deinit` cancels all sources

    **Implementation Summary**:

    - **Files**: `mkdn/Core/DirectoryWatcher/DirectoryWatcher.swift`
    - **Approach**: Followed FileWatcher pattern with adaptations for multi-directory watching. Uses a single AsyncStream shared across all DispatchSources (one per watched directory). The stream continuation is stored as a property and finished explicitly in stopWatching()/deinit rather than in individual cancel handlers (since multiple sources share one stream). Cancel handlers only close file descriptors. Event mask adds .link (beyond FileWatcher's .write/.rename/.delete) per design spec.
    - **Deviations**: None
    - **Tests**: 0 new (T9 handles unit tests); build succeeds, all existing unit tests pass

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

### Window Routing and State (Group 2)

- [x] **T4**: LaunchItem enum and window routing `[complexity:medium]`

    **Reference**: [design.md#t4-launchitem--window-routing](design.md#t4-launchitem--window-routing)

    **Effort**: 5 hours

    **Acceptance Criteria**:

    - [x] `LaunchItem` enum created at `mkdn/App/LaunchItem.swift` with `.file(URL)` and `.directory(URL)` cases, conforming to `Hashable`, `Codable`, `Sendable`
    - [x] `LaunchItem` has a computed `url` property returning the underlying URL regardless of case
    - [x] `WindowGroup(for: URL.self)` changed to `WindowGroup(for: LaunchItem.self)` in `main.swift`
    - [x] `DocumentWindow` updated to accept `LaunchItem?` instead of `URL?`
    - [x] `consumeLaunchContext()` creates appropriate `LaunchItem` values from `LaunchContext.fileURLs` and `LaunchContext.directoryURLs`
    - [x] Mixed file + directory arguments open separate windows via `openWindow(value:)`
    - [x] Existing single-file behavior preserved (no sidebar when opened with `.file` launch item)

    **Implementation Summary**:

    - **Files**: `mkdn/App/LaunchItem.swift`, `mkdn/App/DocumentWindow.swift`, `mkdnEntry/main.swift`
    - **Approach**: Created LaunchItem enum (Hashable, Codable, Sendable) with .file(URL) and .directory(URL) cases and url accessor. Changed WindowGroup routing from URL.self to LaunchItem.self. Refactored DocumentWindow to accept LaunchItem? with handleLaunch() switch for file/directory/nil cases. consumeLaunchContext() drains both file and directory URLs, opening separate windows with appropriate LaunchItem values. FileOpenCoordinator onChange handler wraps URLs in LaunchItem.file(). Directory launch items currently no-op (T5/T7 will wire DirectoryState).
    - **Deviations**: None
    - **Tests**: All existing tests pass (424 total; 30 pre-existing UI compliance failures unrelated to changes)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

- [x] **T5**: DirectoryState observable and supporting keys `[complexity:medium]`

    **Reference**: [design.md#t5-directorystate](design.md#t5-directorystate)

    **Effort**: 7 hours

    **Acceptance Criteria**:

    - [x] `DirectoryState` class created at `mkdn/Features/Sidebar/ViewModels/DirectoryState.swift` with `@Observable` and `@MainActor` annotations
    - [x] Properties: `rootURL`, `tree` (FileTreeNode?), `expandedDirectories` (Set<URL>), `selectedFileURL` (URL?), `isSidebarVisible` (Bool, default true), `sidebarWidth` (CGFloat, default 240)
    - [x] Static constants: `maxScanDepth` (10), `minSidebarWidth` (160), `maxSidebarWidth` (400)
    - [x] `scan()` method performs initial directory scan via `DirectoryScanner`, populates tree, expands first-level directories by default, starts `DirectoryWatcher`
    - [x] `refresh()` method rescans from disk, preserves expansion state and selection (unless selected file deleted)
    - [x] `toggleSidebar()` flips `isSidebarVisible`
    - [x] `selectFile(at:)` updates `selectedFileURL` and calls `documentState?.loadFile(at:)`
    - [x] Weak reference to `DocumentState` for file loading integration
    - [x] Observes `directoryWatcher.hasChanges` to trigger `refresh()` and restart watcher with updated subdirectory list
    - [x] `FocusedDirectoryStateKey` created at `mkdn/App/FocusedDirectoryStateKey.swift` following `FocusedDocumentStateKey` pattern
    - [x] `DirectoryModeKey` environment key created at `mkdn/App/DirectoryModeKey.swift` with default `false`

    **Implementation Summary**:

    - **Files**: `mkdn/Features/Sidebar/ViewModels/DirectoryState.swift`, `mkdn/App/FocusedDirectoryStateKey.swift`, `mkdn/App/DirectoryModeKey.swift`
    - **Approach**: DirectoryState follows the established Observable/MainActor pattern (DocumentState, FindState). Owns DirectoryWatcher and observes hasChanges via withObservationTracking in a Task loop with 250ms debounce for rapid filesystem events. scan() builds tree via DirectoryScanner, expands first-level directories, starts watcher. refresh() preserves expansion/selection state, clears selection if file deleted, restarts watcher with updated subdirectory list. FocusedDirectoryStateKey follows FocusedDocumentStateKey pattern exactly. DirectoryModeKey provides a lightweight Bool environment key defaulting to false.
    - **Deviations**: None
    - **Tests**: 0 new (T9 handles unit tests); build succeeds, all existing unit tests pass

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

### Sidebar UI (Group 3)

- [x] **T6**: Sidebar views -- tree, rows, header, divider, empty state `[complexity:medium]`

    **Reference**: [design.md#t6-sidebar-views](design.md#t6-sidebar-views)

    **Effort**: 7 hours

    **Acceptance Criteria**:

    - [x] `SidebarView` created at `mkdn/Features/Sidebar/Views/SidebarView.swift` with header, divider, scrollable tree (LazyVStack), and empty-state fallback
    - [x] Tree flattening function converts recursive `FileTreeNode` into a flat list of visible nodes respecting expansion state
    - [x] `SidebarRowView` created at `mkdn/Features/Sidebar/Views/SidebarRowView.swift` with depth-based indentation (`depth * 16 + 8` leading padding), disclosure chevrons for directories, folder/document icons, selection highlight (accent color at 0.2 opacity), and tap handling
    - [x] `SidebarDivider` created at `mkdn/Features/Sidebar/Views/SidebarDivider.swift` with 1pt border color fill, 7pt hit target, drag gesture clamped to min/max sidebar width, and resize cursor on hover
    - [x] `SidebarHeaderView` created at `mkdn/Features/Sidebar/Views/SidebarHeaderView.swift` displaying root directory name with folder icon
    - [x] `SidebarEmptyView` created at `mkdn/Features/Sidebar/Views/SidebarEmptyView.swift` with magnifying glass icon and "No Markdown files found" message
    - [x] All views use `appSettings.theme.colors` for Solarized theming (backgroundSecondary, foreground, foregroundSecondary, accent, border, headingColor)
    - [x] Truncation indicator rows are non-interactive (no tap gesture)
    - [x] File name text uses `.callout` font with single-line truncation (`.middle`)

    **Implementation Summary**:

    - **Files**: `mkdn/Features/Sidebar/Views/SidebarView.swift`, `mkdn/Features/Sidebar/Views/SidebarRowView.swift`, `mkdn/Features/Sidebar/Views/SidebarDivider.swift`, `mkdn/Features/Sidebar/Views/SidebarHeaderView.swift`, `mkdn/Features/Sidebar/Views/SidebarEmptyView.swift`
    - **Approach**: Implemented all 5 sidebar views per design spec. SidebarView uses LazyVStack with tree flattening that walks FileTreeNode recursively respecting expansion state. SidebarRowView splits into 3 variants (directory/file/truncation) for clarity; directory rows toggle expansion, file rows trigger selection, truncation rows are inert. SidebarDivider tracks drag start width for stable resizing. All views read theme colors from AppSettings environment.
    - **Deviations**: SidebarDivider stores dragStartWidth @State to compute absolute width from drag start rather than incremental translation, preventing jitter on rapid drags. SidebarRowView splits into separate computed properties per row type rather than one body with conditionals, for readability and to keep SwiftLint body length in check.
    - **Tests**: 0 new (T9 handles unit tests); build succeeds, 424/424 tests run (30 pre-existing UI compliance failures)

- [ ] **T8**: WelcomeView adaptation and menu commands `[complexity:simple]`

    **Reference**: [design.md#t8-welcomeview--menu-commands](design.md#t8-welcomeview--menu-commands)

    **Effort**: 3 hours

    **Acceptance Criteria**:

    - [ ] `WelcomeView` reads `@Environment(\.isDirectoryMode)` and displays different icon (`sidebar.left` vs `doc.richtext`) and message text ("Select a file from the sidebar to begin reading" vs existing)
    - [ ] Instruction rows hidden in directory mode
    - [ ] Default `isDirectoryMode` is `false` (backward compatible)
    - [ ] `MkdnCommands` gains `@FocusedValue(\.directoryState) private var directoryState`
    - [ ] "Toggle Sidebar" button added to View menu (after `.sidebar`) with `Cmd+Shift+L` keyboard shortcut
    - [ ] "Toggle Sidebar" menu item disabled when `directoryState == nil`
    - [ ] Toggle sidebar action uses `withAnimation(motionAnimation(.gentleSpring))` and calls `directoryState?.toggleSidebar()`

### Layout Integration (Group 4)

- [ ] **T7**: DirectoryContentView and DocumentWindow integration `[complexity:medium]`

    **Reference**: [design.md#t7-directorycontentview--layout-integration](design.md#t7-directorycontentview--layout-integration)

    **Effort**: 5 hours

    **Acceptance Criteria**:

    - [ ] `DirectoryContentView` created at `mkdn/Features/Sidebar/Views/DirectoryContentView.swift` as HStack(spacing: 0) wrapper with sidebar + divider + ContentView
    - [ ] Sidebar visibility animated with `gentleSpring` via `MotionPreference`, using `.move(edge: .leading).combined(with: .opacity)` transition
    - [ ] Animation respects system Reduce Motion preference
    - [ ] Minimum window size set to 600x400
    - [ ] `DocumentWindow` conditionally renders `DirectoryContentView` (when `directoryState` is non-nil) or `ContentView` (when nil)
    - [ ] `DocumentWindow.handleLaunch()` creates `DirectoryState` for `.directory` launch items, sets `dirState.documentState = documentState`, calls `dirState.scan()`
    - [ ] Environment injections: `.environment(directoryState)`, `.environment(\.isDirectoryMode, true)`, `.focusedSceneValue(\.directoryState, directoryState)`
    - [ ] Content area resizes to fill available space when sidebar is hidden

### Unit Tests (Group 5)

- [ ] **T9**: Unit tests for scanner, watcher, state, validator, and launch item `[complexity:medium]`

    **Reference**: [design.md#t9-unit-tests](design.md#t9-unit-tests)

    **Effort**: 7 hours

    **Acceptance Criteria**:

    - [ ] `DirectoryScannerTests` at `mkdnTests/Unit/DirectoryScannerTests.swift`: scans only .md/.markdown, excludes hidden, excludes empty directories, sorts directories-first then files alphabetically, respects depth limit, creates truncation indicator, returns nil for nonexistent, handles empty directory
    - [ ] `FileTreeNodeTests` at `mkdnTests/Unit/FileTreeNodeTests.swift`: identity (URL-based), equality, truncation indicator flag
    - [ ] `DirectoryStateTests` at `mkdnTests/Unit/DirectoryStateTests.swift`: first-level expanded by default, deeper collapsed, toggle expansion, expansion preserved on refresh, select file updates selection, selecting new deselects previous, sidebar toggle flips visibility, sidebar width clamped to min/max, deleted selected file clears on refresh
    - [ ] `DirectoryValidatorTests` at `mkdnTests/Unit/DirectoryValidatorTests.swift`: validates existing directory, resolves relative paths, resolves tilde, rejects nonexistent, rejects file path, handles trailing slash
    - [ ] `LaunchItemTests` at `mkdnTests/Unit/LaunchItemTests.swift`: file case url accessor, directory case url accessor, Codable round-trip for both cases, Hashable equality
    - [ ] All tests use Swift Testing (`@Suite`, `@Test`, `#expect`)
    - [ ] All tests use `@testable import mkdnLib`
    - [ ] Tests using `@Observable` / `@MainActor` types apply `@MainActor` on individual test functions

### User Docs

- [ ] **TD1**: Update index.md -- Quick Reference `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/index.md`

    **Section**: Quick Reference

    **KB Source**: index.md

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Quick Reference section includes paths for DirectoryScanner, DirectoryWatcher, and Features/Sidebar

- [ ] **TD2**: Update architecture.md -- System Overview `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: System Overview

    **KB Source**: architecture.md

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] System Overview diagram includes DirectoryState, SidebarView, LaunchItem, and DirectoryContentView

- [ ] **TD3**: Update architecture.md -- Data Flow `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: Data Flow

    **KB Source**: architecture.md

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Data Flow section documents the directory invocation flow: CLI -> LaunchContext -> WindowGroup -> DirectoryState -> SidebarView -> DocumentState

- [ ] **TD4**: Update modules.md -- App Layer `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: App Layer

    **KB Source**: modules.md

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] App Layer table includes LaunchItem.swift, FocusedDirectoryStateKey.swift, and DirectoryModeKey.swift with descriptions

- [ ] **TD5**: Update modules.md -- Features Layer `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Features Layer

    **KB Source**: modules.md

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Features Layer includes a new Sidebar section with DirectoryState, SidebarView, SidebarRowView, SidebarDivider, SidebarHeaderView, SidebarEmptyView, and DirectoryContentView

- [ ] **TD6**: Update modules.md -- Core Layer `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Core Layer

    **KB Source**: modules.md

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Core Layer includes DirectoryScanner section (FileTreeNode.swift, DirectoryScanner.swift) and DirectoryWatcher section (DirectoryWatcher.swift) and DirectoryValidator.swift in CLI section

- [ ] **TD7**: Update modules.md -- Test Layer `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Test Layer

    **KB Source**: modules.md

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Test Layer includes DirectoryScannerTests, FileTreeNodeTests, DirectoryStateTests, DirectoryValidatorTests, and LaunchItemTests

- [ ] **TD8**: Update patterns.md -- Feature-Based MVVM `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/patterns.md`

    **Section**: Feature-Based MVVM

    **KB Source**: patterns.md

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Feature-Based MVVM section references the Sidebar feature as an additional pattern example alongside Viewer and Editor

## Acceptance Criteria Checklist

### Directory Invocation (FR-1)
- [ ] AC-1.1: `mkdn ~/docs/` opens a window with sidebar visible and directory-mode welcome message
- [ ] AC-1.2: `mkdn ./relative/path/` resolves relative paths correctly
- [ ] AC-1.3: `mkdn /nonexistent/path/` produces meaningful error and exits non-zero
- [ ] AC-1.4: Trailing slash on directory path works identically to without

### Single-File Preserved (FR-2)
- [ ] AC-2.1: `mkdn file.md` opens with no sidebar panel visible
- [ ] AC-2.2: No sidebar toggle shortcut appears/functions without directory association

### Mixed Arguments (FR-3)
- [ ] AC-3.1: `mkdn file.md ~/docs/` opens two independent windows (one with sidebar, one without)
- [ ] AC-3.2: Each window operates independently

### Markdown-Only File Tree (FR-4)
- [ ] AC-4.1: Non-.md/.markdown files excluded from sidebar
- [ ] AC-4.2: Empty directories (no Markdown at any depth within limit) excluded
- [ ] AC-4.3: Hidden files/directories excluded
- [ ] AC-4.4: Sorted directories-first, then files, alphabetically case-insensitive

### File Navigation (FR-5)
- [ ] AC-5.1: Clicking file in sidebar loads and renders it in content area
- [ ] AC-5.2: Selected file row has accent-color background highlight
- [ ] AC-5.3: Single selection only; new selection deselects previous
- [ ] AC-5.4: Content area transitions from welcome to file on first selection

### Directory Expand/Collapse (FR-6)
- [ ] AC-6.1: Clicking directory row toggles expanded/collapsed
- [ ] AC-6.2: Disclosure chevron indicates expanded/collapsed state
- [ ] AC-6.3: First-level directories expanded by default
- [ ] AC-6.4: Deeper directories collapsed by default
- [ ] AC-6.5: Expansion state preserved on tree refresh

### Sidebar Toggle (FR-7)
- [ ] AC-7.1: Cmd+Shift+L toggles sidebar visibility
- [ ] AC-7.2: "Toggle Sidebar" menu item in View menu with shortcut displayed
- [ ] AC-7.3: Menu item disabled when no directory associated
- [ ] AC-7.4: Show/hide transition is animated (follows animation conventions)
- [ ] AC-7.5: Content area resizes to fill when sidebar hidden

### Resizable Sidebar (FR-8)
- [ ] AC-8.1: Draggable divider between sidebar and content
- [ ] AC-8.2: Minimum width constraint enforced
- [ ] AC-8.3: Maximum width constraint enforced
- [ ] AC-8.4: Divider visible as 1pt border line
- [ ] AC-8.5: Cursor changes to resize cursor on divider hover

### Directory-Mode Welcome View (FR-9)
- [ ] AC-9.1: Directory-specific welcome message when no file selected
- [ ] AC-9.2: Message text differs from single-file welcome
- [ ] AC-9.3: Welcome message follows Solarized theming
- [ ] AC-9.4: Welcome transitions to file content on selection

### Directory Watching (FR-10)
- [ ] AC-10.1: New .md in root appears in sidebar
- [ ] AC-10.2: Deleted .md from root disappears
- [ ] AC-10.3: New .md in first-level subdirectory appears
- [ ] AC-10.4: Deleted .md from first-level subdirectory disappears
- [ ] AC-10.5: Changes deeper than first-level not detected (v1)
- [ ] AC-10.6: Selected file remains selected after refresh (unless deleted)
- [ ] AC-10.7: Expansion state preserved across refreshes

### Depth-Limited Scanning (FR-11)
- [ ] AC-11.1: Scanning stops at max depth (~10 levels)
- [ ] AC-11.2: Truncation indicator shown at depth limit
- [ ] AC-11.3: Truncation indicator not clickable

### Empty Directory (FR-12)
- [ ] AC-12.1: Sidebar visible when directory has no Markdown files
- [ ] AC-12.2: "No Markdown files found" message displayed
- [ ] AC-12.3: Content area shows directory-mode welcome
- [ ] AC-12.4: Added Markdown file appears via directory watching

### Solarized Theming (FR-13)
- [ ] AC-13.1: Sidebar background uses backgroundSecondary
- [ ] AC-13.2: Sidebar text uses theme foreground colors
- [ ] AC-13.3: Selection highlight uses theme accent color
- [ ] AC-13.4: Theme cycling (Cmd+T) updates sidebar immediately
- [ ] AC-13.5: Divider uses theme border color

### Tree Row Visual Design (FR-14)
- [ ] AC-14.1: Directory rows have folder icon and disclosure chevron
- [ ] AC-14.2: File rows have document icon
- [ ] AC-14.3: Rows indented by depth level
- [ ] AC-14.4: Typography uses theme text styles
- [ ] AC-14.5: Sidebar header displays root directory name

## Definition of Done

- [ ] All tasks completed
- [ ] All acceptance criteria verified
- [ ] Code reviewed
- [ ] Docs updated
- [ ] SwiftLint passes with no new violations
- [ ] SwiftFormat applied
- [ ] All unit tests pass (`swift test`)
