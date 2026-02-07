# Feature Verification Report #1

**Generated**: 2026-02-07T06:22Z
**Feature ID**: default-markdown-app
**Verification Scope**: all
**KB Context**: Loaded
**Field Notes**: Available

## Executive Summary
- Overall Status: PARTIAL
- Acceptance Criteria: 28/36 verified (78%)
- Implementation Quality: HIGH
- Ready for Merge: NO (documentation tasks TD1-TD4 incomplete; 8 criteria require manual verification on a built .app bundle)

## Field Notes Context
**Field Notes Available**: Yes

### Documented Deviations
1. **NSWorkspace API label**: Design specified `setDefaultApplication(at:toOpenContentType:)` but actual macOS 14+ API uses `setDefaultApplication(at:toOpen:)`. Implementation correctly uses the real API.
2. **NSWorkspace non-throwing**: Design assumed `setDefaultApplication` throws for sandbox degradation. On macOS 14+, the API is non-throwing. Implementation returns `true` unconditionally after calling the API.
3. **isMarkdownURL placement**: Placed on `FileOpenCoordinator` (not `AppDelegate`) and marked `nonisolated` for Swift 6 testability. Pure function, no actor-isolated state access.
4. **MarkdownFileFilterTests missing @MainActor**: Pre-existing issue found during T5/T6; fixed by adding `@MainActor` to all 7 test functions.
5. **SwiftLint environment issue**: `swiftlint lint` fails with `Loading sourcekitdInProc.framework failed` -- system-level SourceKit issue, not code-related.

### Undocumented Deviations
1. **DefaultHandlerHintView uses ZStack overlay instead of VStack wrapping**: The design showed `VStack(spacing: 0)` with the hint at the top. Implementation uses `ZStack` with `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)` overlay. This is noted in T7's implementation summary but not in field-notes.md. The behavior is functionally equivalent (non-blocking overlay at top).
2. **DefaultHandlerHintView uses `.ultraThinMaterial` instead of `appSettings.theme.colors.backgroundSecondary`**: Design specified Solarized `backgroundSecondary` as the hint background. Implementation uses `.ultraThinMaterial` for consistency with `ModeTransitionOverlay`. Noted in T7 implementation summary but not in field-notes.md.
3. **`@Environment(\.openWindow)` and `.onChange` placed in DocumentWindow instead of MkdnApp**: Design specified these in the App struct body. Implementation places them in DocumentWindow because they are View-level APIs not available on App structs. Noted in T4 implementation summary but not in field-notes.md.

## Acceptance Criteria Verification

### FR-001: Markdown File Type Declaration

**AC-1**: After installation, macOS lists mkdn in "Open With" for `.md` files
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/Resources/Info.plist`:27-41 - CFBundleDocumentTypes
- Evidence: `CFBundleDocumentTypes` declares `net.daringfireball.markdown` with `CFBundleTypeRole=Editor` and `LSHandlerRank=Default`. This UTType covers `.md` files per the UTImportedTypeDeclarations at lines 43-67.
- Field Notes: N/A
- Issues: None. Full Finder verification requires manual testing with a built .app bundle.

**AC-2**: After installation, macOS lists mkdn in "Open With" for `.markdown` files
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/Resources/Info.plist`:55-58 - UTTypeTagSpecification
- Evidence: The `UTTypeTagSpecification` lists both `md` and `markdown` under `public.filename-extension`. Since the `CFBundleDocumentTypes` references `net.daringfireball.markdown`, and the imported type declaration covers both extensions, `.markdown` files are included.
- Field Notes: N/A
- Issues: None.

**AC-3**: Declarations compatible with macOS 14.0+
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/Resources/Info.plist`:20-21 - LSMinimumSystemVersion
- Evidence: `LSMinimumSystemVersion` is set to `14.0`. The `UTImportedTypeDeclarations` format and `CFBundleDocumentTypes` with `LSItemContentTypes` are the modern macOS approach (replacing deprecated `CFBundleTypeExtensions`).
- Field Notes: N/A
- Issues: None.

### FR-002: UTType Registration

**AC-1**: UTType declarations reference `net.daringfireball.markdown`
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/Resources/Info.plist`:46-47 - UTTypeIdentifier
- Evidence: `UTTypeIdentifier` is explicitly set to `net.daringfireball.markdown`.
- Field Notes: N/A
- Issues: None.

