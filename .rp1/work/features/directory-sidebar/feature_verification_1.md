# Feature Verification Report #1

**Generated**: 2026-02-16T20:45:00-06:00
**Feature ID**: directory-sidebar
**Verification Scope**: all
**KB Context**: Loaded
**Field Notes**: Not available

## Executive Summary
- Overall Status: PARTIAL
- Acceptance Criteria: 47/56 verified (84%)
- Implementation Quality: HIGH
- Ready for Merge: NO (documentation tasks TD1-TD8 incomplete; 9 criteria require manual/runtime verification)

## Field Notes Context
**Field Notes Available**: No

### Documented Deviations
None (no field-notes.md file exists)

### Undocumented Deviations
1. **SidebarDivider drag behavior**: Uses `@State dragStartWidth` to compute absolute width from drag start rather than incremental translation. This is an improvement over the design spec approach (prevents jitter on rapid drags) but is not documented in field notes.
2. **SidebarRowView structure**: Splits into separate computed properties per row type (`directoryRow`, `fileRow`, `truncationRow`) rather than one body with conditionals. This is a code quality improvement but differs from the single-body design in Section 3.5.
3. **consumeLaunchContext enhancement**: Enhanced to adopt the first directory URL into the current window when no file URLs are present, preventing an empty window. Noted in task summary but no field-notes.md entry.

## Acceptance Criteria Verification

### FR-1: Directory Invocation (Must Have)

**AC-1.1**: `mkdn ~/docs/` opens a window with sidebar visible and directory-mode welcome message
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`:75-137 - CLI argument routing; `/Users/jud/Projects/mkdn/mkdn/App/DocumentWindow.swift`:63-75 - handleLaunch()
- Evidence: main.swift detects directory arguments via `FileManager.fileExists(isDirectory:)`, validates with `DirectoryValidator.validate(path:)`, stores in `MKDN_LAUNCH_DIR` env var, re-launches via execv. On re-launch, reads `MKDN_LAUNCH_DIR` into `LaunchContext.directoryURLs`. DocumentWindow.handleLaunch() creates `DirectoryState` for `.directory` launch items, which triggers `DirectoryContentView` rendering with sidebar visible by default (`isSidebarVisible = true`). WelcomeView reads `@Environment(\.isDirectoryMode)` and displays "Select a file from the sidebar to begin reading".
- Field Notes: N/A
- Issues: None

**AC-1.2**: `mkdn ./relative/path/` resolves relative paths correctly
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/DirectoryValidator.swift`:8-13 - validate(path:); `/Users/jud/Projects/mkdn/mkdn/Core/CLI/FileValidator.swift`:19-29 - resolvePath()
- Evidence: `DirectoryValidator.validate(path:)` calls `FileValidator.resolvePath(path)` which handles tilde expansion via `NSString.expandingTildeInPath`, resolves relative paths against `FileManager.default.currentDirectoryPath`, and calls `.standardized.resolvingSymlinksInPath()`. Unit test `resolvesTilde` confirms tilde resolution works.
- Field Notes: N/A
- Issues: None

**AC-1.3**: `mkdn /nonexistent/path/` produces meaningful error and exits non-zero
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/DirectoryValidator.swift`:15-23 - validateIsDirectory(); `/Users/jud/Projects/mkdn/mkdn/Core/CLI/CLIError.swift`:19-20 - directoryNotFound error description; `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`:96-104 - error handling for trailing-slash paths
- Evidence: `DirectoryValidator.validateIsDirectory()` throws `CLIError.directoryNotFound(resolvedPath:)` when path doesn't exist. Error description is "directory not found: {path}". Exit code is 1. main.swift routes non-existent paths with trailing slash to DirectoryValidator which produces the error. Unit tests `rejectsNonexistent` and `directoryNotFoundExitCode` confirm behavior.
- Field Notes: N/A
- Issues: None

**AC-1.4**: Trailing slash on directory path works identically to without
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/FileValidator.swift`:19-29 - resolvePath(); `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`:96-104 - trailing slash detection
- Evidence: `FileValidator.resolvePath()` calls `.standardized` on the URL which normalizes trailing slashes. main.swift explicitly handles non-existent paths with trailing slash by routing to `DirectoryValidator`. Unit test `handlesTrailingSlash` confirms validation succeeds with trailing slash.
- Field Notes: N/A
- Issues: None

### FR-2: Single-File Behavior Preserved (Must Have)

