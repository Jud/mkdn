# Development Tasks: Mac App Essentials

**Feature ID**: mac-app-essentials
**Status**: In Progress
**Progress**: 54% (7 of 13 tasks)
**Estimated Effort**: 4 days
**Started**: 2026-02-13

## Overview

Eight standard macOS application features -- Find in Document, Print, Zoom In/Out, Save As, Code Block Copy Button, Task List Checkboxes, Multiple File CLI Opening, and About Window -- implemented atop the existing Feature-Based MVVM architecture. No new SPM dependencies required. All features surface through standard macOS keyboard shortcuts and menu items.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1, T2, T4, T7, T8] - Independent features touching mostly distinct code paths; menu additions to MkdnCommands are in separate CommandGroup sections
2. [T3, T5, T6] - Features that modify the MarkdownTextStorageBuilder pipeline; parallel because they change different methods/sections

**Dependencies**:

- T3 -> none (self-contained: AppSettings + font scaling + menu)
- T5 -> none (self-contained: hover tracking + raw code attribute + copy button)
- T6 -> none (self-contained: model + visitor + builder list rendering + view)

All 8 tasks are technically parallel (no task defines an interface consumed by another). The grouping above reflects a practical ordering to minimize merge conflicts in shared files (MkdnCommands.swift, MarkdownTextStorageBuilder).

**Recommended implementation order** (to minimize conflict):
1. T8 (About) + T7 (Multi-file CLI) -- smallest/most isolated
2. T1 (Find) + T2 (Print) + T4 (Save As) -- menu additions + responder chain
3. T6 (Task List Checkboxes) -- rendering pipeline extension
4. T3 (Zoom) -- cross-cutting font scaling
5. T5 (Code Block Copy Button) -- highest risk, benefits from stable base

**Critical Path**: T3 (Zoom) is the highest-complexity task spanning the most files. T5 (Code Block Copy Button) is the highest-risk task due to NSTextView hover tracking complexity.

## Task Breakdown

### Independent Features