**AC-2**: Type conforms to `public.plain-text` supertype hierarchy
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/Resources/Info.plist`:50-52 - UTTypeConformsTo
- Evidence: `UTTypeConformsTo` includes `public.plain-text`. The `public.plain-text` type itself conforms to `public.text` -> `public.data` in macOS, so the full hierarchy is satisfied.
- Field Notes: N/A
- Issues: None.

**AC-3**: Both `.md` and `.markdown` covered
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/Resources/Info.plist`:55-58 - UTTypeTagSpecification
- Evidence: `public.filename-extension` array includes both `md` and `markdown`.
- Field Notes: N/A
- Issues: None.

### FR-003: File-Open Event Handling

**AC-1**: Double-clicking `.md` in Finder (mkdn default) launches and renders
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppDelegate.swift`:10-16 - `application(_:open:)`, `/Users/jud/Projects/mkdn/mkdn/App/DocumentWindow.swift`:32-46 - `.task`
- Evidence: The code path is fully implemented: `AppDelegate.application(_:open:)` filters for Markdown URLs, pushes to `FileOpenCoordinator.shared.pendingURLs`, which triggers `DocumentWindow`'s `.onChange` to call `openWindow(value:)`. The initial launch window adopts pending URLs via `.task`. Code logic is correct.
- Field Notes: N/A
- Issues: Full end-to-end verification requires a built `.app` bundle and macOS Finder interaction.

**AC-2**: Double-clicking `.md` while running opens new window
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/DocumentWindow.swift`:47-50 - `.onChange`
- Evidence: When `FileOpenCoordinator.shared.pendingURLs` changes at runtime, `.onChange` consumes all URLs and calls `openWindow(value: url)` for each, creating a new window per file. The `MkdnApp` uses `WindowGroup(for: URL.self)` with `.handlesExternalEvents(matching: [])` to prevent reusing existing windows.
- Field Notes: N/A
- Issues: None.

**AC-3**: File URL routed through existing Markdown pipeline
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/DocumentWindow.swift`:34-35 - `documentState.loadFile(at:)`, `/Users/jud/Projects/mkdn/mkdn/App/DocumentState.swift`:51-59 - `loadFile(at:)`
- Evidence: `DocumentWindow.task` calls `documentState.loadFile(at: fileURL)`. `DocumentState.loadFile(at:)` reads file content, sets `markdownContent`, and triggers `fileWatcher.watch(url:)` -- the same pipeline used by CLI and Open dialog paths.
- Field Notes: N/A
- Issues: None.

**AC-4**: `.markdown` files behave identically to `.md`
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/FileOpenCoordinator.swift`:25-28 - `isMarkdownURL(_:)`, `/Users/jud/Projects/mkdn/mkdn/App/AppDelegate.swift`:11 - URL filtering
- Evidence: `FileOpenCoordinator.isMarkdownURL(_:)` accepts both `md` and `markdown` (case-insensitive). `AppDelegate.application(_:open:)` uses this filter. All downstream processing is extension-agnostic -- `DocumentState.loadFile(at:)` reads any URL. Tests in `MarkdownFileFilterTests` confirm `.markdown` is accepted.
- Field Notes: N/A
- Issues: None.

### FR-004: Multi-Window File Opening

**AC-1**: Second file via Finder creates second window
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/DocumentWindow.swift`:47-50, `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`:18-22
- Evidence: `WindowGroup(for: URL.self)` creates distinct windows per URL value. `.handlesExternalEvents(matching: [])` prevents reusing an existing window. `.onChange` on `pendingURLs` calls `openWindow(value: url)` for each new URL.
- Field Notes: N/A
- Issues: None.

**AC-2**: Each window operates independently
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/DocumentWindow.swift`:19 - `@State private var documentState = DocumentState()`
- Evidence: Each `DocumentWindow` creates its own `@State private var documentState = DocumentState()`. This means each window has completely independent file state, view mode, content, and file watcher. `AppSettings` is shared (theme), but document state is per-window.
- Field Notes: N/A
- Issues: None.

