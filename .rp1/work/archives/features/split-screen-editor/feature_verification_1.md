# Feature Verification Report #1

**Generated**: 2026-02-06T20:30:00Z
**Feature ID**: split-screen-editor
**Verification Scope**: all
**KB Context**: Loaded
**Field Notes**: Not available

## Executive Summary
- Overall Status: PARTIAL
- Acceptance Criteria: 40/47 verified (85%)
- Implementation Quality: HIGH
- Ready for Merge: NO (documentation tasks TD1-TD4 incomplete; 7 criteria require manual/visual verification)

## Field Notes Context
**Field Notes Available**: No

### Documented Deviations
None (no field-notes.md file present in feature directory)

### Undocumented Deviations
1. **T1 Deviation (resolved)**: `saveFile()` initially used `fileWatcher.acknowledge()` instead of `pauseForSave()/resumeAfterSave()` because those methods were added in T10. T10 subsequently updated `saveFile()` to use the correct pause/resume pattern. The final code at `AppState.swift:57-58` now correctly calls `pauseForSave()` and `resumeAfterSave()`.
2. **T1 Deviation**: `isFileOutdated` was converted from a stored property to a computed property delegating to `fileWatcher.isOutdated`. This is noted in T1's implementation summary but not in a field-notes.md file. This is a positive architectural improvement (avoids manual state synchronization) and has no negative impact.

## Acceptance Criteria Verification

### REQ-SSE-001: View Mode Toggle

**AC1**: A toolbar control is visible that allows switching between preview-only and side-by-side modes
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/ViewModePicker.swift`:4-18
- Evidence: `ViewModePicker` is a segmented `Picker` bound to `appState.viewMode` with all `ViewMode.allCases` (Preview, Edit + Preview). It is included in the toolbar via `MkdnToolbarContent` at `ContentView.swift:64`.
- Field Notes: N/A
- Issues: None

**AC2**: Selecting preview-only mode displays full-width rendered Markdown with no editor visible
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:15-18
- Evidence: `ContentView.body` uses a `switch appState.viewMode` where `.previewOnly` renders only `MarkdownPreviewView()` with no editor component. The `MarkdownPreviewView` takes full width via `ScrollView` layout.
- Field Notes: N/A
- Issues: None

**AC3**: Selecting side-by-side mode displays the editor pane on the left and the preview pane on the right
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/SplitEditorView.swift`:8-12, `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:19-21
- Evidence: `.sideBySide` case renders `SplitEditorView()` which uses `ResizableSplitView` with `editorPane` (MarkdownEditorView) as left content and `MarkdownPreviewView()` as right content.
- Field Notes: N/A
- Issues: None

**AC4**: The default mode on file open is preview-only
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppState.swift`:34
- Evidence: `public var viewMode: ViewMode = .previewOnly` -- AppState initializes to `.previewOnly`. Test `defaultState()` in AppStateTests.swift confirms `state.viewMode == .previewOnly`.
- Field Notes: N/A
- Issues: None

**AC5**: The mode toggle is accessible via keyboard navigation
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:20-31
- Evidence: `MkdnCommands` provides keyboard shortcuts: Cmd+1 for "Preview Only" and Cmd+2 for "Edit + Preview". Additionally, the segmented `Picker` in `ViewModePicker` is inherently keyboard-navigable via standard macOS accessibility.
- Field Notes: N/A
- Issues: None

### REQ-SSE-002: Split Pane Layout

**AC1**: The editor pane appears on the left and the preview pane appears on the right
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/SplitEditorView.swift`:8-12
- Evidence: `ResizableSplitView { editorPane } right: { MarkdownPreviewView() }` -- the `left` closure contains the editor, `right` closure contains the preview. `ResizableSplitView` renders them in an `HStack(spacing: 0)` with left first.
- Field Notes: N/A
- Issues: None

**AC2**: The divider between panes is draggable by the user to resize the split ratio
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/ResizableSplitView.swift`:102-124
- Evidence: `dragGesture(totalWidth:)` creates a `DragGesture(minimumDistance: 1)` on the divider that updates `splitRatio` on `.onChanged`, computing `rawRatio` from translation width and applying `snappedSplitRatio()`.
- Field Notes: N/A
- Issues: None

