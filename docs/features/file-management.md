# File Management

## Overview

File management covers every path a Markdown file can take into and through mkdn: Finder/dock open events, default app registration, live file watching, in-window drag-and-drop, local link navigation, Open Recent, and save/save-as. The subsystem bridges macOS Launch Services and AppKit delegate events into the SwiftUI multi-window lifecycle through a coordinator pattern, ensuring every entry point converges on the same `DocumentState.loadFile(at:)` flow.

## User Experience

Files reach mkdn through six entry points, all producing the same result -- the file renders in a window:

1. **Finder / dock**: Double-click or drag `.md`/`.markdown` files. If mkdn is running, a new window opens; if not, the app launches with the file. Multiple files produce multiple windows.
2. **Open Recent**: File > Open Recent lists previously opened files (system-managed count, typically 10). Selecting one opens a new window. "Clear Menu" purges the list.
3. **Drag-and-drop**: Dragging a Markdown file onto the content area loads it into the current window (replaces content, not a new window).
4. **Link navigation**: Clicking a relative `.md`/`.markdown` link in the preview loads the target in the same window. Cmd+click opens it in a new window. External links (http, mailto, tel) open in the system default handler. Non-Markdown local files open in their default app.
5. **Save / Save As**: Cmd+S writes editor content back to the current file. Save As (Cmd+Shift+S) presents an NSSavePanel, writes to the chosen location, and updates the window to track the new file.
6. **File watching**: When the on-disk file changes externally, the orb indicator signals the outdated state. The user can reload to pick up changes.

Default app registration is offered via a "Set as Default Markdown App" menu item in the app menu and a one-time first-launch hint banner. Both call the same `DefaultHandlerService`. The hint persists its dismissed state in UserDefaults and never reappears.

## Architecture

The file management subsystem spans three layers:

**System bridge** -- `AppDelegate` receives `application(_:open:)` events from Launch Services (covers Finder double-click, dock drag, and Open With). It filters for `.md`/`.markdown` extensions, records each URL in NSDocumentController for Open Recent tracking, and pushes them into `FileOpenCoordinator.pendingURLs`. When no visible windows exist (cold launch or all windows closed), it forces a new window via `NSDocumentController.newDocument`.

**Coordinator** -- `FileOpenCoordinator` is a `@MainActor @Observable` singleton with a `pendingURLs` queue. The SwiftUI `App` body observes this array and calls `openWindow(value:)` for each URL, then drains the queue via `consumeAll()`. This decouples AppKit event delivery from SwiftUI window creation.

**Per-window state** -- `DocumentState` owns the file lifecycle for a single window: load, save, save-as, reload, and unsaved-changes tracking. It creates a `FileWatcher` that uses `DispatchSource.makeFileSystemObjectSource` (kernel-level `O_EVTONLY` file descriptor) to monitor `.write`, `.rename`, and `.delete` events. The watcher bridges DispatchSource callbacks into an `AsyncStream` consumed by a `Task`, setting `isOutdated = true` on the main actor. Save operations pause the watcher to suppress false-positive events from the app's own writes.

`LinkNavigationHandler` classifies clicked URLs into three destinations -- `.localMarkdown`, `.external`, or `.otherLocalFile` -- by inspecting the scheme and file extension. Relative paths are resolved against the current document's parent directory. Anchor-only links (`#heading`) resolve to the current document.

`DefaultHandlerService` wraps `NSWorkspace.setDefaultApplication(at:toOpenContentType:)` for the `net.daringfireball.markdown` UTType. It resolves the app bundle URL with a fallback to Launch Services lookup by bundle identifier, so it works both from a `.app` bundle and (gracefully returns false) when running as a bare binary via `swift run`.

## Implementation Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| File-open event routing | `NSApplicationDelegateAdaptor` + `FileOpenCoordinator` queue | Standard AppKit bridge; cleanly separates delegate from SwiftUI window lifecycle |
| File watching mechanism | `DispatchSource.makeFileSystemObjectSource` with `AsyncStream` bridge | Kernel-level efficiency; no polling. AsyncStream avoids `@MainActor`-isolated closures on the utility queue |
| Save-pause strategy | `pauseForSave()` / `resumeAfterSave()` with 200ms drain delay | Prevents the app's own write from triggering a false outdated signal |
| Default handler API | `NSWorkspace.setDefaultApplication(at:toOpenContentType:)` | Non-deprecated macOS 12+ API; works on the macOS 14+ deployment target |
| UTType declaration | `UTImportedTypeDeclarations` (not Exported) | mkdn does not own `net.daringfireball.markdown`; importing avoids conflicts |
| Open Recent backend | `NSDocumentController.shared` | System manages persistence, item count, and Clear Menu for free |
| Link classification | Static `LinkNavigationHandler.classify` with enum return | Pure function; easy to test without UI or file system dependencies |
| Drag-and-drop target | `.onDrop(of: [.fileURL])` on `ContentView` | Loads into current window (not a new one), matching single-document drag semantics |
| Markdown extension check | `FileOpenCoordinator.isMarkdownURL` (`.md` / `.markdown`, case-insensitive) | Single source of truth shared by AppDelegate, ContentView drop handler, and LinkNavigationHandler |