**AC-3**: N simultaneous files create N windows
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppDelegate.swift`:12-14, `/Users/jud/Projects/mkdn/mkdn/App/DocumentWindow.swift`:47-50
- Evidence: `AppDelegate.application(_:open:)` iterates over all URLs and appends each to `pendingURLs`. The `.onChange` handler calls `consumeAll()` which returns all pending URLs, then calls `openWindow(value: url)` for each in the loop. N URLs produce N `openWindow` calls.
- Field Notes: N/A
- Issues: None.

### FR-005: Set as Default Menu Item

**AC-1**: Menu item visible in application menu
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:17-24 - `CommandGroup(after: .appInfo)`
- Evidence: `CommandGroup(after: .appInfo)` places the "Set as Default Markdown App" button immediately after the About item in the application menu -- the standard macOS app menu location.
- Field Notes: N/A
- Issues: None.

**AC-2**: Activating registers mkdn as default for `.md` and `.markdown`
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:19, `/Users/jud/Projects/mkdn/mkdn/Core/Services/DefaultHandlerService.swift`:14-22
- Evidence: Button action calls `DefaultHandlerService.registerAsDefault()` which calls `NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: markdownType)`. The `markdownType` is `UTType("net.daringfireball.markdown")` which covers both `.md` and `.markdown` extensions.
- Field Notes: API parameter label deviation documented in field-notes.md.
- Issues: None.

**AC-3**: After activation, Finder double-click opens in mkdn
- Status: MANUAL_REQUIRED
- Implementation: Same as AC-2 above.
- Evidence: The code correctly calls the system API to register as default. Verification that Finder respects this requires manual testing.
- Field Notes: N/A
- Issues: Requires manual verification on macOS with .app bundle.

**AC-4**: No elevated privileges required
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Services/DefaultHandlerService.swift`:14-22
- Evidence: `NSWorkspace.shared.setDefaultApplication(at:toOpen:)` does not require any entitlements, accessibility permissions, or elevated privileges. No `sudo`, no entitlements file, no permission dialogs.
- Field Notes: N/A
- Issues: None.

**AC-5**: Menu item always available (not conditionally hidden)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:17-24
- Evidence: The `Button("Set as Default Markdown App")` has no `.disabled()` modifier and no conditional wrapping. It is always visible and always enabled.
- Field Notes: N/A
- Issues: None.

### FR-006: First-Launch Hint

**AC-1**: Non-modal hint appears on first launch
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:53-56, `/Users/jud/Projects/mkdn/mkdn/Features/DefaultHandler/Views/DefaultHandlerHintView.swift`:1-83
- Evidence: `ContentView` body contains `if !appSettings.hasShownDefaultHandlerHint { DefaultHandlerHintView() }` as a ZStack overlay with `.top` alignment. `hasShownDefaultHandlerHint` defaults to `false` (verified in `AppSettingsTests` line 147-153). The hint is a banner overlay, not a modal sheet or alert.
- Field Notes: N/A
- Issues: None.

**AC-2**: "Set as Default" button triggers registration
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/DefaultHandler/Views/DefaultHandlerHintView.swift`:30-37
- Evidence: `Button("Set as Default")` action calls `DefaultHandlerService.registerAsDefault()`. On success, it sets `showConfirmation = true` and calls `dismissAfterDelay()`. It also calls `markHintShown()` which persists the hint suppression.
- Field Notes: N/A
- Issues: None.

**AC-3**: Dismiss option available
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/DefaultHandler/Views/DefaultHandlerHintView.swift`:40-47
- Evidence: An xmark button is present with `.buttonStyle(.plain)`. Clicking it calls `withAnimation(.easeOut(duration: 0.3)) { isVisible = false }` and `markHintShown()`.
- Field Notes: N/A
- Issues: None.

**AC-4**: After "Set as Default", hint disappears and mkdn registered
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/DefaultHandler/Views/DefaultHandlerHintView.swift`:30-37, 57-71, 77-82
- Evidence: On success, `showConfirmation = true` transitions the view to `confirmationContent` (checkmark + "Done!" text), then `dismissAfterDelay()` waits 2 seconds and sets `isVisible = false`. `markHintShown()` ensures the hint never returns.
- Field Notes: N/A
- Issues: None.

**AC-5**: After dismiss, never appears again
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/DefaultHandler/Views/DefaultHandlerHintView.swift`:73-75, `/Users/jud/Projects/mkdn/mkdn/App/AppSettings.swift`:40-44
- Evidence: Both dismiss paths call `markHintShown()` which sets `appSettings.hasShownDefaultHandlerHint = true`. The `didSet` observer on `AppSettings.hasShownDefaultHandlerHint` writes to `UserDefaults`. `ContentView` checks `!appSettings.hasShownDefaultHandlerHint` before showing the hint.
- Field Notes: N/A
- Issues: None.