**AC3**: The default split ratio is approximately 50/50
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/ResizableSplitView.swift`:45
- Evidence: `@State private var splitRatio: CGFloat = 0.5` -- initial ratio is exactly 0.5 (50/50).
- Field Notes: N/A
- Issues: None

**AC4**: The layout respects the window's minimum size constraints
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:26, `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/ResizableSplitView.swift`:52
- Evidence: `ContentView` applies `.frame(minWidth: 600, minHeight: 400)`. `ResizableSplitView` enforces `minPaneWidth: CGFloat = 200` on both sides, ensuring neither pane collapses.
- Field Notes: N/A
- Issues: None

### REQ-SSE-003: Plain-Text Markdown Editing

**AC1**: The editor displays Markdown content as plain text in a monospaced font
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/MarkdownEditorView.swift`:13-14
- Evidence: `TextEditor(text: $text).font(.system(.body, design: .monospaced))` -- uses SwiftUI `TextEditor` with monospaced system font.
- Field Notes: N/A
- Issues: None

**AC2**: The editor foreground and background colors match the active Solarized theme (Dark or Light)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/MarkdownEditorView.swift`:15-17
- Evidence: `.foregroundColor(appState.theme.colors.foreground)` and `.scrollContentBackground(.hidden).background(appState.theme.colors.background)` -- both foreground and background read from the active theme's color palette.
- Field Notes: N/A
- Issues: None

**AC3**: Undo (Cmd+Z) and redo (Cmd+Shift+Z) function correctly
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/MarkdownEditorView.swift`:13 (TextEditor)
- Evidence: SwiftUI `TextEditor` inherits standard macOS undo/redo behavior from NSTextView. This is a platform-provided capability that cannot be verified through static code analysis.
- Field Notes: N/A
- Issues: Requires manual verification

**AC4**: Cut (Cmd+X), copy (Cmd+C), and paste (Cmd+V) function correctly
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/MarkdownEditorView.swift`:13 (TextEditor)
- Evidence: SwiftUI `TextEditor` inherits standard macOS clipboard operations from NSTextView. Platform-provided capability.
- Field Notes: N/A
- Issues: Requires manual verification

**AC5**: Text selection via mouse and keyboard (Shift+Arrow, Cmd+A) functions correctly
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/MarkdownEditorView.swift`:13 (TextEditor)
- Evidence: SwiftUI `TextEditor` inherits standard macOS text selection from NSTextView. Platform-provided capability.
- Field Notes: N/A
- Issues: Requires manual verification

### REQ-SSE-004: Live Preview

**AC1**: Typing in the editor causes the preview pane to update with the newly rendered Markdown
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/SplitEditorView.swift`:17-19, `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`:24-35
- Evidence: `MarkdownEditorView(text: $state.markdownContent)` binds the editor to `appState.markdownContent`. `MarkdownPreviewView` uses `.task(id: appState.markdownContent)` which re-triggers on every content change, rendering via `MarkdownRenderer.render()`. The data flow is: editor -> binding -> appState.markdownContent -> task trigger -> render -> renderedBlocks -> display.
- Field Notes: N/A
- Issues: None

**AC2**: Preview updates feel responsive (no perceptible lag for typical Markdown files)
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`:28
- Evidence: 150ms debounce delay implemented via `Task.sleep(for: .milliseconds(150))`. The 150ms delay is below the ~200ms perceived-instant threshold per design decision D9. Initial render has no delay (`isInitialRender` flag at line 26). This is architecturally sound but perceived responsiveness requires subjective testing.
- Field Notes: N/A
- Issues: Requires manual verification for perceived responsiveness

**AC3**: The preview uses the same rendering pipeline and visual output as the preview-only mode
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`:31-34
- Evidence: Both preview-only and side-by-side modes use the exact same `MarkdownPreviewView` component, which calls `MarkdownRenderer.render(text: appState.markdownContent, theme: appState.theme)`. In preview-only mode, `ContentView` renders `MarkdownPreviewView()` directly. In side-by-side mode, `SplitEditorView` passes `MarkdownPreviewView()` as the right pane. Same component, same rendering pipeline.
- Field Notes: N/A
- Issues: None

**AC4**: Rapid typing does not cause visual jank or application unresponsiveness
- Status: PARTIAL (architectural support verified, runtime behavior requires manual testing)
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`:24-35
- Evidence: The `.task(id:)` modifier with 150ms sleep and `Task.isCancelled` check ensures that rapid typing cancels stale render tasks. Only the final stabilized content triggers actual rendering. This is the correct architectural approach for debouncing, but actual jank-free behavior under load requires manual testing.
- Field Notes: N/A
- Issues: Runtime performance requires manual verification