## Files

**Core services:**
- `mkdn/Core/Services/DefaultHandlerService.swift` -- UTType resolution, `registerAsDefault()`, `isDefault()`, bundle URL fallback logic.
- `mkdn/Core/FileWatcher/FileWatcher.swift` -- DispatchSource file monitor with AsyncStream bridge, save-pause/resume, acknowledge.
- `mkdn/Core/Markdown/LinkNavigationHandler.swift` -- URL classification (local markdown / external / other local), relative path resolution.

**App layer:**
- `mkdn/App/AppDelegate.swift` -- `NSApplicationDelegate` handling `application(_:open:)`, Cmd-W monitor, icon masking, reopen behavior.
- `mkdn/App/FileOpenCoordinator.swift` -- Observable URL queue bridging AppDelegate to SwiftUI window creation.
- `mkdn/App/OpenRecentCommands.swift` -- SwiftUI `Commands` struct reading `NSDocumentController.recentDocumentURLs`.
- `mkdn/App/DocumentState.swift` -- Per-window file lifecycle: load, save, save-as, reload, unsaved-changes detection, FileWatcher ownership.
- `mkdn/App/ContentView.swift` -- `.onDrop` handler for drag-and-drop file loading.

## Dependencies

| Dependency | Type | Usage |
|------------|------|-------|
| `UniformTypeIdentifiers` | System framework | `UTType("net.daringfireball.markdown")` for default handler registration |
| `NSWorkspace` | AppKit API | `setDefaultApplication`, `urlForApplication` |
| `NSDocumentController` | AppKit API | Open Recent tracking, `noteNewRecentDocumentURL`, `clearRecentDocuments` |
| `DispatchSource.makeFileSystemObjectSource` | libdispatch API | Kernel-level file change monitoring |
| `NSSavePanel` | AppKit API | Save As file picker |
| Info.plist `CFBundleDocumentTypes` / `UTImportedTypeDeclarations` | Build config | Registers mkdn with Launch Services for `.md` and `.markdown` |

No external packages. Everything builds with the existing dependency graph.

## Testing

**FileOpenCoordinatorTests** (`mkdnTests/Unit/Core/FileOpenCoordinatorTests.swift`, 4 tests):
Queue lifecycle: starts empty; append makes URLs available; `consumeAll()` returns all and clears; `consumeAll()` on empty returns empty array.

**DefaultHandlerServiceTests** (`mkdnTests/Unit/Core/DefaultHandlerServiceTests.swift`, 2 tests):
Interface contracts: `isDefault()` and `registerAsDefault()` return Bool without crashing. Full integration requires a `.app` bundle context.

**FileWatcherTests** (`mkdnTests/Unit/Core/FileWatcherTests.swift`, 4 tests):
Initial state: starts not outdated, no watched URL. `acknowledge()` clears outdated flag. `pauseForSave()` sets pause flag. `resumeAfterSave()` clears pause after ~200ms delay. Tests that call `watch(url:)` are avoided because DispatchSource teardown races with test process exit.

**LinkNavigationHandlerTests** (`mkdnTests/Unit/Core/LinkNavigationHandlerTests.swift`, 14 tests):
Classification: http/https/mailto/tel/unknown schemes as external; relative `.md`/`.markdown` paths as local markdown; `.txt`/`.pdf` as other local file; `file://` scheme with `.md` extension as local markdown. Resolution: parent directory traversal, dot-slash prefix, nil document URL fallback, anchor-only links. Edge cases: deeply nested paths, multiple parent traversals.

**DocumentState** file operations (load, save, save-as, reload, unsaved-changes) are covered by DocumentState unit tests in the broader test suite. Visual verification of drag-and-drop, link navigation, and file-watching indicator behavior uses the mkdn-ctl harness.