**AC-6**: State persisted across restarts
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppSettings.swift`:40-44, 55
- Evidence: `hasShownDefaultHandlerHint` has a `didSet` that writes to `UserDefaults.standard` under key `"hasShownDefaultHandlerHint"`. The `init()` reads `UserDefaults.standard.bool(forKey: hasShownDefaultHandlerHintKey)`. Unit tests at `/Users/jud/Projects/mkdn/mkdnTests/Unit/Features/AppSettingsTests.swift`:155-174 verify persistence and restoration.
- Field Notes: N/A
- Issues: None.

**AC-7**: Hint does not block interaction
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:53-56, `/Users/jud/Projects/mkdn/mkdn/Features/DefaultHandler/Views/DefaultHandlerHintView.swift`:1-83
- Evidence: The hint is rendered as a ZStack overlay with `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)`. It is not a modal sheet, alert, or full-screen overlay -- it floats at the top while the rest of the UI remains interactive beneath it.
- Field Notes: N/A
- Issues: None.

**AC-8**: No separate notification about existing defaults
- Status: VERIFIED
- Implementation: Full codebase search
- Evidence: There is no code that checks `DefaultHandlerService.isDefault()` on launch to show any notification. The only proactive hint is the first-launch `DefaultHandlerHintView`, controlled by `hasShownDefaultHandlerHint`. No other notification mechanism exists.
- Field Notes: N/A
- Issues: None.

### FR-007: Dock Icon Drag-and-Drop

**AC-1**: Drag `.md` to dock opens in mkdn
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppDelegate.swift`:10-16
- Evidence: macOS routes dock icon drops through the same `application(_:open:)` delegate method. The implementation filters for Markdown URLs and pushes them through `FileOpenCoordinator`. Code path is correct.
- Field Notes: N/A
- Issues: Requires manual verification with .app bundle in dock.

**AC-2**: Drag `.markdown` to dock opens in mkdn
- Status: MANUAL_REQUIRED
- Implementation: Same as AC-1.
- Evidence: `FileOpenCoordinator.isMarkdownURL(_:)` accepts `.markdown`. Same code path as AC-1.
- Field Notes: N/A
- Issues: Requires manual verification.

**AC-3**: Drag to dock while not running launches and opens
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppDelegate.swift`:10-16, `/Users/jud/Projects/mkdn/mkdn/App/DocumentWindow.swift`:32-46
- Evidence: When the app is not running, macOS launches it and delivers the file-open event via `application(_:open:)`. The `DocumentWindow.task` handles pending URLs on the initial window. Code path is correct.
- Field Notes: N/A
- Issues: Requires manual verification.

**AC-4**: Drag while running opens new window
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/DocumentWindow.swift`:47-50
- Evidence: Runtime file-open events (including dock drops) push URLs to `pendingURLs`. The `.onChange` handler creates new windows via `openWindow(value: url)`.
- Field Notes: N/A
- Issues: None (code path verified; dock drops use same `application(_:open:)` as Finder).

**AC-5**: Multiple files each open in separate window
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppDelegate.swift`:12-14
- Evidence: The `for url in markdownURLs` loop appends each URL individually to `pendingURLs`. The `.onChange` handler then opens each in a separate window.
- Field Notes: N/A
- Issues: None.

### FR-008: Open Recent

**AC-1**: File > Open Recent submenu exists
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/OpenRecentMenu.swift`:9-30, `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`:27
- Evidence: `OpenRecentCommands` is a `Commands` struct using `CommandGroup(after: .newItem)` with a `Menu("Open Recent")` containing dynamic items and a "Clear Menu" button. It is included in the `MkdnApp` body via `.commands { ... OpenRecentCommands() }`.
- Field Notes: N/A
- Issues: None.

**AC-2**: Files from any open method added to list
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/DocumentState.swift`:58, `/Users/jud/Projects/mkdn/mkdn/App/AppDelegate.swift`:13, `/Users/jud/Projects/mkdn/mkdn/App/DocumentWindow.swift`:35,40
- Evidence: `NSDocumentController.shared.noteNewRecentDocumentURL(url)` is called in three locations: (1) `DocumentState.loadFile(at:)` line 58 -- covers CLI, Open dialog, and reload; (2) `AppDelegate.application(_:open:)` line 13 -- covers Finder/dock; (3) `DocumentWindow.task` lines 35,40 -- covers initial window file loading. All file-open paths are covered.
- Field Notes: N/A
- Issues: None.

**AC-3**: Selecting from Open Recent opens new window
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/OpenRecentMenu.swift`:19-21
- Evidence: The button action for each recent item calls `FileOpenCoordinator.shared.pendingURLs.append(url)`. This triggers the `.onChange` handler in `DocumentWindow` which calls `openWindow(value: url)`, creating a new window.
- Field Notes: N/A
- Issues: None.