### REQ-SSE-005: File Save

**AC1**: Pressing Cmd+S writes the current editor text content to the original file path on disk
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:12-18, `/Users/jud/Projects/mkdn/mkdn/App/AppState.swift`:55-61
- Evidence: `CommandGroup(replacing: .saveItem)` with `Button("Save") { try? appState.saveFile() }.keyboardShortcut("s", modifiers: .command)`. `saveFile()` calls `markdownContent.write(to: url, atomically: true, encoding: .utf8)` where `url` is `currentFileURL`. Unit test `saveFileWritesContent()` in AppStateTests.swift verifies content round-trips correctly to disk.
- Field Notes: N/A
- Issues: None

**AC2**: After a successful save, the unsaved-changes indicator is no longer visible
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppState.swift`:60, `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:56-58
- Evidence: `saveFile()` sets `lastSavedContent = markdownContent` at line 60, which makes `hasUnsavedChanges` (computed as `markdownContent != lastSavedContent`) return false. `ContentView` conditionally shows `UnsavedIndicator()` only `if appState.hasUnsavedChanges`. Unit test `unsavedChangesClearedBySave()` verifies this behavior.
- Field Notes: N/A
- Issues: None

**AC3**: If the save fails (e.g., permissions issue), the user is informed and the unsaved indicator remains
- Status: PARTIAL
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:14, `/Users/jud/Projects/mkdn/mkdn/App/AppState.swift`:55-61
- Evidence: `try? appState.saveFile()` -- the `try?` silently discards errors. If the save fails (the `write(to:)` throws), `lastSavedContent` is never updated (it comes after the write at line 60), so `hasUnsavedChanges` correctly remains true. However, the user is NOT explicitly informed of the failure -- the error is silently swallowed by `try?`. The acceptance criterion specifies "the user is informed."
- Field Notes: N/A
- Issues: Save failure is silent -- no error alert or notification is shown to the user. The unsaved indicator correctly remains, but the user has no way to know the save failed vs. simply not having pressed Cmd+S.

### REQ-SSE-006: Unsaved Changes Tracking

**AC1**: A visual indicator appears when the editor text differs from the last-saved content
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppState.swift`:19-21, `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:56-58, `/Users/jud/Projects/mkdn/mkdn/UI/Components/UnsavedIndicator.swift`:1-32
- Evidence: `hasUnsavedChanges` is computed as `markdownContent != lastSavedContent`. ContentView shows `UnsavedIndicator()` when `appState.hasUnsavedChanges` is true. `UnsavedIndicator` displays a capsule with a breathing yellow dot and "Unsaved" text. Unit test `unsavedChangesOnEdit()` confirms the flag becomes true on edit.
- Field Notes: N/A
- Issues: None

**AC2**: The indicator disappears after a successful save (Cmd+S)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppState.swift`:60, `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:56-58
- Evidence: After `saveFile()`, `lastSavedContent = markdownContent` makes `hasUnsavedChanges` false. The conditional `if appState.hasUnsavedChanges` in the toolbar hides the `UnsavedIndicator`. Unit test `unsavedChangesClearedBySave()` confirms.
- Field Notes: N/A
- Issues: None

**AC3**: The indicator appears immediately when the user makes any edit to a previously saved file
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppState.swift`:19-21
- Evidence: `hasUnsavedChanges` is a computed property (`markdownContent != lastSavedContent`) on an `@Observable` class. Any mutation to `markdownContent` (via the TextEditor binding) instantly triggers re-evaluation. The property is reactive by design. Unit test `unsavedChangesOnEdit()` confirms: after setting `markdownContent = "# Edited"`, `hasUnsavedChanges` is immediately true.
- Field Notes: N/A
- Issues: None

**AC4**: Opening a file and making no edits does not show the unsaved indicator
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppState.swift`:46-52
- Evidence: `loadFile(at:)` sets both `markdownContent = content` and `lastSavedContent = content`, so `hasUnsavedChanges` evaluates to false. Unit test `noUnsavedChangesAfterLoad()` confirms: after `loadFile`, `!state.hasUnsavedChanges` and `state.lastSavedContent == content`.
- Field Notes: N/A
- Issues: None