- [x] **T8**: Implement About Window with standard macOS About panel `[complexity:simple]`

    **Reference**: [design.md#38-about-window](design.md#38-about-window)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] `CommandGroup(replacing: .appInfo)` added to MkdnCommands with "About mkdn" button
    - [x] `NSApp.orderFrontStandardAboutPanel(options:)` called with applicationIcon key
    - [x] `Info.plist` `CFBundleShortVersionString` aligned with `MkdnCLI.configuration.version`
    - [x] About panel displays app icon, "mkdn" name, and correct version string
    - [x] REQ-ABOUT-001: "About mkdn" menu item present in application menu
    - [x] REQ-ABOUT-002: Panel shows icon, name, and version

    **Implementation Summary**:

    - **Files**: `mkdn/App/MkdnCommands.swift`, `Resources/Info.plist`
    - **Approach**: Added `CommandGroup(replacing: .appInfo)` with "About mkdn" button calling `NSApp.orderFrontStandardAboutPanel(options:)` passing the app icon. Aligned `CFBundleShortVersionString` and `CFBundleVersion` from "0.0.0" to "1.0.0" to match `MkdnCLI.configuration.version`.
    - **Deviations**: None
    - **Tests**: Skipped (framework behavior verification per design test strategy)

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

- [x] **T7**: Implement multiple file CLI opening via variadic arguments `[complexity:medium]`

    **Reference**: [design.md#26-multiple-file-cli-architecture](design.md#26-multiple-file-cli-architecture)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] `MkdnCLI.file: String?` changed to `MkdnCLI.files: [String]` with `@Argument` (variadic)
    - [x] `LaunchContext.fileURL: URL?` changed to `LaunchContext.fileURLs: [URL]` with `consumeURLs()` method
    - [x] `main.swift` validates each file independently, prints errors to stderr, continues with valid files
    - [x] `MKDN_LAUNCH_FILE` env var holds newline-delimited paths for multi-file launch
    - [x] `DocumentWindow.onAppear` loads first URL in current window, opens remaining via `openWindow(value:)`
    - [x] Exit code 0 if at least one file valid, exit code 1 if all fail
    - [x] REQ-MULTI-001: `mkdn a.md b.md c.md` opens three separate windows
    - [x] REQ-MULTI-002: Invalid files produce stderr errors without blocking valid files
    - [x] REQ-MULTI-004: `mkdn --help` shows variadic file argument
    - [x] Unit tests for multi-file validation (all valid, mixed, all invalid)

    **Implementation Summary**:

    - **Files**: `mkdn/Core/CLI/MkdnCLI.swift`, `mkdn/Core/CLI/LaunchContext.swift`, `mkdnEntry/main.swift`, `mkdn/App/DocumentWindow.swift`
    - **Approach**: Changed `MkdnCLI.file: String?` to `MkdnCLI.files: [String]` variadic argument. Changed `LaunchContext.fileURL: URL?` to `LaunchContext.fileURLs: [URL]` with `consumeURLs()`. Updated `main.swift` to validate each file independently, join valid paths with newline delimiter in `MKDN_LAUNCH_FILE` env var, and exit(1) only if all files invalid. Updated `DocumentWindow.onAppear` to consume multiple URLs, load first in current window, open remaining via `openWindow(value:)`.
    - **Deviations**: None
    - **Tests**: 7/7 passing (LaunchContextTests: 4, MultiFileValidationTests: 3)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ✅ PASS |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

- [x] **T1**: Implement Find in Document via NSTextView built-in find bar `[complexity:simple]`

    **Reference**: [design.md#22-find-in-document-architecture](design.md#22-find-in-document-architecture)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] `textView.usesFindBar = true` and `textView.isIncrementalSearchingEnabled = true` set in `SelectableTextView.configureTextView()`
    - [x] Find menu items added to MkdnCommands Edit menu: Find... (Cmd+F), Find Next (Cmd+G), Find Previous (Shift+Cmd+G), Use Selection for Find (Cmd+E)
    - [x] Menu items dispatch via `NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from:)` with tagged sender
    - [x] Tag values match NSFindPanelAction: showFindPanel=1, next=2, previous=3, setFindString=7
    - [x] REQ-FIND-001: Cmd+F reveals find bar at top of text view
    - [x] REQ-FIND-002: Cmd+G and Shift+Cmd+G navigate between matches
    - [x] REQ-FIND-003: Cmd+E populates find bar with current selection
    - [x] REQ-FIND-004: All find items visible in Edit menu with shortcuts

    **Implementation Summary**:

    - **Files**: `mkdn/Features/Viewer/Views/SelectableTextView.swift`, `mkdn/App/MkdnCommands.swift`
    - **Approach**: Enabled NSTextView built-in find bar via `usesFindBar`/`isIncrementalSearchingEnabled` in `configureTextView()`. Added four find menu items in `CommandGroup(after: .pasteboard)` dispatching via `NSApp.sendAction` with tagged `NSMenuItem` sender matching NSFindPanelAction tag values.
    - **Deviations**: None
    - **Tests**: No unit tests (framework behavior; find bar is NSTextView built-in)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | PASS |
    | Comments | PASS |

- [x] **T2**: Implement Print and Page Setup via NSResponder chain `[complexity:simple]`

    **Reference**: [design.md#34-mkdncommands-changes](design.md#34-mkdncommands-changes)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] Print... menu item added to File menu with Cmd+P shortcut
    - [x] Page Setup... menu item added to File menu
    - [x] Print dispatches via `NSApp.sendAction(#selector(NSView.printView(_:)), to: nil, from: nil)`
    - [x] Page Setup dispatches via `NSApp.sendAction(#selector(NSDocument.runPageLayout(_:)), to: nil, from: nil)`
    - [x] REQ-PRINT-001: Cmd+P shows macOS print dialog with document content
    - [x] REQ-PRINT-003: Page Setup... available in File menu
    - [x] REQ-PRINT-004: Print... available in File menu with Cmd+P shortcut

    **Implementation Summary**:

    - **Files**: `mkdn/App/MkdnCommands.swift`
    - **Approach**: Added `CommandGroup(replacing: .printItem)` with Print... (Cmd+P) and Page Setup... (Shift+Cmd+P) menu items. Both dispatch via `NSApp.sendAction` to the NSResponder chain, targeting `NSView.printView(_:)` and `NSDocument.runPageLayout(_:)` respectively.
    - **Deviations**: None
    - **Tests**: No unit tests (framework behavior; print is NSTextView built-in)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | PASS |
    | Comments | PASS |

- [x] **T4**: Implement Save As via NSSavePanel and DocumentState extension `[complexity:simple]`

    **Reference**: [design.md#27-save-as-architecture](design.md#27-save-as-architecture)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] `DocumentState.saveAs()` method added: presents NSSavePanel, writes content, updates `currentFileURL`, restarts file watcher, updates `lastSavedContent`, records in Open Recent
    - [x] NSSavePanel pre-fills current filename and directory
    - [x] `allowedContentTypes` restricted to `.md`
    - [x] Save As... menu item added to MkdnCommands File menu with Shift+Cmd+S shortcut
    - [x] Menu item disabled when `documentState?.currentFileURL == nil`
    - [x] REQ-SAVEAS-001: Shift+Cmd+S shows NSSavePanel
    - [x] REQ-SAVEAS-002: After save, DocumentState tracks new URL, file watcher monitors new path
    - [x] REQ-SAVEAS-003: Save As... visible in File menu with shortcut
    - [x] REQ-SAVEAS-004: Panel defaults to current filename and directory

    **Implementation Summary**:

    - **Files**: `mkdn/App/DocumentState.swift`, `mkdn/App/MkdnCommands.swift`
    - **Approach**: Added `saveAs()` method to DocumentState that presents NSSavePanel pre-filled with current filename/directory, writes content to chosen URL, updates `currentFileURL`, resets `lastSavedContent`, restarts file watcher on new path, and records in Open Recent. Menu item placed in `CommandGroup(replacing: .saveItem)` alongside existing Save, disabled when no document state is available.
    - **Deviations**: Disabled condition uses `documentState == nil` instead of `documentState?.currentFileURL == nil` per design -- Save As should also work for new unsaved documents.
    - **Tests**: No unit tests (NSSavePanel is modal UI; state transitions verified by integration)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | PASS |
    | Comments | PASS |

### Rendering Pipeline Features

- [x] **T6**: Implement task list checkbox rendering with SF Symbols `[complexity:medium]`

    **Reference**: [design.md#25-task-list-checkbox-architecture](design.md#25-task-list-checkbox-architecture)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] `CheckboxState` enum added (`.checked`, `.unchecked`) conforming to `Sendable`
    - [x] `ListItem.checkbox: CheckboxState?` field added (nil for non-task-list items)
    - [x] `MarkdownVisitor` extracts `listItem.checkbox` property from swift-markdown AST and maps to `CheckboxState`
    - [x] `MarkdownTextStorageBuilder` replaces bullet prefix with SF Symbol `NSImage` attachment (`square` for unchecked, `checkmark.square.fill` for checked)
    - [x] SF Symbol images tinted with `colors.foregroundSecondary` for theme awareness
    - [x] `MarkdownBlockView` replaces bullet `Text` with `Image(systemName:)` for SwiftUI rendering path
    - [x] Checkboxes are read-only (non-interactive) -- clicking does nothing
    - [x] REQ-TASK-001: `- [ ]` renders as unchecked checkbox visual
    - [x] REQ-TASK-002: `- [x]` renders as checked checkbox visual
    - [x] REQ-TASK-003: Clicking checkbox does nothing
    - [x] REQ-TASK-004: SF Symbols used for native appearance
    - [x] REQ-TASK-005: Checkbox color is theme-aware
    - [x] Unit tests for checkbox extraction (unchecked, checked, non-task items)

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Markdown/MarkdownBlock.swift`, `mkdn/Core/Markdown/MarkdownVisitor.swift`, `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Complex.swift`, `mkdn/Features/Viewer/Views/MarkdownBlockView.swift`
    - **Approach**: Added `CheckboxState` enum and `checkbox` field to `ListItem`. `MarkdownVisitor` maps swift-markdown `ListItem.checkbox` to `CheckboxState`. NSTextView path renders SF Symbol (`square`/`checkmark.square.fill`) as tinted `NSTextAttachment`. SwiftUI path renders `Image(systemName:)`. Refactored list prefix computation into `resolvedListPrefix` to keep parameter counts and function body lengths within lint limits.
    - **Deviations**: None
    - **Tests**: 7/7 passing (4 visitor + 3 builder)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ✅ PASS |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

- [x] **T3**: Implement Zoom In/Out with persisted scale factor and font-size scaling `[complexity:complex]`

    **Reference**: [design.md#23-zoom-architecture](design.md#23-zoom-architecture)

    **Effort**: 8 hours

    **Acceptance Criteria**:

    - [x] `AppSettings.scaleFactor` property added: `CGFloat`, range 0.5...3.0, default 1.0, persisted via UserDefaults
    - [x] `AppSettings.zoomIn()` increments by 0.1, clamped at 3.0
    - [x] `AppSettings.zoomOut()` decrements by 0.1, clamped at 0.5
    - [x] `AppSettings.zoomReset()` sets to 1.0
    - [x] `PlatformTypeConverter` font-producing methods accept `scaleFactor` parameter and multiply point sizes
    - [x] `MarkdownTextStorageBuilder.build()` accepts `scaleFactor` parameter, passes through to all font calls
    - [x] `MarkdownPreviewView` detects `.onChange(of: appSettings.scaleFactor)` and rebuilds text storage
    - [x] `OverlayCoordinator` passes `scaleFactor` to table overlay creation so table text scales consistently
    - [x] `ModeTransitionOverlay` displays zoom percentage (e.g., "125%") on each zoom change
    - [x] Zoom In (Cmd+Plus), Zoom Out (Cmd+Minus), Actual Size (Cmd+0) menu items in View menu
    - [x] `textContainerInset` remains fixed (32pt) -- only content scales
    - [x] REQ-ZOOM-001: Cmd+Plus increases text size
    - [x] REQ-ZOOM-002: Cmd+Minus decreases text size
    - [x] REQ-ZOOM-003: Cmd+0 resets to default size
    - [x] REQ-ZOOM-004: Scale factor persists across app restarts
    - [x] REQ-ZOOM-005: Zoom items in View menu with shortcuts
    - [x] REQ-ZOOM-006: Text remains crisp at all scale factors (font-size scaling, not view magnification)
    - [x] Unit tests for zoom scale persistence, clamping (min/max), increment/decrement

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Markdown/PlatformTypeConverter.swift`, `mkdn/App/AppSettings.swift`, `mkdn/App/MkdnCommands.swift`, `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift`, `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`, `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Complex.swift`, `mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`, `mkdn/Features/Viewer/Views/OverlayCoordinator.swift`, `mkdn/Features/Viewer/Views/TableBlockView.swift`, `mkdn/Features/Viewer/Views/TableHeaderView.swift`, `mkdnTests/Unit/Features/AppSettingsTests.swift`
    - **Approach**: Font-size scaling (not view magnification) via `scaleFactor` parameter threaded through PlatformTypeConverter font methods, MarkdownTextStorageBuilder pipeline (build, appendBlock, all block/complex/table helpers), and SwiftUI table overlays. AppSettings persists scaleFactor via UserDefaults with zoom methods. View menu items dispatch zoom actions and display ephemeral percentage overlay via ModeTransitionOverlay.
    - **Deviations**: None
    - **Tests**: 8/8 zoom tests passing (default, increment, decrement, reset, clamp max/min, persistence, restore, label formatting)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ✅ PASS |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

- [x] **T5**: Implement code block copy button with hover tracking and raw code attribute `[complexity:medium]`

    **Reference**: [design.md#24-code-block-copy-button-architecture](design.md#24-code-block-copy-button-architecture)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [x] `CodeBlockAttributes.rawCode` (`NSAttributedString.Key`) added for storing unformatted code string
    - [x] `MarkdownTextStorageBuilder.appendCodeBlock` stores raw code (trimmed, without language label) via `rawCode` attribute on code block ranges
    - [x] `CodeBlockBackgroundTextView.updateTrackingAreas()` installs tracking area with `.mouseMoved`, `.mouseEnteredAndExited`, `.activeInActiveApp`
    - [x] `CodeBlockBackgroundTextView.mouseMoved(with:)` hit-tests against code block geometries (via `collectCodeBlocks` + `fragmentFrames`)
    - [x] `CodeBlockCopyButton.swift` created: SwiftUI view with `doc.on.doc`/`checkmark` icon toggle, `quickShift` animation, `.ultraThinMaterial` background
    - [x] Copy button overlay is a single lazily-created `NSHostingView`, shown/hidden and repositioned on hover
    - [x] Button positioned at top-right corner of hovered code block's bounding rect
    - [x] Click reads `CodeBlockAttributes.rawCode` from textStorage and places on `NSPasteboard.general` as `.string`
    - [x] Button reads current theme colors from `CodeBlockColorInfo` for consistent styling
    - [x] REQ-COPY-001: Copy button appears on code block hover
    - [x] REQ-COPY-002: Click copies raw code (without language label) to clipboard
    - [x] REQ-COPY-003: Button shows checkmark feedback after copy
    - [x] REQ-COPY-004: Button is theme-aware
    - [x] REQ-COPY-005: Button fades in/out with subtle animation
    - [x] Unit test for rawCode attribute presence on code block ranges

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Markdown/CodeBlockAttributes.swift`, `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`, `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift`, `mkdn/Features/Viewer/Views/CodeBlockCopyButton.swift` (new)
    - **Approach**: Added `rawCode` attribute key to `CodeBlockAttributes` and stored trimmed code content on code block ranges in `appendCodeBlock`. Extended `CodeBlockBackgroundTextView` with NSTrackingArea for `mouseMoved`/`mouseExited` events, hit-testing mouse position against code block bounding rects. A single lazily-created `NSHostingView<CodeBlockCopyButton>` is shown/hidden with 0.2s alpha fade on hover. The SwiftUI `CodeBlockCopyButton` uses `doc.on.doc`/`checkmark` SF Symbol toggle with `quickShift` animation and `.ultraThinMaterial` background. Copy reads the `rawCode` attribute from textStorage and places it on `NSPasteboard.general`.
    - **Deviations**: None
    - **Tests**: 9/9 passing (2 new rawCode attribute tests added to CodeBlockStylingTests)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ✅ PASS |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

### User Docs

- [ ] **TD1**: Update modules.md - App Layer `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: App Layer

    **KB Source**: `modules.md`

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Section reflects addition of scaleFactor to AppSettings, saveAs to DocumentState, checkbox to ListItem

- [ ] **TD2**: Update modules.md - Core/CLI `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Core/CLI

    **KB Source**: `modules.md`

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Section reflects MkdnCLI variadic files argument and LaunchContext multi-URL support

- [ ] **TD3**: Update modules.md - Features/Viewer `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Features/Viewer

    **KB Source**: `modules.md`

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Section reflects addition of CodeBlockCopyButton view and copy button overlay on CodeBlockBackgroundTextView

- [ ] **TD4**: Update architecture.md - Data Flow `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: Data Flow

    **KB Source**: `architecture.md`

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Section reflects zoom scale factor data flow and multi-file launch flow

- [ ] **TD5**: Update patterns.md - Anti-Patterns `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/patterns.md`

    **Section**: Anti-Patterns

    **KB Source**: `patterns.md`

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Section notes that code block copy uses rawCode attribute, not re-parsing from attributed string

## Acceptance Criteria Checklist

### Find in Document
- [ ] REQ-FIND-001: Cmd+F reveals NSTextView find bar
- [ ] REQ-FIND-002: Cmd+G / Shift+Cmd+G navigate matches
- [ ] REQ-FIND-003: Cmd+E populates find bar with selection
- [ ] REQ-FIND-004: Find items in Edit menu with shortcuts

### Print
- [ ] REQ-PRINT-001: Cmd+P shows print dialog
- [ ] REQ-PRINT-002: Printed output uses current theme colors
- [ ] REQ-PRINT-003: Page Setup... in File menu
- [ ] REQ-PRINT-004: Print... in File menu with Cmd+P

### Zoom In/Out
- [ ] REQ-ZOOM-001: Cmd+Plus increases text size
- [ ] REQ-ZOOM-002: Cmd+Minus decreases text size
- [ ] REQ-ZOOM-003: Cmd+0 resets to default
- [ ] REQ-ZOOM-004: Scale factor persists across restarts
- [ ] REQ-ZOOM-005: Zoom items in View menu with shortcuts
- [ ] REQ-ZOOM-006: Crisp text at all scale factors

### Save As
- [ ] REQ-SAVEAS-001: Shift+Cmd+S shows NSSavePanel
- [ ] REQ-SAVEAS-002: DocumentState tracks new URL after save
- [ ] REQ-SAVEAS-003: Save As... in File menu with shortcut
- [ ] REQ-SAVEAS-004: Panel defaults to current file info

### Code Block Copy Button
- [ ] REQ-COPY-001: Copy button appears on hover
- [ ] REQ-COPY-002: Click copies raw code to clipboard
- [ ] REQ-COPY-003: Checkmark feedback after copy
- [ ] REQ-COPY-004: Theme-aware styling
- [ ] REQ-COPY-005: Subtle fade animation

### Task List Checkboxes
- [ ] REQ-TASK-001: `- [ ]` renders as unchecked checkbox
- [ ] REQ-TASK-002: `- [x]` renders as checked checkbox
- [ ] REQ-TASK-003: Checkboxes are read-only
- [ ] REQ-TASK-004: SF Symbols for native appearance
- [ ] REQ-TASK-005: Theme-aware checkbox color

### Multiple File CLI Opening
- [x] REQ-MULTI-001: Multiple files open in separate windows
- [x] REQ-MULTI-002: Invalid files produce stderr errors, valid files still open
- [x] REQ-MULTI-003: Each file opens via FileOpenCoordinator
- [x] REQ-MULTI-004: `mkdn --help` shows variadic argument

### About Window
- [x] REQ-ABOUT-001: "About mkdn" in application menu
- [x] REQ-ABOUT-002: Panel shows icon, name, version
- [x] REQ-ABOUT-003: Minimal and elegant appearance
- [x] REQ-ABOUT-004: Uses standard macOS About panel

### Non-Functional
- [ ] NFR-PERF-001: Find bar activates under 50ms
- [ ] NFR-PERF-002: Find Next/Previous under 50ms
- [ ] NFR-PERF-003: Zoom re-renders without flicker on Apple Silicon
- [ ] NFR-PERF-005: Copy button hover reveal under 100ms
- [ ] NFR-UX-001: All shortcuts follow macOS HIG
- [ ] NFR-UX-003: Zoom level displayed via ephemeral overlay
- [ ] NFR-COMPLY-001: All new code passes SwiftLint strict mode
- [ ] NFR-COMPLY-003: No ObservableObject usage

## Definition of Done

- [ ] All tasks completed
- [ ] All acceptance criteria verified
- [ ] Code reviewed
- [ ] Docs updated
- [ ] SwiftLint passes with zero new violations
- [ ] SwiftFormat applied