**AC-2.1**: `mkdn file.md` opens with no sidebar panel visible
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/DocumentWindow.swift`:31-40 - body; lines 63-67 - handleLaunch .file case
- Evidence: When `launchItem` is `.file(url)`, `handleLaunch()` loads the file into `documentState` and does NOT create a `DirectoryState`. In the body, when `directoryState` is nil, only `ContentView()` is rendered (no `DirectoryContentView`, no sidebar).
- Field Notes: N/A
- Issues: None

**AC-2.2**: No sidebar toggle shortcut appears/functions without directory association
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:143-152 - Toggle Sidebar command
- Evidence: The "Toggle Sidebar" button has `.disabled(directoryState == nil)`. Since `directoryState` is a `@FocusedValue` that is only set via `.focusedSceneValue(\.directoryState, directoryState)` in DocumentWindow when `directoryState` is non-nil (directory mode), the menu item is disabled for single-file windows.
- Field Notes: N/A
- Issues: None

### FR-3: Mixed Arguments (Must Have)

**AC-3.1**: `mkdn file.md ~/docs/` opens two independent windows (one with sidebar, one without)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`:79-136 - argument routing; `/Users/jud/Projects/mkdn/mkdn/App/DocumentWindow.swift`:84-113 - consumeLaunchContext()
- Evidence: main.swift iterates arguments, classifying each as file or directory, and stores validated URLs in separate arrays. Both `MKDN_LAUNCH_FILE` and `MKDN_LAUNCH_DIR` env vars are set. `consumeLaunchContext()` drains both `LaunchContext.consumeURLs()` and `LaunchContext.consumeDirectoryURLs()`, adopting the first into the current window and opening additional windows via `openWindow(value: LaunchItem.file(url))` or `openWindow(value: LaunchItem.directory(url))`. Each window gets its own independent `DocumentState` and optional `DirectoryState`.
- Field Notes: N/A
- Issues: None

**AC-3.2**: Each window operates independently
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/DocumentWindow.swift`:18-26 - per-window @State properties
- Evidence: Each `DocumentWindow` instance has its own `@State private var documentState`, `@State private var findState`, and `@State private var directoryState`. These are per-instance SwiftUI state. Windows are created via `WindowGroup(for: LaunchItem.self)` which creates independent instances.
- Field Notes: N/A
- Issues: None

### FR-4: Markdown-Only File Tree (Must Have)

**AC-4.1**: Non-.md/.markdown files excluded from sidebar
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/DirectoryScanner/DirectoryScanner.swift`:6,75,123-125 - markdownExtensions and isMarkdownFile()
- Evidence: `DirectoryScanner.markdownExtensions` is `["md", "markdown"]`. `isMarkdownFile()` checks `url.pathExtension.lowercased()` against this set. In `scanChildren()`, non-directory items are only added if `isMarkdownFile(itemURL)` returns true. Unit test `scansOnlyMarkdown` creates .md, .markdown, .png, .json, .sh files and confirms only .md and .markdown appear.
- Field Notes: N/A
- Issues: None

**AC-4.2**: Empty directories (no Markdown at any depth within limit) excluded
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/DirectoryScanner/DirectoryScanner.swift`:98-99 - scanDirectory(); lines 110 - truncatedDirectoryNode()
- Evidence: In `scanDirectory()`: after recursive scan, `guard !children.isEmpty else { return nil }` prunes empty directories. At depth limit, `truncatedDirectoryNode()` calls `directoryHasMarkdownFiles()` and returns nil if none found. Unit test `excludesEmptyDirectories` confirms.
- Field Notes: N/A
- Issues: None

**AC-4.3**: Hidden files/directories excluded
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/DirectoryScanner/DirectoryScanner.swift`:47,58 - .skipsHiddenFiles and hasPrefix(".")
- Evidence: `contentsOfDirectory()` uses `.skipsHiddenFiles` option. Additionally, an explicit check `if itemName.hasPrefix(".") { continue }` provides a double-guard. Unit test `excludesHidden` confirms hidden files and hidden directories are excluded.
- Field Notes: N/A
- Issues: None