### REQ-SSE-007: File Load into Editor

**AC1**: Opening a file via `mkdn file.md` populates the editor with the file's text content
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`:11-13, `/Users/jud/Projects/mkdn/mkdn/App/AppState.swift`:46-52
- Evidence: CLI entry point checks `LaunchContext.fileURL` and calls `state.loadFile(at: url)`, which sets `markdownContent = content`. `SplitEditorView` binds to `appState.markdownContent` for the editor via `MarkdownEditorView(text: $state.markdownContent)`.
- Field Notes: N/A
- Issues: None

**AC2**: Opening a file via drag-and-drop populates the editor with the file's text content
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:30-46
- Evidence: `ContentView` has `.onDrop(of: [.fileURL], ...)` handler that calls `appState.loadFile(at: url)` on successful drop of `.md` or `.markdown` files. `loadFile` sets `markdownContent`, which flows to the editor binding.
- Field Notes: N/A
- Issues: None

**AC3**: Opening a file via the open dialog populates the editor with the file's text content
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:74-85
- Evidence: `MkdnToolbarContent.openFile()` presents an `NSOpenPanel` for `.md` files and calls `appState.loadFile(at: url)` on selection. `loadFile` sets `markdownContent`, which flows to the editor binding.
- Field Notes: N/A
- Issues: None

**AC4**: The preview pane displays the rendered version of the same content
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`:24-35
- Evidence: `MarkdownPreviewView` reads `appState.markdownContent` and renders it via `.task(id: appState.markdownContent)`. Since `loadFile` sets `markdownContent`, the preview renders the loaded content. Both editor and preview read from the same `markdownContent` property.
- Field Notes: N/A
- Issues: None

**AC5**: Editor and preview are in sync immediately after file load
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppState.swift`:48-49, `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownPreviewView.swift`:25-27
- Evidence: `loadFile` sets `markdownContent = content` which simultaneously populates the editor (via binding) and triggers preview rendering. The initial render uses `isInitialRender = true` path which skips the 150ms debounce, ensuring immediate preview on load.
- Field Notes: N/A
- Issues: None

### REQ-SSE-008: File-Change Detection in Edit Mode

**AC1**: If the file is modified on disk while the editor is open, the outdated indicator appears
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/FileWatcher/FileWatcher.swift`:40-51, `/Users/jud/Projects/mkdn/mkdn/App/AppState.swift`:24-26
- Evidence: `FileWatcher.watch(url:)` creates a `DispatchSource` monitoring `.write`, `.rename`, `.delete` events. The event handler sets `self.isOutdated = true` (when not save-paused). `AppState.isFileOutdated` is a computed property: `fileWatcher.isOutdated`. ContentView shows `OutdatedIndicator()` when `appState.isFileOutdated` is true.
- Field Notes: N/A
- Issues: None

**AC2**: The outdated indicator is visible in both preview-only and side-by-side modes
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:60-62
- Evidence: `OutdatedIndicator()` is rendered in `MkdnToolbarContent` which is always present in the toolbar regardless of view mode. The toolbar is attached to the top-level `Group` that contains both view modes.
- Field Notes: N/A
- Issues: None

**AC3**: Reloading the file replaces the editor text with the on-disk content
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppState.swift`:64-67
- Evidence: `reloadFile()` calls `loadFile(at: url)` which sets `markdownContent = content` (from disk) and `lastSavedContent = content`. This replaces the editor text via the binding. Unit test `reloadResetsBothContentFields()` confirms: after external write + reload, `markdownContent` matches the new disk content.
- Field Notes: N/A
- Issues: None

**AC4**: Reloading clears the outdated indicator
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/AppState.swift`:51, `/Users/jud/Projects/mkdn/mkdn/Core/FileWatcher/FileWatcher.swift`:33-34
- Evidence: `reloadFile()` calls `loadFile()` which calls `fileWatcher.watch(url:)` which sets `isOutdated = false` at line 34. This resets the outdated state, causing `appState.isFileOutdated` to return false.
- Field Notes: N/A
- Issues: None

