# Hypothesis Document: directory-sidebar
**Version**: 1.0.0 | **Created**: 2026-02-16T00:00:00Z | **Status**: VALIDATED

## Hypotheses

### HYP-001: WindowGroup(for: LaunchItem.self) Opens Separate Windows per Value
**Risk Level**: HIGH
**Status**: CONFIRMED
**Statement**: WindowGroup(for: LaunchItem.self) correctly opens separate windows when openWindow(value: LaunchItem.directory(url)) is called, and SwiftUI does not deduplicate or merge windows based on the LaunchItem value. LaunchItem is a custom enum with cases .file(URL) and .directory(URL), conforming to Hashable and Codable.
**Context**: The directory-sidebar feature requires opening directory windows alongside file windows. The existing app uses WindowGroup(for: URL.self) for file windows. The design needs a discriminated union (LaunchItem enum) to distinguish window types.
**Validation Criteria**:
- CONFIRM if: WindowGroup(for: LaunchItem.self) produces distinct windows for different LaunchItem values, and openWindow(value:) correctly dispatches to the right WindowGroup scene
- REJECT if: SwiftUI deduplicates windows based on enum value, merges them, or fails to route openWindow calls to the correct WindowGroup
**Suggested Method**: CODE_EXPERIMENT

### HYP-002: DispatchSource Directory Watch Fires on Child File Changes
**Risk Level**: MEDIUM
**Status**: CONFIRMED
**Statement**: DispatchSource.makeFileSystemObjectSource on a directory with event mask [.write, .rename, .delete, .link] fires events when files are created or deleted within that directory (not just when the directory itself is modified).
**Context**: The directory sidebar needs to update its file listing when files are added/removed from the watched directory. The existing FileWatcher uses DispatchSource on individual files. This hypothesis tests whether the same mechanism works for directory-level monitoring of child changes.
**Validation Criteria**:
- CONFIRM if: Opening a DispatchSource on a directory fd with O_EVTONLY and event mask [.write, .rename, .delete, .link] fires the event handler when a file is created or deleted inside the directory
- REJECT if: The event handler only fires for modifications to the directory inode itself (e.g., chmod, rename of directory) and not for child file operations
**Suggested Method**: CODE_EXPERIMENT

## Validation Findings

### HYP-001 Findings
**Validated**: 2026-02-16T00:00:00Z
**Method**: EXTERNAL_RESEARCH + CODEBASE_ANALYSIS
**Result**: CONFIRMED

**Evidence**:

WindowGroup(for: LaunchItem.self) will work correctly for opening separate windows with different LaunchItem values. Key findings from Apple's WWDC22 documentation and multiple authoritative sources:

1. **Value-based window identity**: SwiftUI uses the value's `Hashable` equality to determine window identity. Each unique presented value gets its own window. Since a `LaunchItem` enum with `.file(URL)` and `.directory(URL)` cases produces different hash values for different cases (even with the same inner URL), they will always produce separate windows.

2. **Deduplication is per-value, not per-type**: When `openWindow(value: LaunchItem.directory(someURL))` is called and a window with that exact value already exists, SwiftUI brings that window to the front rather than creating a duplicate. This is desirable behavior -- it prevents opening the same directory sidebar twice.

3. **Required conformances**: The value type must conform to both `Hashable` (for window identity) and `Codable` (for state restoration). A Swift enum with associated URL values satisfies both with standard synthesis.

4. **Single WindowGroup with enum switching**: A single `WindowGroup(for: LaunchItem.self)` can switch on the enum case to show different views (DocumentWindow vs DirectorySidebarWindow). This is cleaner than two separate WindowGroup declarations.

5. **Current codebase migration path**: The existing app (`mkdnEntry/main.swift:12`) uses `WindowGroup(for: URL.self)`. Migrating to `WindowGroup(for: LaunchItem.self)` requires:
   - Defining a `LaunchItem` enum conforming to `Hashable, Codable`
   - Updating `DocumentWindow` to switch on the enum case
   - Updating all `openWindow(value: url)` calls to `openWindow(value: LaunchItem.file(url))`
   - Updating `LaunchContext.fileURLs` to produce `LaunchItem` values
   - Updating `FileOpenCoordinator` to produce `.file(url)` values

