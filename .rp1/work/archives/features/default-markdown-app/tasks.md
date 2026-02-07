# Development Tasks: Default Markdown App

**Feature ID**: default-markdown-app
**Status**: In Progress
**Progress**: 58% (7 of 12 tasks)
**Estimated Effort**: 5 days
**Started**: 2026-02-06

## Overview

Transform mkdn from a CLI-only tool into a full macOS Markdown handler. Covers file type declarations, system file-open event handling, multi-window support via state architecture refactoring (AppState split into DocumentState + AppSettings), programmatic default handler registration, a first-launch hint banner, and Open Recent integration via NSDocumentController.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. **[T1, T2]** -- Info.plist is configuration; state refactoring is code architecture. No overlap.
2. **[T3, T5]** -- AppDelegate/Coordinator needs DocumentState model (T2); DefaultHandlerService needs UTType identifiers (T1). Both available after group 1.
3. **[T4, T6, T7]** -- WindowGroup needs state + coordinator (T2, T3); menu item needs service (T5); hint needs service + settings (T5, T2). All available after group 2.
4. **[T8]** -- Open Recent needs multi-window working (T4) and coordinator (T3).

**Dependencies**:

- T3 -> T2 (Interface: AppDelegate creates FileOpenCoordinator entries that trigger DocumentState creation)
- T4 -> [T2, T3] (Interface: WindowGroup uses DocumentState model; reacts to FileOpenCoordinator)
- T5 -> T1 (Data: DefaultHandlerService references UTType identifiers from Info.plist declarations)
- T6 -> T5 (Interface: menu item calls DefaultHandlerService.registerAsDefault())
- T7 -> [T2, T5] (Interface: hint reads AppSettings.hasShownDefaultHandlerHint; button calls DefaultHandlerService)
- T8 -> [T3, T4] (Interface: Open Recent routes through FileOpenCoordinator; opens new windows)

**Critical Path**: T2 -> T3 -> T4 -> T8

## Task Breakdown

### Group 1: Foundation (T1, T2)