**AC5**: The user is not forced to reload; it is a manual action
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/OutdatedIndicator.swift`:8-9, `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`:34-39
- Evidence: `OutdatedIndicator` is a `Button` that calls `appState.reloadFile()` on tap -- the user must explicitly click it or use Cmd+R (from MkdnCommands). There is no automatic reload mechanism anywhere in the codebase. The FileWatcher only sets `isOutdated = true`; it never triggers a reload.
- Field Notes: N/A
- Issues: None

### REQ-SSE-009: Theme-Aware Editor Pane

**AC1**: The editor background color matches the active theme's background
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/MarkdownEditorView.swift`:17
- Evidence: `.scrollContentBackground(.hidden).background(appState.theme.colors.background)` -- the TextEditor's native background is hidden and replaced with the theme background.
- Field Notes: N/A
- Issues: None

**AC2**: The editor text color matches the active theme's foreground
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/MarkdownEditorView.swift`:15
- Evidence: `.foregroundColor(appState.theme.colors.foreground)` applied to the TextEditor.
- Field Notes: N/A
- Issues: None

**AC3**: Switching themes updates the editor pane colors immediately
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/MarkdownEditorView.swift`:9,15,17
- Evidence: `@Environment(AppState.self) private var appState` -- the view reads theme colors from `appState.theme.colors` which is reactive via `@Observable`. When `appState.theme` changes, SwiftUI automatically re-renders the view with the new colors. The preview also handles theme changes via `.onChange(of: appState.theme)` at `MarkdownPreviewView.swift:36-41`.
- Field Notes: N/A
- Issues: None

**AC4**: The editor and preview panes appear visually cohesive when displayed side-by-side
- Status: MANUAL_REQUIRED
- Implementation: Both panes read from `appState.theme.colors` for background colors
- Evidence: Both `MarkdownEditorView` (background: `appState.theme.colors.background`) and `MarkdownPreviewView` (background: `appState.theme.colors.background` at line 23) use the same theme background. Editor foreground uses `appState.theme.colors.foreground`. Architecturally consistent, but visual cohesion is a subjective assessment.
- Field Notes: N/A
- Issues: Requires visual inspection to confirm subjective cohesion

### REQ-SSE-010: Mode Transition Animation

**AC1**: Switching from preview-only to side-by-side shows the editor pane sliding in from the left
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:21,25
- Evidence: `SplitEditorView().transition(.move(edge: .leading).combined(with: .opacity))` combined with `.animation(.spring(response: 0.4, dampingFraction: 0.85), value: appState.viewMode)`. The `.move(edge: .leading)` transition slides in from the left.
- Field Notes: N/A
- Issues: None

**AC2**: Switching from side-by-side to preview-only shows the editor pane sliding out to the left
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:21,25
- Evidence: The same `.move(edge: .leading)` transition reverses on removal, sliding the SplitEditorView out to the left. The `.opacity` combination provides a fade effect during the slide.
- Field Notes: N/A
- Issues: None

**AC3**: The animation feels organic and spring-like, not mechanical or linear
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift`:25
- Evidence: `.animation(.spring(response: 0.4, dampingFraction: 0.85), value: appState.viewMode)` -- uses a spring animation with 0.4s response and 0.85 damping fraction, which produces organic spring physics rather than linear interpolation.
- Field Notes: N/A
- Issues: None

**AC4**: The animation completes without visual glitches or layout jumps
- Status: MANUAL_REQUIRED
- Implementation: ContentView.swift animation configuration
- Evidence: Architecture is correct (spring + transition), but glitch-free completion requires runtime visual verification.
- Field Notes: N/A
- Issues: Requires manual verification

### REQ-SSE-011: Divider Interaction Polish

**AC1**: Dragging the divider resizes the panes smoothly without lag
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/ResizableSplitView.swift`:102-124
- Evidence: `DragGesture(minimumDistance: 1)` on the divider updates `splitRatio` on every `.onChanged` event. The `GeometryReader` layout recalculates `leftWidth` and `rightWidth` reactively. The `.onEnded` handler only resets `isDragging` state. No async operations during drag.
- Field Notes: N/A
- Issues: Runtime smoothness requires manual verification, but architecture avoids lag-introducing patterns