6. **Important caveat**: `openWindow(value:)` deduplicates. Calling `openWindow(value: .file(sameURL))` when that window already exists will bring it to front, NOT create a new window. This matches the current behavior with `URL.self` and is the correct UX for both file and directory windows.

**Sources**:
- WWDC22 Session 10061: "Bring multiple windows to your SwiftUI app" (https://developer.apple.com/videos/play/wwdc2022/10061/)
- Apple Developer Documentation: WindowGroup (https://developer.apple.com/documentation/swiftui/windowgroup)
- fline.dev: Window Management with SwiftUI 4 (https://www.fline.dev/window-management-on-macos-with-swiftui-4/)
- Codebase: `mkdnEntry/main.swift:12` -- current `WindowGroup(for: URL.self)` usage
- Codebase: `mkdn/App/DocumentWindow.swift:48` -- current `openWindow(value: url)` calls
- Codebase: `mkdn/Core/CLI/LaunchContext.swift` -- current launch URL handling

**Implications for Design**:
The design can proceed with a `LaunchItem` enum approach. A single `WindowGroup(for: LaunchItem.self)` that switches on the case is the recommended pattern. The deduplication behavior (same value = bring existing window to front) is correct UX. The migration from the current `URL.self` approach is straightforward but touches several files (main.swift, DocumentWindow, LaunchContext, FileOpenCoordinator, AppDelegate).

---

### HYP-002 Findings
**Validated**: 2026-02-16T00:00:00Z
**Method**: CODE_EXPERIMENT
**Result**: CONFIRMED

**Evidence**:

A Swift script opened a `DispatchSource.makeFileSystemObjectSource` on a temporary directory with `O_EVTONLY` and event mask `[.write, .rename, .delete, .link]`, then performed file operations inside the directory. Results:

1. **File creation (Test 1)**: Creating a file inside the directory fired the event handler with `.write` event mask (rawValue 2). **PASS**.

2. **File deletion (Test 2)**: Deleting a file inside the directory fired the event handler with `.write` event mask (rawValue 2). **PASS**.

3. **Subdirectory creation (Test 3)**: Creating a subdirectory fired the event handler with `.write` AND `.link` event masks (rawValue 18 = 2 + 16). The `.link` event fires because directory creation changes the parent directory's link count. **PASS**.

4. **Nested file creation (Test 4)**: Creating a file inside a *subdirectory* did NOT fire the event handler on the parent directory watch. **This is expected kqueue behavior -- monitoring is not recursive.** The directory sidebar design must account for this: only direct children of the watched directory will trigger events.

Full experiment output:
```
EVENT 1: Received event mask: 2 (write=2) -> .write          [file creation]
EVENT 2: Received event mask: 2 (write=2) -> .write          [file deletion]
EVENT 3: Received event mask: 18 (write=2, link=16) -> .write, .link  [subdir creation]
Test 4: No event for nested file creation (expected - kqueue not recursive)
Total events received: 3
```

**Sources**:
- Code experiment: `/tmp/hypothesis-directory-sidebar/hyp002_directory_watch.swift` (disposable)
- Codebase: `mkdn/Core/FileWatcher/FileWatcher.swift:42-46` -- existing DispatchSource pattern on files

**Implications for Design**:
DispatchSource on a directory reliably fires for direct child file/directory create and delete operations. The existing `FileWatcher` pattern can be adapted for directory monitoring with minimal changes (open directory fd instead of file fd, add `.link` to event mask). However, monitoring is NOT recursive -- changes in subdirectories will not trigger events on the parent watch. If the sidebar needs to show nested directory contents, each subdirectory requires its own DispatchSource. For a flat file listing of a single directory, the current approach is sufficient.

## Summary
| Hypothesis | Risk | Result | Implication |
|------------|------|--------|-------------|
| HYP-001 | HIGH | CONFIRMED | WindowGroup(for: LaunchItem.self) works with enum-based routing; deduplication by value equality is correct UX; migration from URL.self is straightforward |
| HYP-002 | MEDIUM | CONFIRMED | DispatchSource on directory fires for direct child create/delete; not recursive (subdirs need own watchers); existing FileWatcher pattern reusable |