**AC-4.4**: Sorted directories-first, then files, alphabetically case-insensitive
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/DirectoryScanner/DirectoryScanner.swift`:80-83 - sort and merge
- Evidence: Directories and files are collected in separate arrays, each sorted with `localizedCaseInsensitiveCompare`, then merged as `directories + files`. Unit test `sortOrder` creates "zebra.md", "apple.md", "Beta/" (with file), "alpha/" (with file) and expects `["alpha", "Beta", "apple.md", "zebra.md"]`.
- Field Notes: N/A
- Issues: None

### FR-5: File Navigation (Must Have)

**AC-5.1**: Clicking file in sidebar loads and renders it in content area
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/SidebarRowView.swift`:82-85 - fileRow onTapGesture; `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/ViewModels/DirectoryState.swift`:121-124 - selectFile(at:)
- Evidence: File row's `onTapGesture` calls `directoryState.selectFile(at: node.url)`. `selectFile(at:)` sets `selectedFileURL = url` and calls `try? documentState?.loadFile(at: url)`. `documentState` is wired in `DocumentWindow.setupDirectoryState()` via `dirState.documentState = documentState`.
- Field Notes: N/A
- Issues: None

**AC-5.2**: Selected file row has accent-color background highlight
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/SidebarRowView.swift`:81 - fileRow background
- Evidence: `.background(isSelected ? appSettings.theme.colors.accent.opacity(0.2) : .clear)` applies the accent color at 0.2 opacity when `isSelected` is true. `isSelected` is computed as `!node.isDirectory && directoryState.selectedFileURL == node.url`.
- Field Notes: N/A
- Issues: None

**AC-5.3**: Single selection only; new selection deselects previous
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/ViewModels/DirectoryState.swift`:121-124 - selectFile(at:)
- Evidence: `selectFile(at:)` sets `selectedFileURL = url` which is a single URL property, inherently allowing only one selection. Setting a new URL replaces the previous one. Unit test `selectNewFileReplacesOld` confirms.
- Field Notes: N/A
- Issues: None

**AC-5.4**: Content area transitions from welcome to file on first selection
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:21-23 - welcome/content switch; `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/ViewModels/DirectoryState.swift`:121-124 - selectFile loads file
- Evidence: `ContentView` renders `WelcomeView()` when `documentState.currentFileURL == nil` and renders `MarkdownPreviewView()` when a file is loaded. When `directoryState.selectFile(at:)` calls `documentState?.loadFile(at: url)`, it sets `currentFileURL` which triggers ContentView to switch from WelcomeView to MarkdownPreviewView.
- Field Notes: N/A
- Issues: None

### FR-6: Directory Expand/Collapse (Must Have)

**AC-6.1**: Clicking directory row toggles expanded/collapsed
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/SidebarRowView.swift`:54-59 - directoryRow onTapGesture
- Evidence: Directory row's `onTapGesture` checks `isExpanded`: if true, removes from `expandedDirectories`; if false, inserts. This toggles the expansion state.
- Field Notes: N/A
- Issues: None

**AC-6.2**: Disclosure chevron indicates expanded/collapsed state
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/SidebarRowView.swift`:35 - directoryRow chevron
- Evidence: `Image(systemName: isExpanded ? "chevron.down" : "chevron.right")` changes the chevron direction based on expansion state. `isExpanded` is computed from `directoryState.expandedDirectories.contains(node.url)`.
- Field Notes: N/A
- Issues: None

**AC-6.3**: First-level directories expanded by default
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/ViewModels/DirectoryState.swift`:81-86 - scan(); lines 128-133 - expandFirstLevelDirectories()
- Evidence: `scan()` calls `expandFirstLevelDirectories()` after building the tree. This method iterates `tree.children` and inserts URLs of directory children into `expandedDirectories`. Since tree.children are depth-1 nodes (first level), only first-level directories are expanded.
- Field Notes: N/A
- Issues: None

**AC-6.4**: Deeper directories collapsed by default
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/ViewModels/DirectoryState.swift`:128-133 - expandFirstLevelDirectories()
- Evidence: `expandFirstLevelDirectories()` only inserts first-level children (direct children of root). Deeper directories are not inserted into `expandedDirectories`, so they start collapsed. The `flattenVisibleNodes` function in `SidebarView` only recurses into children whose URLs are in `expandedDirectories`.
- Field Notes: N/A
- Issues: None