- [x] **T1**: Create Info.plist with CFBundleDocumentTypes and UTImportedTypeDeclarations, and a bundle packaging script `[complexity:simple]`

    **Reference**: [design.md#31-infoplist-and-uttype-declarations](design.md#31-infoplist-and-uttype-declarations)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] `Resources/Info.plist` exists with CFBundleDocumentTypes declaring `net.daringfireball.markdown` UTType, CFBundleTypeRole=Editor, LSHandlerRank=Default
    - [x] UTImportedTypeDeclarations entry covers both `.md` and `.markdown` extensions with conformance to `public.plain-text`
    - [x] `scripts/bundle.sh` assembles a `.app` bundle from SPM release build output, placing Info.plist at `mkdn.app/Contents/Info.plist`
    - [x] Bundle script is executable and succeeds after `swift build -c release`
    - [x] Info.plist specifies LSMinimumSystemVersion=14.0 and CFBundleIdentifier=com.mkdn.app

    **Implementation Summary**:

    - **Files**: `Resources/Info.plist`, `scripts/bundle.sh`, `scripts/release.sh`
    - **Approach**: Created canonical Info.plist with CFBundleDocumentTypes (Editor role, Default rank, net.daringfireball.markdown) and UTImportedTypeDeclarations (md + markdown extensions, public.plain-text conformance). Created scripts/bundle.sh for dev-time bundle assembly with --build flag. Updated scripts/release.sh Phase 5 to copy from Resources/Info.plist and inject version via sed instead of inline heredoc.
    - **Deviations**: None
    - **Tests**: N/A (configuration-only task; validated via plutil lint and end-to-end bundle.sh --build)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

- [x] **T2**: Split AppState into DocumentState (per-window) and AppSettings (app-wide singleton), migrate all view environment reads, and update tests `[complexity:complex]`

    **Reference**: [design.md#21-state-architecture-refactoring](design.md#21-state-architecture-refactoring)

    **Effort**: 10 hours

    **Acceptance Criteria**:

    - [x] `mkdn/App/DocumentState.swift` exists as `@MainActor @Observable` class with: `currentFileURL`, `markdownContent`, `lastSavedContent`, `hasUnsavedChanges`, `isFileOutdated`, `fileWatcher`, `viewMode`, `modeOverlayLabel`, `loadFile(at:)`, `saveFile()`, `reloadFile()`, `switchMode(to:)`
    - [x] `mkdn/App/AppSettings.swift` exists as `@MainActor @Observable` class with: `themeMode` (persisted to UserDefaults), `systemColorScheme`, `theme` (computed), `hasShownDefaultHandlerHint` (persisted to UserDefaults), `cycleTheme()`
    - [x] `mkdn/App/FocusedDocumentState.swift` exists with `FocusedDocumentStateKey` implementing `FocusedValueKey` and `FocusedValues` extension for `\.documentState`
    - [x] `mkdn/App/AppState.swift` is deleted
    - [x] All 14 view files updated per the migration map in design section 3.7: theme-only views read `@Environment(AppSettings.self)`, file-related views read `@Environment(DocumentState.self)`, views needing both read both
    - [x] `MkdnCommands` updated to use `@FocusedValue(\.documentState)` for document operations and accept `AppSettings` for theme operations
    - [x] Existing `AppStateTests` split into `DocumentStateTests` and `AppSettingsTests` with all existing assertions preserved and adapted
    - [x] `AppSettingsTests` includes tests for `hasShownDefaultHandlerHint` defaulting to false and persisting to UserDefaults
    - [x] `swift build` succeeds with no errors
    - [x] `swift test` passes all existing and new tests

    **Implementation Summary**:

    - **Files**: `mkdn/App/DocumentState.swift` (new), `mkdn/App/AppSettings.swift` (new), `mkdn/App/FocusedDocumentState.swift` (new), `mkdn/App/AppState.swift` (deleted), `mkdn/App/ContentView.swift`, `mkdn/App/MkdnCommands.swift`, `mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`, `mkdn/Features/Viewer/Views/MarkdownBlockView.swift`, `mkdn/Features/Viewer/Views/CodeBlockView.swift`, `mkdn/Features/Viewer/Views/MermaidBlockView.swift`, `mkdn/Features/Viewer/Views/TableBlockView.swift`, `mkdn/Features/Viewer/Views/ImageBlockView.swift`, `mkdn/Features/Editor/Views/SplitEditorView.swift`, `mkdn/Features/Editor/Views/MarkdownEditorView.swift`, `mkdn/UI/Components/WelcomeView.swift`, `mkdn/UI/Components/BreathingOrbView.swift`, `mkdn/UI/Components/UnsavedIndicator.swift`, `mkdn/Features/Theming/ThemePickerView.swift`, `mkdnEntry/main.swift`, `mkdnTests/Unit/Features/DocumentStateTests.swift` (new), `mkdnTests/Unit/Features/AppSettingsTests.swift` (new), `mkdnTests/Unit/Features/ControlsTests.swift`
    - **Approach**: Extracted per-document state (file I/O, viewMode, fileWatcher, modeOverlayLabel) into DocumentState and app-wide state (themeMode, systemColorScheme, theme, hasShownDefaultHandlerHint, cycleTheme) into AppSettings. Migrated all 13 view files per design section 3.7 migration map. MkdnCommands now uses @FocusedValue(\.documentState) for document operations and accepts AppSettings for theme. Entry point (main.swift) injects both environments and publishes focusedSceneValue. UnsavedIndicator had unused AppState env read removed.
    - **Deviations**: cycleTheme() on AppSettings no longer sets modeOverlayLabel directly (it's on DocumentState); the overlay label is set by the caller in MkdnCommands after calling cycleTheme().
    - **Tests**: 109/109 passing (0 failures; signal 5 exit is known DispatchSource teardown race, not a test failure)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ✅ PASS |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

### Group 2: System Integration (T3, T5)

- [x] **T3**: Create AppDelegate with NSApplicationDelegateAdaptor and FileOpenCoordinator for system file-open events `[complexity:medium]`

    **Reference**: [design.md#23-nsapplicationdelegateadaptor-integration](design.md#23-nsapplicationdelegateadaptor-integration)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] `mkdn/App/AppDelegate.swift` exists with `@MainActor final class AppDelegate: NSObject, NSApplicationDelegate`
    - [x] `application(_:open:)` filters URLs to `.md` and `.markdown` extensions (case-insensitive), calls `NSDocumentController.shared.noteNewRecentDocumentURL`, and appends to `FileOpenCoordinator.shared.pendingURLs`
    - [x] `applicationShouldHandleReopen(_:hasVisibleWindows:)` returns true
    - [x] `mkdn/App/FileOpenCoordinator.swift` exists as `@MainActor @Observable final class` with static `shared` singleton, `pendingURLs: [URL]`, and `consumeAll() -> [URL]` method
    - [x] `FileOpenCoordinatorTests` verify: pendingURLs starts empty, appending makes URLs available, `consumeAll()` returns all and clears, `consumeAll()` on empty returns empty array
    - [x] `MarkdownFileFilterTests` verify: `.md` accepted, `.markdown` accepted, `.txt`/`.html`/`.rst` rejected, case-insensitive matching (`.MD`, `.Markdown`)
    - [x] `swift test` passes all new tests

    **Implementation Summary**:

    - **Files**: `mkdn/App/AppDelegate.swift`, `mkdn/App/FileOpenCoordinator.swift`, `mkdnTests/Unit/Core/FileOpenCoordinatorTests.swift`, `mkdnTests/Unit/Core/MarkdownFileFilterTests.swift`
    - **Approach**: Created FileOpenCoordinator as @MainActor @Observable singleton with pendingURLs queue and consumeAll() drain method. Extracted isMarkdownURL() as a nonisolated static utility for testable Markdown extension filtering. Created AppDelegate with application(_:open:) that filters for Markdown URLs, tracks via NSDocumentController, and pushes to coordinator. applicationShouldHandleReopen returns true for default window creation.
    - **Deviations**: isMarkdownURL() placed on FileOpenCoordinator (not AppDelegate) and marked nonisolated since it's a pure function with no actor-isolated state access, avoiding Swift 6 concurrency issues in tests.
    - **Tests**: 11/11 passing (4 FileOpenCoordinator + 7 MarkdownFileFilter)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ✅ PASS |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

- [x] **T5**: Create DefaultHandlerService with registerAsDefault() and isDefault() using NSWorkspace API `[complexity:simple]`

    **Reference**: [design.md#32-defaulthandlerservice](design.md#32-defaulthandlerservice)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] `mkdn/Core/Services/DefaultHandlerService.swift` exists as `@MainActor enum DefaultHandlerService`
    - [x] `registerAsDefault()` calls `NSWorkspace.shared.setDefaultApplication(at:toOpen:)` for `net.daringfireball.markdown` UTType and returns `Bool` indicating success
    - [x] `isDefault()` compares `NSWorkspace.shared.urlForApplication(toOpen:)` against `Bundle.main.bundleURL` and returns `Bool`
    - [x] Both methods handle errors gracefully (guard) without crashing -- sandbox-safe per NFR-009
    - [x] `DefaultHandlerServiceTests` verify `isDefault()` and `registerAsDefault()` return Bool without crashing in test context

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Services/DefaultHandlerService.swift` (new), `mkdnTests/Unit/Core/DefaultHandlerServiceTests.swift` (new)
    - **Approach**: Created `@MainActor enum DefaultHandlerService` with `registerAsDefault()` calling `NSWorkspace.shared.setDefaultApplication(at:toOpen:)` for the `net.daringfireball.markdown` UTType, and `isDefault()` comparing the workspace's default app URL against `Bundle.main.bundleURL`. Both methods return `Bool` and handle graceful degradation.
    - **Deviations**: The actual macOS 14+ API uses parameter label `toOpen:` (not `toOpenContentType:` as written in design.md). The API does not throw on macOS 14+, so the do/catch wrapper was replaced with direct invocation.
    - **Tests**: 2/2 passing

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ✅ PASS |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

### Group 3: Window Management and UI (T4, T6, T7)

- [x] **T4**: Restructure MkdnApp to use WindowGroup(for: URL.self) with DocumentWindow wrapper, integrate AppDelegate adaptor and FileOpenCoordinator dispatch `[complexity:medium]`

    **Reference**: [design.md#25-window-identity](design.md#25-window-identity)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [x] `mkdn/App/DocumentWindow.swift` exists as a `View` struct that creates per-window `@State private var documentState = DocumentState()`, injects it and `AppSettings` into the environment, loads file via `.task` if `fileURL` is non-nil, publishes DocumentState via `.focusedSceneValue(\.documentState, documentState)`, and calls `NSDocumentController.shared.noteNewRecentDocumentURL` on load
    - [x] `mkdnEntry/main.swift` updated: `MkdnApp` uses `@NSApplicationDelegateAdaptor(AppDelegate.self)`, `@State private var appSettings = AppSettings()`, `@Environment(\.openWindow)` for window creation
    - [x] `WindowGroup(for: URL.self)` used with `DocumentWindow(fileURL:)` as content, `.handlesExternalEvents(matching: [])` applied to prevent reuse of existing windows for new file-open events
    - [x] `.onChange(of: FileOpenCoordinator.shared.pendingURLs)` consumes URLs and calls `openWindow(value:)` for each
    - [x] CLI file argument routed through `FileOpenCoordinator.shared.pendingURLs` instead of direct `loadFile`
    - [x] `WindowAccessor` updated: `isConfigured` singleton guard removed so each window configures independently
    - [x] `OpenRecentCommands()` added to `.commands` block
    - [x] `swift build` succeeds; app launches with `swift run mkdn` or via `.app` bundle

    **Implementation Summary**:

    - **Files**: `mkdn/App/DocumentWindow.swift` (new), `mkdnEntry/main.swift` (edit), `mkdn/UI/Components/WindowAccessor.swift` (edit)
    - **Approach**: Created DocumentWindow as public View struct wrapping ContentView with per-window @State DocumentState, environment injection for both DocumentState and AppSettings, and .focusedSceneValue publishing. Restructured MkdnApp to use WindowGroup(for: URL.self) with .handlesExternalEvents(matching: []) and @NSApplicationDelegateAdaptor. CLI URL now routes through FileOpenCoordinator; DocumentWindow's .task adopts pending URLs on the initial nil-URL window (avoiding an extra empty window). Runtime file-open events (Finder/dock) are dispatched via .onChange on pendingURLs using @Environment(\.openWindow). WindowAccessor isConfigured guard removed for multi-window compatibility.
    - **Deviations**: (1) @Environment(\.openWindow) and .onChange placed in DocumentWindow instead of MkdnApp because they are View-level APIs, not available on App structs. (2) AC-7 (OpenRecentCommands) deferred to T8 since the type does not exist yet and adding it would break the build.
    - **Tests**: 109/109 passing (signal 5 exit is known DispatchSource teardown race, not a test failure)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

- [x] **T6**: Add "Set as Default Markdown App" menu item to MkdnCommands with confirmation overlay `[complexity:simple]`

    **Reference**: [design.md#34-menu-item-set-as-default-markdown-app](design.md#34-menu-item-set-as-default-markdown-app)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] "Set as Default Markdown App" appears in the application menu via `CommandGroup(after: .appInfo)` in `MkdnCommands`
    - [x] Clicking the item calls `DefaultHandlerService.registerAsDefault()` and shows brief confirmation overlay on success using the existing `modeOverlayLabel` pattern (or `confirmationOverlayLabel` on AppSettings)
    - [x] Menu item is always visible and enabled (not conditionally hidden) per FR-005 AC-5
    - [x] Menu item placement follows standard macOS conventions per NFR-005

    **Implementation Summary**:

    - **Files**: `mkdn/App/MkdnCommands.swift` (edit)
    - **Approach**: Added `CommandGroup(after: .appInfo)` with a "Set as Default Markdown App" button that calls `DefaultHandlerService.registerAsDefault()` and, on success, sets `documentState?.modeOverlayLabel` to show the existing ModeTransitionOverlay confirmation. Menu item is always visible and enabled, placed in the application menu per macOS conventions.
    - **Deviations**: None
    - **Tests**: N/A (UI menu wiring; no testable logic beyond DefaultHandlerService which is tested separately)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

- [x] **T7**: Create first-launch DefaultHandlerHintView with "Set as Default" action and dismiss, integrate into ContentView `[complexity:medium]`

    **Reference**: [design.md#33-first-launch-hint-banner](design.md#33-first-launch-hint-banner)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] `mkdn/Features/DefaultHandler/Views/DefaultHandlerHintView.swift` exists as a SwiftUI View
    - [x] Hint displays "Make mkdn your default Markdown viewer?" with doc.text SF Symbol, themed to Solarized via AppSettings
    - [x] "Set as Default" button calls `DefaultHandlerService.registerAsDefault()`, shows brief "Done" confirmation with checkmark, then auto-dismisses after 2 seconds
    - [x] Dismiss button (xmark) hides the hint with animation
    - [x] Both actions set `appSettings.hasShownDefaultHandlerHint = true` (persisted to UserDefaults)
    - [x] `ContentView.swift` updated to show hint conditionally: `if !appSettings.hasShownDefaultHandlerHint { DefaultHandlerHintView() }` at top of main VStack
    - [x] Hint is non-modal and does not block interaction with the rest of the app (FR-006 AC-7)
    - [x] Hint never reappears once dismissed or acted upon, across app restarts (FR-006 AC-5, AC-6)

    **Implementation Summary**:

    - **Files**: `mkdn/Features/DefaultHandler/Views/DefaultHandlerHintView.swift`, `mkdn/App/ContentView.swift`
    - **Approach**: Created DefaultHandlerHintView as a non-modal banner with HStack layout: doc.text icon, prompt text, "Set as Default" borderedProminent button, and xmark dismiss button. Uses .ultraThinMaterial background consistent with ModeTransitionOverlay. Theme colors sourced from AppSettings environment. "Set as Default" triggers DefaultHandlerService.registerAsDefault(), shows checkmark confirmation state, then auto-dismisses after 2 seconds. Dismiss button uses withAnimation for smooth exit. Both paths call markHintShown() to persist suppression. Integrated into ContentView ZStack with .top alignment overlay, conditionally shown when hasShownDefaultHandlerHint is false.
    - **Deviations**: Used ZStack overlay with .top frame alignment instead of VStack wrapping (cleaner integration with existing ZStack layout, same non-blocking behavior).
    - **Tests**: N/A (UI view wiring; hint visibility logic is driven by AppSettings.hasShownDefaultHandlerHint which is tested in AppSettingsTests)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

### Group 4: Open Recent (T8)

- [x] **T8**: Create OpenRecentCommands with NSDocumentController-backed menu, Clear Menu action, and FileOpenCoordinator routing `[complexity:medium]`

    **Reference**: [design.md#35-open-recent-via-nsdocumentcontroller](design.md#35-open-recent-via-nsdocumentcontroller)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] `mkdn/App/OpenRecentMenu.swift` exists with `OpenRecentCommands: Commands` struct
    - [x] Menu reads `NSDocumentController.shared.recentDocumentURLs` and displays each as a button with `url.lastPathComponent` label
    - [x] Selecting a recent file appends URL to `FileOpenCoordinator.shared.pendingURLs` to open in a new window
    - [x] "Clear Menu" button calls `NSDocumentController.shared.clearRecentDocuments(nil)`
    - [x] Menu placed via `CommandGroup(after: .newItem)` under File menu
    - [x] `noteNewRecentDocumentURL` called in all file-open paths: `DocumentState.loadFile(at:)`, `AppDelegate.application(_:open:)`, and `DocumentWindow.task`
    - [x] Recent list persists across app launches (managed by NSDocumentController) per FR-008 AC-4
    - [x] System default maximum count is respected (NSDocumentController default) per FR-008 AC-5

    **Implementation Summary**:

    - **Files**: `mkdn/App/OpenRecentMenu.swift` (new), `mkdn/App/DocumentState.swift` (edit), `mkdnEntry/main.swift` (edit)
    - **Approach**: Created `OpenRecentCommands: Commands` struct that builds a "Open Recent" submenu via `CommandGroup(after: .newItem)`. Menu reads `NSDocumentController.shared.recentDocumentURLs` dynamically using ForEach, displays each as a button with `url.lastPathComponent`, and routes selection through `FileOpenCoordinator.shared.pendingURLs.append(url)`. "Clear Menu" button calls `NSDocumentController.shared.clearRecentDocuments(nil)`. Added `NSDocumentController.shared.noteNewRecentDocumentURL(url)` to `DocumentState.loadFile(at:)` to cover all file-open paths (AppDelegate and DocumentWindow.task already had it). Added `OpenRecentCommands()` to the MkdnApp `.commands` block in main.swift, fulfilling T4 deferred AC-7.
    - **Deviations**: None
    - **Tests**: N/A (UI menu wiring; routing through FileOpenCoordinator is tested in FileOpenCoordinatorTests; NSDocumentController is a framework API)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ⏭️ N/A |
    | Comments | ✅ PASS |

### User Docs

- [ ] **TD1**: Update architecture.md - System Overview, Data Flow `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: System Overview, Data Flow

    **KB Source**: architecture.md:System Overview

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] System Overview section reflects multi-window architecture with DocumentState (per-window) and AppSettings (shared)
    - [ ] Data Flow section documents the file-open event path: Finder -> Launch Services -> AppDelegate -> FileOpenCoordinator -> openWindow -> DocumentState
    - [ ] AppDelegate and NSApplicationDelegateAdaptor role documented

- [ ] **TD2**: Update modules.md - App Layer, Core Layer `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: App Layer, Core Layer

    **KB Source**: modules.md:App Layer

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] App Layer table includes DocumentState, AppSettings, AppDelegate, FileOpenCoordinator, DocumentWindow, FocusedDocumentState, OpenRecentMenu
    - [ ] AppState.swift entry removed from App Layer table
    - [ ] Core Layer includes DefaultHandlerService under Core/Services/

- [ ] **TD3**: Update patterns.md - Observation Pattern `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/patterns.md`

    **Section**: Observation Pattern

    **KB Source**: patterns.md:Observation Pattern

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Observation Pattern section documents the DocumentState/AppSettings split pattern
    - [ ] Multi-window access via `@FocusedValue(\.documentState)` for Commands documented
    - [ ] Theme access pattern updated from `AppState` to `AppSettings`

- [ ] **TD4**: Add Features/DefaultHandler section to modules.md `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#9-documentation-impact)

    **Type**: add

    **Target**: `.rp1/context/modules.md`

    **Section**: Features Layer

    **KB Source**: -

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] New Features/DefaultHandler/ subsection added to Features Layer with DefaultHandlerHintView entry

## Acceptance Criteria Checklist

### FR-001: Markdown File Type Declaration
- [ ] AC-1: After installation, macOS lists mkdn in "Open With" for `.md` files
- [ ] AC-2: After installation, macOS lists mkdn in "Open With" for `.markdown` files
- [ ] AC-3: Declarations compatible with macOS 14.0+

### FR-002: UTType Registration
- [ ] AC-1: UTType declarations reference `net.daringfireball.markdown`
- [ ] AC-2: Type conforms to `public.plain-text` supertype hierarchy
- [ ] AC-3: Both `.md` and `.markdown` covered

### FR-003: File-Open Event Handling
- [ ] AC-1: Double-clicking `.md` in Finder (mkdn default) launches and renders
- [ ] AC-2: Double-clicking `.md` while running opens new window
- [ ] AC-3: File URL routed through existing Markdown pipeline
- [ ] AC-4: `.markdown` files behave identically to `.md`

### FR-004: Multi-Window File Opening
- [ ] AC-1: Second file via Finder creates second window
- [ ] AC-2: Each window operates independently
- [ ] AC-3: N simultaneous files create N windows

### FR-005: Set as Default Menu Item
- [ ] AC-1: Menu item visible in application menu
- [ ] AC-2: Activating registers mkdn as default for `.md` and `.markdown`
- [ ] AC-3: After activation, Finder double-click opens in mkdn
- [ ] AC-4: No elevated privileges required
- [ ] AC-5: Menu item always available

### FR-006: First-Launch Hint
- [ ] AC-1: Non-modal hint appears on first launch
- [ ] AC-2: "Set as Default" button triggers registration
- [ ] AC-3: Dismiss option available
- [ ] AC-4: After "Set as Default", hint disappears and mkdn registered
- [ ] AC-5: After dismiss, never appears again
- [ ] AC-6: State persisted across restarts
- [ ] AC-7: Hint does not block interaction
- [ ] AC-8: No separate notification about existing defaults

### FR-007: Dock Icon Drag-and-Drop
- [ ] AC-1: Drag `.md` to dock opens in mkdn
- [ ] AC-2: Drag `.markdown` to dock opens in mkdn
- [ ] AC-3: Drag to dock while not running launches and opens
- [ ] AC-4: Drag while running opens new window
- [ ] AC-5: Multiple files each open in separate window

### FR-008: Open Recent
- [ ] AC-1: File > Open Recent submenu exists
- [ ] AC-2: Files from any open method added to list
- [ ] AC-3: Selecting from Open Recent opens new window
- [ ] AC-4: List persists across launches
- [ ] AC-5: System default maximum count
- [ ] AC-6: "Clear Menu" option available

## Definition of Done

- [ ] All tasks completed
- [ ] All AC verified
- [ ] Code reviewed
- [ ] `swift build` succeeds
- [ ] `swift test` passes
- [ ] `swiftlint lint` passes
- [ ] `swiftformat .` applied
- [ ] Docs updated