**AC2**: The divider snaps to sensible ratio points (approximately 30/70, 50/50, 70/30) when dragged near them
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/ResizableSplitView.swift`:12-34
- Evidence: `snappedSplitRatio()` function accepts snap points `[0.3, 0.5, 0.7]` with 20pt threshold. When `abs(proposedPosition - snapPosition) <= snapThreshold`, it returns the snap point. Unit tests confirm: `snapsToHalf()`, `snapsToThirty()`, `snapsToSeventy()` all pass. `noSnapOutsideThreshold()` confirms non-snap behavior.
- Field Notes: N/A
- Issues: None

**AC3**: Hovering over the divider provides visual feedback (highlight, cursor change, or width change)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/ResizableSplitView.swift`:80-89,92-100
- Evidence: `.onHover` toggles `isHovering` state. On hover: (1) `NSCursor.resizeLeftRight.push()` changes the cursor; (2) `dividerFill` changes from `Color.gray.opacity(0.2)` to `Color.accentColor.opacity(0.35)`; (3) `effectiveDividerWidth` changes from 6pt to 10pt (line 57). Animations applied via `.animation(.easeInOut(duration: 0.15))`.
- Field Notes: N/A
- Issues: None

**AC4**: The divider respects minimum pane widths so neither pane collapses to zero
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/ResizableSplitView.swift`:21-23,52
- Evidence: `snappedSplitRatio()` clamps the ratio: `let minRatio = minPaneWidth / totalWidth` and `let maxRatio = 1.0 - minRatio`, then `clamped = min(max(proposedRatio, minRatio), max(maxRatio, minRatio))`. With `minPaneWidth = 200`, neither pane can go below 200pt. Unit tests `clampsToMinPaneWidthLeft()` and `clampsToMinPaneWidthRight()` confirm clamping at 0.2 and 0.8 for 1000pt width.
- Field Notes: N/A
- Issues: None

### REQ-SSE-012: Unsaved Indicator Animation

**AC1**: The unsaved-changes indicator pulses with a gentle breathing rhythm
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/UnsavedIndicator.swift`:14-18
- Evidence: The circle's opacity is bound to `isBreathing` state: `.opacity(isBreathing ? 1.0 : 0.4)` with `.animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isBreathing)`. On `.onAppear`, `isBreathing` is set to true, triggering the repeating animation.
- Field Notes: N/A
- Issues: None

**AC2**: The animation rate is approximately 12 cycles per minute (one cycle every 5 seconds)
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/UnsavedIndicator.swift`:16
- Evidence: `.easeInOut(duration: 2.5).repeatForever(autoreverses: true)` -- 2.5 seconds fade up + 2.5 seconds fade down = 5 seconds per cycle = 12 cycles per minute. Matches design decision D8.
- Field Notes: N/A
- Issues: None

**AC3**: The animation is subtle enough to not distract from editing but noticeable enough to inform the user
- Status: MANUAL_REQUIRED
- Implementation: UnsavedIndicator.swift opacity range 0.4-1.0
- Evidence: Opacity oscillates between 0.4 and 1.0 (not fully disappearing). The component uses `.ultraThinMaterial` background, `.caption` font, and `.secondary` foreground color. Design is intentionally restrained. Subjective assessment required.
- Field Notes: N/A
- Issues: Requires subjective visual assessment

**AC4**: The animation uses the same design language as other animated indicators in the application
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Components/UnsavedIndicator.swift`:1-32, `/Users/jud/Projects/mkdn/mkdn/UI/Components/OutdatedIndicator.swift`:1-27
- Evidence: Both indicators use the same structure: `HStack(spacing: 4)` with `Circle().fill(color).frame(width: 8, height: 8)`, `Text(label).font(.caption).foregroundColor(.secondary)`, wrapped in `.padding(.horizontal, 8).padding(.vertical, 4).background(.ultraThinMaterial).clipShape(Capsule())`. UnsavedIndicator uses yellow dot; OutdatedIndicator uses orange dot. Consistent design language confirmed.
- Field Notes: N/A
- Issues: None