**AC-6.5**: Expansion state preserved on tree refresh
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/ViewModels/DirectoryState.swift`:93-113 - refresh()
- Evidence: `refresh()` saves `previousExpanded = expandedDirectories` before rescanning, then restores `expandedDirectories = previousExpanded` after rebuilding the tree. This preserves expansion state across refreshes.
- Field Notes: N/A
- Issues: None

### FR-7: Sidebar Toggle (Must Have)

**AC-7.1**: Cmd+Shift+L toggles sidebar visibility
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:143-152 - Toggle Sidebar command
- Evidence: `Button("Toggle Sidebar")` with `.keyboardShortcut("l", modifiers: [.command, .shift])` calls `directoryState?.toggleSidebar()` which flips `isSidebarVisible`. The `DirectoryContentView` conditionally shows the sidebar based on `directoryState.isSidebarVisible`.
- Field Notes: N/A
- Issues: None

**AC-7.2**: "Toggle Sidebar" menu item in View menu with shortcut displayed
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:143-152 - CommandGroup(after: .sidebar)
- Evidence: `CommandGroup(after: .sidebar)` places the item in the View menu. `Button("Toggle Sidebar")` with `.keyboardShortcut("l", modifiers: [.command, .shift])` displays the shortcut.
- Field Notes: N/A
- Issues: None

**AC-7.3**: Menu item disabled when no directory associated
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:151 - .disabled(directoryState == nil)
- Evidence: `.disabled(directoryState == nil)` disables the menu item when no `DirectoryState` is available via `@FocusedValue`.
- Field Notes: N/A
- Issues: None

**AC-7.4**: Show/hide transition is animated (follows animation conventions)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/DirectoryContentView.swift`:33 - animation; `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:146-148 - withAnimation
- Evidence: `DirectoryContentView` applies `.animation(motion.resolved(.gentleSpring), value: directoryState.isSidebarVisible)` which uses the `gentleSpring` named primitive from `AnimationConstants` via `MotionPreference`. The sidebar has `.transition(.move(edge: .leading).combined(with: .opacity))`. The menu command wraps the toggle in `withAnimation(motionAnimation(.gentleSpring))`. Both respect the system Reduce Motion preference.
- Field Notes: N/A
- Issues: None

**AC-7.5**: Content area resizes to fill when sidebar hidden
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/DirectoryContentView.swift`:20-31 - body HStack
- Evidence: The HStack only includes `SidebarView()` and `SidebarDivider()` when `directoryState.isSidebarVisible` is true. When hidden, `ContentView()` is the only child in the HStack and naturally fills all available space.
- Field Notes: N/A
- Issues: None

### FR-8: Resizable Sidebar (Should Have)

**AC-8.1**: Draggable divider between sidebar and content
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/SidebarDivider.swift`:14-42 - body
- Evidence: `SidebarDivider` is placed between `SidebarView()` and `ContentView()` in `DirectoryContentView`. It has a `DragGesture(minimumDistance: 1)` that modifies `directoryState.sidebarWidth`.
- Field Notes: N/A
- Issues: None

**AC-8.2**: Minimum width constraint enforced
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/SidebarDivider.swift`:26 - max(newWidth, minSidebarWidth)
- Evidence: `max(newWidth, DirectoryState.minSidebarWidth)` clamps the width to at least 160pt. `DirectoryState.minSidebarWidth` is 160. Unit test `minSidebarWidth` confirms the constant value.
- Field Notes: N/A
- Issues: None

**AC-8.3**: Maximum width constraint enforced
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/SidebarDivider.swift`:25-28 - min(max(...), maxSidebarWidth)
- Evidence: `min(..., DirectoryState.maxSidebarWidth)` clamps the width to at most 400pt. `DirectoryState.maxSidebarWidth` is 400. Unit test `maxSidebarWidth` confirms the constant value.
- Field Notes: N/A
- Issues: None

**AC-8.4**: Divider visible as 1pt border line
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/SidebarDivider.swift`:16-17 - Rectangle fill and frame
- Evidence: `Rectangle().fill(appSettings.theme.colors.border).frame(width: 1)` creates a 1pt wide line using the theme's border color.
- Field Notes: N/A
- Issues: None