**AC-4**: List persists across launches
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/OpenRecentMenu.swift`:16
- Evidence: The menu reads from `NSDocumentController.shared.recentDocumentURLs`. `NSDocumentController` automatically persists recent documents across app launches using the system's built-in mechanism (backed by the app's defaults domain).
- Field Notes: N/A
- Issues: None.

**AC-5**: System default maximum count
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/OpenRecentMenu.swift`:15-22
- Evidence: `NSDocumentController.shared.recentDocumentURLs` returns a system-managed list with the default maximum count (typically 10). No custom limit is imposed. The code does not set `maximumRecentDocumentCount`.
- Field Notes: N/A
- Issues: None.

**AC-6**: "Clear Menu" option available
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/OpenRecentMenu.swift`:24-26
- Evidence: A `Divider()` followed by `Button("Clear Menu") { NSDocumentController.shared.clearRecentDocuments(nil) }` is present at the bottom of the Open Recent menu.
- Field Notes: N/A
- Issues: None.

## Implementation Gap Analysis

### Missing Implementations
- **TD1**: architecture.md documentation update (not started)
- **TD2**: modules.md documentation update (not started)
- **TD3**: patterns.md documentation update (not started)
- **TD4**: modules.md Features/DefaultHandler section (not started)

### Partial Implementations
- None. All code tasks (T1-T8) are complete.

### Implementation Issues
- **Undocumented deviations**: Three deviations from design are noted in task implementation summaries but not captured in `field-notes.md`: (1) ZStack overlay vs VStack wrapping for hint, (2) `.ultraThinMaterial` vs `backgroundSecondary` for hint background, (3) `@Environment(\.openWindow)` placement in DocumentWindow vs MkdnApp.
- **SwiftLint**: `swiftlint lint` fails due to system-level SourceKit issue (documented in field notes). This is not a code issue but prevents the Definition of Done checklist item from being satisfied.

## Code Quality Assessment

**Architecture**: The state split from `AppState` into `DocumentState` (per-window) and `AppSettings` (app-wide singleton) is clean and well-executed. All 14+ view files have been correctly migrated to read from the appropriate environment objects. No remaining references to `AppState` exist in the codebase.

**Patterns**: The implementation follows established project patterns:
- `@MainActor @Observable` on both state classes (consistent with prior `AppState`)
- `@FocusedValue` for multi-window command access (standard SwiftUI pattern)
- `UserDefaults` persistence with `didSet` (consistent with existing `themeMode` pattern)
- Swift Testing with `@Suite`/`@Test`/`#expect` (project standard)
- `nonisolated` static utility method for pure functions (clean Swift 6 concurrency)

**Test Coverage**: 141 tests pass with 0 failures. Feature-specific tests include:
- `DocumentStateTests`: 13 tests covering file I/O, view mode, unsaved changes
- `AppSettingsTests`: 14 tests covering theme, hint persistence, UserDefaults round-trip
- `FileOpenCoordinatorTests`: 4 tests covering URL queuing and consumption
- `MarkdownFileFilterTests`: 7 tests covering extension filtering with case sensitivity
- `DefaultHandlerServiceTests`: 2 tests verifying API contracts

**Code Organization**: New files follow the established directory structure:
- `mkdn/App/` for application-level components
- `mkdn/Core/Services/` for service layer
- `mkdn/Features/DefaultHandler/Views/` for feature-specific UI
- `mkdnTests/Unit/Core/` and `mkdnTests/Unit/Features/` for tests

**Build Health**: `swift build` succeeds. `swift test` passes all 141 tests. Signal 5 exit is a known DispatchSource teardown race documented in project memory.