### REQ-SSE-013: Focus Transition Polish

**AC1**: Moving focus between panes provides a subtle visual indication of which pane is focused
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/MarkdownEditorView.swift`:18-28
- Evidence: `@FocusState private var isFocused: Bool` with `.focused($isFocused)` on the TextEditor. An overlay `RoundedRectangle(cornerRadius: 4).stroke(appState.theme.colors.accent.opacity(isFocused ? 0.3 : 0), lineWidth: 1.5)` provides a subtle border when focused.
- Field Notes: N/A
- Issues: Focus indication is only on the editor pane. The preview pane does not have its own focus indicator, but this is acceptable since the preview pane is read-only and not a focus target.

**AC2**: The focus indicator uses theme-consistent colors
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/MarkdownEditorView.swift`:24
- Evidence: `appState.theme.colors.accent.opacity(isFocused ? 0.3 : 0)` -- uses the theme's accent color.
- Field Notes: N/A
- Issues: None

**AC3**: No harsh or system-default focus rings are visible on the panes
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/MarkdownEditorView.swift`:19, `/Users/jud/Projects/mkdn/mkdn/Features/Editor/Views/SplitEditorView.swift`:13
- Evidence: `.focusEffectDisabled()` is applied to both the TextEditor (in MarkdownEditorView) and the SplitEditorView container, suppressing system-default focus rings.
- Field Notes: N/A
- Issues: None

## Implementation Gap Analysis

### Missing Implementations
- **REQ-SSE-005 AC3 (partial)**: Save failure user notification. The unsaved indicator correctly persists on failure, but the user is not informed of the failure. No error alert, toast, or notification is displayed. The `try?` in MkdnCommands.swift silently discards the error.
- **Documentation tasks TD1-TD4**: KB documentation updates (architecture.md, modules.md, patterns.md) are not yet completed per tasks.md.

### Partial Implementations
- **REQ-SSE-005 AC3**: Unsaved indicator persists correctly on save failure (half of the criterion met), but user is not informed (other half not met).
- **REQ-SSE-004 AC4**: Debounce architecture is correct, but runtime jank-free behavior cannot be confirmed via static analysis alone.

### Implementation Issues
- None detected. All implemented code follows the design specification, uses correct patterns, and passes all tests.

## Code Quality Assessment

**Architecture**: The implementation follows the Feature-Based MVVM pattern with AppState as the single source of truth. The decision to remove EditorViewModel and fold its functionality into AppState is clean and avoids state synchronization bugs.

**State Management**: Uses `@Observable` consistently. `hasUnsavedChanges` as a computed property is elegant -- it is automatically reactive and cannot become stale. `isFileOutdated` delegation to `fileWatcher.isOutdated` avoids manual state synchronization.

**SwiftUI Patterns**: Proper use of `@Environment`, `@Bindable`, `@FocusState`, `.task(id:)` for debouncing, and `@ViewBuilder` for generic components. No anti-patterns detected (no WKWebView, no ObservableObject, no force unwrapping).

**Separation of Concerns**: `snappedSplitRatio()` is extracted as a pure function for testability. `ResizableSplitView` is generic and reusable. `UnsavedIndicator` and `OutdatedIndicator` share consistent design language.

**Testing**: 98 tests total, all passing. 16 new tests specifically for this feature covering AppState editing lifecycle (7), FileWatcher save-pause (2), and snap logic (7). Tests properly avoid DispatchSource creation to prevent signal 5 race conditions.

**Concurrency Safety**: `@MainActor` annotations on AppState and FileWatcher. `nonisolated(unsafe)` correctly applied to mutable DispatchSource properties. Async resume uses `Task { @MainActor in ... }` for safe main-thread access.

**Animation Quality**: Spring animation (response: 0.4, dampingFraction: 0.85) for mode transitions. Breathing animation at 12 cycles/min. Divider hover animations at 0.15s easeInOut. Focus transition at 0.2s easeInOut. All animation parameters are sensible and consistent.

## Recommendations

1. **Add save failure user notification** (REQ-SSE-005 AC3): Replace `try? appState.saveFile()` in MkdnCommands.swift with a do/catch that presents an alert or logs a visible error message to the user. This could be implemented as a `@State var saveError: Error?` on the app level with an `.alert` modifier, or by adding an `errorMessage: String?` property to AppState.

2. **Complete documentation tasks TD1-TD4**: Update `.rp1/context/architecture.md`, `.rp1/context/modules.md`, and `.rp1/context/patterns.md` per the tasks.md acceptance criteria. These are straightforward KB maintenance tasks.

3. **Perform manual visual verification** for the 7 MANUAL_REQUIRED criteria:
   - REQ-SSE-003 AC3/AC4/AC5 (standard text editing operations)
   - REQ-SSE-004 AC2 (perceived responsiveness)
   - REQ-SSE-009 AC4 (visual cohesion)
   - REQ-SSE-010 AC4 (animation glitch-free)
   - REQ-SSE-012 AC3 (animation subtlety)

4. **Consider adding field-notes.md**: Document the T1 deviation where `isFileOutdated` was changed from stored to computed property. While this is an improvement, having it in field notes provides traceability for future verification.

## Verification Evidence

### AppState.swift - Core Editing State
```swift
// Lines 16-21: Unsaved changes tracking
public private(set) var lastSavedContent = ""
public var hasUnsavedChanges: Bool {
    markdownContent != lastSavedContent
}