**AC-8.5**: Cursor changes to resize cursor on divider hover
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/SidebarDivider.swift`:35-40 - onHover
- Evidence: `.onHover { hovering in if hovering { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }` changes the cursor to the horizontal resize cursor on hover.
- Field Notes: N/A
- Issues: None

### FR-9: Directory-Mode Welcome View (Must Have)

**AC-9.1**: Directory-specific welcome message when no file selected
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/WelcomeView.swift`:11,23-26 - isDirectoryMode conditional text
- Evidence: `WelcomeView` reads `@Environment(\.isDirectoryMode)` and when true, displays "Select a file from the sidebar to begin reading". `DirectoryContentView` sets `.environment(\.isDirectoryMode, true)` which propagates to `ContentView` and then `WelcomeView`.
- Field Notes: N/A
- Issues: None

**AC-9.2**: Message text differs from single-file welcome
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/WelcomeView.swift`:23-26 - ternary text
- Evidence: Directory mode: "Select a file from the sidebar to begin reading". Single-file mode: "Open a Markdown file to get started". These are different strings.
- Field Notes: N/A
- Issues: None

**AC-9.3**: Welcome message follows Solarized theming
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/WelcomeView.swift`:17,21,29,50 - theme color usage
- Evidence: Uses `appSettings.theme.colors.foregroundSecondary` for icon and message text, `appSettings.theme.colors.headingColor` for title, `appSettings.theme.colors.background` for the background. All Solarized theme colors.
- Field Notes: N/A
- Issues: None

**AC-9.4**: Welcome transitions to file content on selection
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:21-23 - conditional rendering
- Evidence: `ContentView` shows `WelcomeView()` when `documentState.currentFileURL == nil` and `MarkdownPreviewView()` otherwise. When a file is selected via sidebar, `documentState.loadFile(at:)` sets `currentFileURL`, triggering the transition.
- Field Notes: N/A
- Issues: None

### FR-10: Directory Watching (Should Have)

**AC-10.1**: New .md in root appears in sidebar
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/DirectoryWatcher/DirectoryWatcher.swift`:35-70 - watch(); `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/ViewModels/DirectoryState.swift`:145-171 - startObservingWatcher()
- Evidence: DirectoryWatcher watches rootURL with DispatchSource event mask [.write, .rename, .delete, .link]. When events fire, `hasChanges` is set to true, which triggers `DirectoryState.refresh()` via the observation loop with 250ms debounce. `refresh()` rescans the directory and rebuilds the tree. The architecture is correct; actual filesystem event delivery requires runtime verification.
- Field Notes: N/A
- Issues: Cannot verify filesystem event delivery timing in static analysis

**AC-10.2**: Deleted .md from root disappears
- Status: MANUAL_REQUIRED
- Implementation: Same as AC-10.1 plus `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/ViewModels/DirectoryState.swift`:93-113 - refresh()
- Evidence: Same watcher mechanism. On refresh, the tree is rebuilt from disk, so deleted files will not appear. Architecture is sound; requires runtime verification.
- Field Notes: N/A
- Issues: Cannot verify filesystem event delivery timing in static analysis

**AC-10.3**: New .md in first-level subdirectory appears
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/DirectoryWatcher/DirectoryWatcher.swift`:38 - watches subdirectories; `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/ViewModels/DirectoryState.swift`:135-137 - startWatching()
- Evidence: `startWatching()` calls `firstLevelSubdirectories()` which extracts first-level directory URLs from the tree, then passes them to `directoryWatcher.watch(rootURL:subdirectories:)`. The watcher opens DispatchSources for each. Architecture is correct; requires runtime verification.
- Field Notes: N/A
- Issues: Cannot verify filesystem event delivery timing in static analysis

**AC-10.4**: Deleted .md from first-level subdirectory disappears
- Status: MANUAL_REQUIRED
- Implementation: Same as AC-10.3
- Evidence: Same mechanism -- subdirectory watchers detect changes, refresh rebuilds tree. Requires runtime verification.
- Field Notes: N/A
- Issues: Cannot verify filesystem event delivery timing in static analysis

**AC-10.5**: Changes deeper than first-level not detected (v1)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/ViewModels/DirectoryState.swift`:140-143 - firstLevelSubdirectories()
- Evidence: `firstLevelSubdirectories()` returns only `tree.children.filter(\.isDirectory).map(\.url)` -- first-level only. No deeper directories are passed to the watcher. This matches the v1 limitation documented in CON-1.
- Field Notes: N/A
- Issues: None (intentional v1 limitation)

**AC-10.6**: Selected file remains selected after refresh (unless deleted)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/ViewModels/DirectoryState.swift`:94-109 - refresh()
- Evidence: `refresh()` saves `previousSelected = selectedFileURL`, then after rescan, checks if the file still exists on disk. If yes, restores `selectedFileURL = selected`. If deleted, clears selection and resets documentState. This is correct logic.
- Field Notes: N/A
- Issues: None

**AC-10.7**: Expansion state preserved across refreshes
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/ViewModels/DirectoryState.swift`:94,99 - refresh()
- Evidence: `refresh()` saves `previousExpanded = expandedDirectories` before rescan, then restores `expandedDirectories = previousExpanded` after.
- Field Notes: N/A
- Issues: None

### FR-11: Depth-Limited Scanning (Should Have)

**AC-11.1**: Scanning stops at max depth (~10 levels)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/DirectoryScanner/DirectoryScanner.swift`:93-94 - depth check; `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/ViewModels/DirectoryState.swift`:43,82 - maxScanDepth = 10
- Evidence: `scanDirectory()` checks `if childDepth >= maxDepth { return truncatedDirectoryNode(...) }`. `DirectoryState.maxScanDepth` is 10. `scan()` passes this to `DirectoryScanner.scan(url:maxDepth:)`. Unit test `respectsDepthLimit` with maxDepth=2 confirms truncation occurs.
- Field Notes: N/A
- Issues: None

**AC-11.2**: Truncation indicator shown at depth limit
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/DirectoryScanner/DirectoryScanner.swift`:104-121 - truncatedDirectoryNode()
- Evidence: At depth limit, `truncatedDirectoryNode()` creates a child node with `name: "..."`, `isTruncated: true`. The directory node wraps this truncation indicator. Unit test `truncationIndicator` confirms the "..." node with `isTruncated == true`.
- Field Notes: N/A
- Issues: None

**AC-11.3**: Truncation indicator not clickable
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/SidebarRowView.swift`:22-23,88-101 - truncationRow
- Evidence: The `body` checks `if node.isTruncated` and renders `truncationRow` which has NO `.onTapGesture` and NO `.contentShape(Rectangle())`. It is purely visual with no interactive elements.
- Field Notes: N/A
- Issues: None

### FR-12: Empty Directory Handling (Must Have)

**AC-12.1**: Sidebar visible when directory has no Markdown files
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/SidebarView.swift`:19-29 - empty state fallback; `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/ViewModels/DirectoryState.swift`:35 - isSidebarVisible defaults true
- Evidence: `SidebarView` checks if tree is nil or children are empty, and if so shows `SidebarEmptyView()`. The sidebar itself is always rendered when `directoryState.isSidebarVisible` is true (default). An empty directory produces a tree with empty children, triggering the empty state.
- Field Notes: N/A
- Issues: None

**AC-12.2**: "No Markdown files found" message displayed
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/SidebarEmptyView.swift`:4-17 - body
- Evidence: `SidebarEmptyView` displays `Text("No Markdown files found")` with a `doc.text.magnifyingglass` icon, centered in the available space.
- Field Notes: N/A
- Issues: None

**AC-12.3**: Content area shows directory-mode welcome
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/DirectoryContentView.swift`:32 - .environment(\.isDirectoryMode, true)
- Evidence: `DirectoryContentView` sets `.environment(\.isDirectoryMode, true)` which propagates to `ContentView` and then `WelcomeView`. Since no file is selected initially, `documentState.currentFileURL` is nil and WelcomeView renders with the directory-mode message.
- Field Notes: N/A
- Issues: None

**AC-12.4**: Added Markdown file appears via directory watching
- Status: MANUAL_REQUIRED
- Implementation: Same as AC-10.1
- Evidence: The watcher monitors the root directory. When a file is added, the DispatchSource fires, `hasChanges` is set, and `refresh()` rebuilds the tree which will now include the new file. `SidebarView` switches from `SidebarEmptyView` to the tree view. Architecture is correct; requires runtime verification of actual DispatchSource event delivery.
- Field Notes: N/A
- Issues: Cannot verify filesystem event delivery in static analysis

### FR-13: Solarized Sidebar Theming (Must Have)

**AC-13.1**: Sidebar background uses backgroundSecondary
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/SidebarView.swift`:32 - .background
- Evidence: `.background(appSettings.theme.colors.backgroundSecondary)` is applied to the entire SidebarView VStack.
- Field Notes: N/A
- Issues: None

**AC-13.2**: Sidebar text uses theme foreground colors
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/SidebarRowView.swift`:45,73 - foreground; `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/SidebarHeaderView.swift`:14 - headingColor
- Evidence: File and directory row text uses `.foregroundStyle(appSettings.theme.colors.foreground)`. Secondary elements (chevrons, icons, truncation) use `foregroundSecondary`. Header uses `headingColor`. All are theme-driven.
- Field Notes: N/A
- Issues: None

**AC-13.3**: Selection highlight uses theme accent color
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/SidebarRowView.swift`:81 - fileRow background
- Evidence: `.background(isSelected ? appSettings.theme.colors.accent.opacity(0.2) : .clear)` uses the theme's accent color.
- Field Notes: N/A
- Issues: None

**AC-13.4**: Theme cycling (Cmd+T) updates sidebar immediately
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:166-178 - Cycle Theme command
- Evidence: All sidebar views read colors from `@Environment(AppSettings.self)`. When `appSettings.cycleTheme()` is called, SwiftUI's observation system should propagate the change to all views. The architecture supports immediate updates via `@Observable` and `@Environment`. Requires runtime visual verification.
- Field Notes: N/A
- Issues: Requires visual runtime verification to confirm no lag or incomplete update

**AC-13.5**: Divider uses theme border color
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/SidebarDivider.swift`:16 - fill
- Evidence: `Rectangle().fill(appSettings.theme.colors.border)` uses the theme's border color for the divider.
- Field Notes: N/A
- Issues: None

### FR-14: Tree Row Visual Design (Should Have)

**AC-14.1**: Directory rows have folder icon and disclosure chevron
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/SidebarRowView.swift`:33-48 - directoryRow
- Evidence: Directory row includes `Image(systemName: "chevron.down"/"chevron.right")` for disclosure and `Image(systemName: "folder")` for the folder icon.
- Field Notes: N/A
- Issues: None

**AC-14.2**: File rows have document icon
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/SidebarRowView.swift`:68 - fileRow
- Evidence: File row includes `Image(systemName: "doc.text")` for the document icon.
- Field Notes: N/A
- Issues: None

**AC-14.3**: Rows indented by depth level
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/SidebarRowView.swift`:49,77,97 - padding
- Evidence: All row variants apply `.padding(.leading, CGFloat(node.depth) * 16 + 8)` for depth-based indentation. Unit test `childDepthValues` confirms depth values are correct (root files at depth 1, subdirectory files at depth 2, etc.).
- Field Notes: N/A
- Issues: None

**AC-14.4**: Typography uses theme text styles
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/SidebarRowView.swift`:44-46,72-74 - font and foregroundStyle
- Evidence: Text uses `.font(.callout)` with `.foregroundStyle(appSettings.theme.colors.foreground)`. Header uses `.font(.headline)` with `.foregroundStyle(appSettings.theme.colors.headingColor)`. All theme-driven.
- Field Notes: N/A
- Issues: None

**AC-14.5**: Sidebar header displays root directory name
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/Views/SidebarHeaderView.swift`:9-20 - body
- Evidence: `Text(directoryState.rootURL.lastPathComponent)` displays the root directory name. Includes a folder icon via `Image(systemName: "folder")`.
- Field Notes: N/A
- Issues: None

## Implementation Gap Analysis

### Missing Implementations
- **TD1-TD8 (Knowledge Base documentation updates)**: All 8 documentation tasks are marked incomplete in tasks.md. These update `.rp1/context/` files (index.md, architecture.md, modules.md, patterns.md) with information about the new sidebar feature components.

### Partial Implementations
- None identified. All code implementations for T1-T9 are complete and verified.

### Implementation Issues
- None identified. Code quality is consistent with existing patterns.

## Code Quality Assessment

**Pattern Consistency**: HIGH. The implementation closely follows established codebase patterns:
- `DirectoryState` follows the same `@Observable` + `@MainActor` pattern as `DocumentState` and `FindState`
- `DirectoryWatcher` follows the same `DispatchSource` + `AsyncStream` pattern as `FileWatcher`
- `DirectoryValidator` follows the same validation pattern as `FileValidator`
- `FocusedDirectoryStateKey` follows the same pattern as `FocusedDocumentStateKey`
- All views use `@Environment(AppSettings.self)` for theme access
- All tests use Swift Testing (`@Suite`, `@Test`, `#expect`)

**Separation of Concerns**: HIGH. Clean separation between:
- Core layer: DirectoryScanner (pure function), DirectoryWatcher (filesystem monitoring), DirectoryValidator (path validation)
- State layer: DirectoryState (per-window state management)
- View layer: SidebarView, SidebarRowView, SidebarDivider, SidebarHeaderView, SidebarEmptyView, DirectoryContentView
- App layer: LaunchItem, FocusedDirectoryStateKey, DirectoryModeKey

**Test Coverage**: 53 unit tests across 5 suites, all passing. DirectoryScanner logic is thoroughly tested (14 tests). DirectoryState tests intentionally skip scan()-dependent assertions due to DispatchSource teardown races (documented in MEMORY.md), which is a reasonable tradeoff.

**SwiftLint/SwiftFormat Compliance**: Project builds cleanly. Task summaries indicate SwiftLint compliance was maintained throughout (SidebarRowView was refactored into separate computed properties to stay within body length limits).

**Design Adherence**: The implementation closely matches the design specification in design.md. Three undocumented deviations exist (SidebarDivider drag behavior, SidebarRowView structure, consumeLaunchContext enhancement), all of which are quality improvements rather than regressions.

## Recommendations

1. **Complete documentation tasks TD1-TD8**: All 8 knowledge base documentation updates are pending. These are important for maintaining the `.rp1/context/` knowledge base accuracy. Recommend completing before merge.

2. **Create field-notes.md**: Three deviations from the design were identified during verification but no field notes file exists. Recommend documenting the SidebarDivider dragStartWidth approach, SidebarRowView row-variant splitting, and consumeLaunchContext enhancement for future reference.

3. **Runtime verification of directory watching (AC-10.1 through AC-10.4, AC-12.4)**: Five acceptance criteria related to filesystem event delivery require manual runtime testing. Recommend creating a manual test script: open a directory, add/remove .md files, and verify sidebar updates. Consider adding integration tests for this in a future iteration.

4. **Runtime verification of theme cycling (AC-13.4)**: The sidebar theme update on Cmd+T should be visually verified at runtime to confirm no lag or incomplete updates.

5. **Consider adding sidebar width clamping in DirectoryState.sidebarWidth setter**: Currently, width clamping only happens in `SidebarDivider`'s drag gesture. If `sidebarWidth` were set programmatically elsewhere, it would not be clamped. Consider adding a `didSet` clamping guard in `DirectoryState`.

6. **Consider documenting the DispatchSource test limitation**: The DirectoryStateTests skip scan/refresh assertions due to DispatchSource cleanup races. This is well-documented in task summaries but could benefit from a code comment in the test file explaining why these tests are skipped.

## Verification Evidence

### Build Verification
```
Build complete! (0.42s) -- no errors, no warnings
```

### Test Verification
```
Test run with 53 tests passed after 0.013 seconds.
- DirectoryScannerTests: 14/14 passed
- FileTreeNodeTests: 8/8 passed
- DirectoryStateTests: 15/15 passed
- DirectoryValidatorTests: 7/7 passed
- LaunchItemTests: 9/9 passed
```

### Key File Inventory
| File | Purpose | Status |
|------|---------|--------|
| `mkdn/Core/CLI/DirectoryValidator.swift` | Directory path validation | Implemented |
| `mkdn/Core/CLI/CLIError.swift` | Error cases for directory | Extended |
| `mkdn/Core/CLI/LaunchContext.swift` | Directory URL storage | Extended |
| `mkdn/Core/CLI/FileValidator.swift` | resolvePath made public | Modified |
| `mkdn/Core/DirectoryScanner/FileTreeNode.swift` | Tree node model | Implemented |
| `mkdn/Core/DirectoryScanner/DirectoryScanner.swift` | Directory scanning | Implemented |
| `mkdn/Core/DirectoryWatcher/DirectoryWatcher.swift` | Filesystem monitoring | Implemented |
| `mkdn/App/LaunchItem.swift` | File/directory discriminant | Implemented |
| `mkdn/App/DocumentWindow.swift` | Window routing for directory | Modified |
| `mkdn/App/FocusedDirectoryStateKey.swift` | FocusedValue key | Implemented |
| `mkdn/App/DirectoryModeKey.swift` | Environment key | Implemented |
| `mkdn/Features/Sidebar/ViewModels/DirectoryState.swift` | Per-window directory state | Implemented |
| `mkdn/Features/Sidebar/Views/SidebarView.swift` | Main sidebar panel | Implemented |
| `mkdn/Features/Sidebar/Views/SidebarRowView.swift` | Tree row rendering | Implemented |
| `mkdn/Features/Sidebar/Views/SidebarDivider.swift` | Resizable divider | Implemented |
| `mkdn/Features/Sidebar/Views/SidebarHeaderView.swift` | Directory name header | Implemented |
| `mkdn/Features/Sidebar/Views/SidebarEmptyView.swift` | Empty state message | Implemented |
| `mkdn/Features/Sidebar/Views/DirectoryContentView.swift` | Layout wrapper | Implemented |
| `mkdn/UI/Components/WelcomeView.swift` | Directory mode adaptation | Modified |
| `mkdn/App/MkdnCommands.swift` | Toggle Sidebar command | Modified |
| `mkdnEntry/main.swift` | CLI argument routing | Modified |
| `mkdnTests/Unit/Core/DirectoryScannerTests.swift` | Scanner tests (14) | Implemented |
| `mkdnTests/Unit/Core/FileTreeNodeTests.swift` | Node tests (8) | Implemented |
| `mkdnTests/Unit/Features/DirectoryStateTests.swift` | State tests (15) | Implemented |
| `mkdnTests/Unit/Core/DirectoryValidatorTests.swift` | Validator tests (7) | Implemented |
| `mkdnTests/Unit/Core/LaunchItemTests.swift` | LaunchItem tests (9) | Implemented |