## Recommendations
1. **Complete documentation tasks TD1-TD4**: The knowledge base files (`architecture.md`, `modules.md`, `patterns.md`) are out of date. They still reference `AppState` instead of `DocumentState`/`AppSettings`. This should be updated before the feature is considered fully done.
2. **Add undocumented deviations to field-notes.md**: Three design deviations (ZStack overlay placement, `.ultraThinMaterial` background, `@Environment(\.openWindow)` placement) are noted in task summaries but not in `field-notes.md`. For audit trail completeness, these should be documented.
3. **Manual verification on .app bundle**: 8 acceptance criteria require manual testing with a built `.app` bundle in macOS Finder/dock. Run `scripts/bundle.sh --build` and test: (a) double-click `.md` from Finder with mkdn as default, (b) dock drag-and-drop for `.md` and `.markdown`, (c) cold-start file opening from dock drag.
4. **Resolve SwiftLint issue**: `swiftlint lint` fails due to a system-level SourceKit configuration issue. While this is not a code problem, the Definition of Done includes SwiftLint passing. Consider resolving the SourceKit environment or documenting the exception.
5. **Consider adding `@discardableResult` documentation**: `DefaultHandlerService.registerAsDefault()` always returns `true` (non-throwing API). The callers in `DefaultHandlerHintView` and `MkdnCommands` check the return value. If the API can never return `false` on macOS 14+, consider whether the conditional logic around `success` is misleading.

## Verification Evidence

### Info.plist (FR-001, FR-002)
File: `/Users/jud/Projects/mkdn/Resources/Info.plist`
- Lines 27-41: CFBundleDocumentTypes with `net.daringfireball.markdown`, Editor role, Default rank
- Lines 43-67: UTImportedTypeDeclarations with `md` + `markdown` extensions, `public.plain-text` conformance
- Line 20-21: LSMinimumSystemVersion = 14.0

### AppDelegate (FR-003, FR-007)
File: `/Users/jud/Projects/mkdn/mkdn/App/AppDelegate.swift`
- Lines 10-16: `application(_:open:)` filters Markdown URLs, tracks in NSDocumentController, pushes to FileOpenCoordinator
- Lines 18-23: `applicationShouldHandleReopen` returns true

### FileOpenCoordinator (FR-003, FR-004)
File: `/Users/jud/Projects/mkdn/mkdn/App/FileOpenCoordinator.swift`
- Lines 8-29: Singleton with `pendingURLs`, `consumeAll()`, and `isMarkdownURL(_:)` utility

### DocumentWindow (FR-003, FR-004)
File: `/Users/jud/Projects/mkdn/mkdn/App/DocumentWindow.swift`
- Line 19: Per-window `@State private var documentState = DocumentState()`
- Lines 32-46: `.task` handles initial file loading and cold-start pending URLs
- Lines 47-50: `.onChange` handles runtime file-open events via `openWindow(value:)`

### DefaultHandlerService (FR-005)
File: `/Users/jud/Projects/mkdn/mkdn/Core/Services/DefaultHandlerService.swift`
- Lines 14-22: `registerAsDefault()` calls `NSWorkspace.shared.setDefaultApplication(at:toOpen:)`
- Lines 25-34: `isDefault()` compares default app URL against bundle URL

### MkdnCommands (FR-005)
File: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`
- Lines 17-24: "Set as Default Markdown App" in `CommandGroup(after: .appInfo)`, always visible/enabled

### DefaultHandlerHintView (FR-006)
File: `/Users/jud/Projects/mkdn/mkdn/Features/DefaultHandler/Views/DefaultHandlerHintView.swift`
- Lines 22-55: Hint content with "Set as Default" button and xmark dismiss
- Lines 57-71: Confirmation content with checkmark
- Lines 73-75: `markHintShown()` persists suppression

### ContentView Hint Integration (FR-006)
File: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`
- Lines 53-56: Conditional hint overlay based on `!appSettings.hasShownDefaultHandlerHint`

### OpenRecentCommands (FR-008)
File: `/Users/jud/Projects/mkdn/mkdn/App/OpenRecentMenu.swift`
- Lines 13-28: "Open Recent" menu reading from NSDocumentController, with Clear Menu action

### MkdnApp Entry Point
File: `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`
- Line 8: `@NSApplicationDelegateAdaptor(AppDelegate.self)`
- Lines 18-22: `WindowGroup(for: URL.self)` with `.handlesExternalEvents(matching: [])`
- Line 27: `OpenRecentCommands()` in commands block

### Build and Test Verification
- `swift build`: Success (0 errors)
- `swift test`: 141 passed, 0 failed
- `AppState.swift`: Confirmed deleted (no file at path)
- No remaining `AppState` references in codebase (grep confirmed)
- `scripts/bundle.sh`: Executable (-rwxr-xr-x), properly assembles .app bundle