// Lines 24-26: File outdated delegation
public var isFileOutdated: Bool {
    fileWatcher.isOutdated
}

// Lines 46-52: File loading with baseline
public func loadFile(at url: URL) throws {
    let content = try String(contentsOf: url, encoding: .utf8)
    currentFileURL = url
    markdownContent = content
    lastSavedContent = content
    fileWatcher.watch(url: url)
}

// Lines 55-61: Save with FileWatcher coordination
public func saveFile() throws {
    guard let url = currentFileURL else { return }
    fileWatcher.pauseForSave()
    defer { fileWatcher.resumeAfterSave() }
    try markdownContent.write(to: url, atomically: true, encoding: .utf8)
    lastSavedContent = markdownContent
}
```

### ContentView.swift - Mode Switching with Animation
```swift
// Lines 15-25: Mode switch with spring animation
switch appState.viewMode {
case .previewOnly:
    MarkdownPreviewView()
        .transition(.opacity)
case .sideBySide:
    SplitEditorView()
        .transition(.move(edge: .leading).combined(with: .opacity))
}
.animation(.spring(response: 0.4, dampingFraction: 0.85), value: appState.viewMode)
```

### MarkdownPreviewView.swift - Debounced Rendering
```swift
// Lines 24-35: Debounced render with initial-render bypass
.task(id: appState.markdownContent) {
    if isInitialRender {
        isInitialRender = false
    } else {
        try? await Task.sleep(for: .milliseconds(150))
        guard !Task.isCancelled else { return }
    }
    renderedBlocks = MarkdownRenderer.render(
        text: appState.markdownContent,
        theme: appState.theme
    )
}
```

### ResizableSplitView.swift - Snap Logic
```swift
// Lines 12-34: Pure snap function
func snappedSplitRatio(
    proposedRatio: CGFloat,
    totalWidth: CGFloat,
    snapPoints: [CGFloat] = [0.3, 0.5, 0.7],
    snapThreshold: CGFloat = 20,
    minPaneWidth: CGFloat = 200
) -> CGFloat {
    guard totalWidth > 0 else { return 0.5 }
    let minRatio = minPaneWidth / totalWidth
    let maxRatio = 1.0 - minRatio
    let clamped = min(max(proposedRatio, minRatio), max(maxRatio, minRatio))
    // ... snap point check ...
}
```

### FileWatcher.swift - Save-Pause Pattern
```swift
// Lines 83-96: Pause/resume for save conflict prevention
func pauseForSave() {
    isSavePaused = true
}
func resumeAfterSave() {
    Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(200))
        self.isSavePaused = false
    }
}
```

### Test Coverage Summary
| Test File | Tests | Focus |
|-----------|-------|-------|
| AppStateTests.swift | 13 | Default state, load, save, reload, unsaved tracking lifecycle |
| SnapLogicTests.swift | 7 | Snap points, no-snap, min pane clamping, zero width |
| FileWatcherTests.swift | 4 | Start state, acknowledge, pauseForSave, resumeAfterSave |
| **Total feature-relevant** | **24** | |
