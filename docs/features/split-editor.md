# Split Editor

## Overview

The Split Editor turns mkdn from a read-only viewer into a view-and-edit tool. It provides a side-by-side layout with a plain-text Markdown editor on the left and a live-rendered preview on the right, connected by a resizable divider with snap points. The default mode on file open remains preview-only; users toggle into editing mode on demand.

## User Experience

- **Mode switching**: A toolbar `ViewModePicker` toggles between `previewOnly` (full-width render) and `sideBySide` (editor + preview). Keyboard shortcut available. The editor pane slides in from the leading edge with a spring animation; returning to preview-only slides it back out.
- **Live preview**: Typing in the editor updates the preview in real time. Rendering is debounced (~150ms via `.task(id:)`) so rapid keystrokes do not cause jank.
- **Resizable divider**: A custom draggable divider separates the panes. It snaps to 30/70, 50/50, and 70/30 ratios within a 20pt threshold. The divider widens and tints on hover, and the cursor changes to `resizeLeftRight`. Minimum pane width is 200pt.
- **Save**: Cmd+S writes the editor text to disk atomically. A "Save As" option is also available.
- **Unsaved indicator**: When editor text diverges from the last-saved baseline, the Orb indicator reflects unsaved state. Saving or reloading clears it.
- **File-change detection**: If an external process modifies the file on disk while editing, the outdated indicator appears. Reload is always manual to prevent data loss.
- **Theme consistency**: The editor pane reads foreground, background, and accent colors from the active Solarized theme. Switching themes updates both panes immediately.
- **Focus polish**: A subtle theme-accent border appears on the editor pane when focused, animated with a quick shift. System focus rings are suppressed.

## Architecture

State flows through `DocumentState` (per-window, `@Observable`). The editor binds directly to `documentState.markdownContent`, which is also the source for preview rendering. Unsaved detection is a computed property comparing `markdownContent` to `lastSavedContent`.

```
ContentView
  |-- [.previewOnly] MarkdownPreviewView
  |-- [.sideBySide]  SplitEditorView
                        |-- ResizableSplitView<Left, Right>
                        |     |-- MarkdownEditorView (left)
                        |     |-- MarkdownPreviewView (right)
                        |-- Divider (DragGesture + snap logic)
```

Data flow for an edit-save cycle:

1. User types -> `MarkdownEditorView` binding updates `documentState.markdownContent`
2. `hasUnsavedChanges` becomes `true` (computed: `markdownContent != lastSavedContent`)
3. `.task(id: markdownContent)` in preview debounces and re-renders
4. Cmd+S -> `documentState.saveFile()` pauses FileWatcher, writes atomically, updates `lastSavedContent`, resumes FileWatcher

## Implementation Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| State ownership | `DocumentState.markdownContent` as single source | Avoids duplication; preview already reads from it |
| Unsaved detection | Computed property (`markdownContent != lastSavedContent`) | Automatically reactive via `@Observable`; no manual flag management |
| Split view | Custom `ResizableSplitView` (GeometryReader + DragGesture) | `HSplitView` lacks snap points, hover feedback, and minimum-width enforcement |
| Debounce mechanism | `.task(id:)` with 150ms sleep | SwiftUI-native cancellation handles rapid typing; no Combine needed |
| FileWatcher save conflict | Pause/resume pattern with short delay | Prevents false outdated signals from the app's own writes |
| Mode animation | Spring (`.gentleSpring`) + `.move(edge: .leading)` transition | Physical, organic feel; matches project animation conventions |
| Editor component | SwiftUI `TextEditor` with monospaced font | Provides undo/redo, selection, paste, and standard macOS text editing for free |

## Files

### Source (`mkdn/`)

| File | Role |
|------|------|
| `App/DocumentState.swift` | Per-window state: `markdownContent`, `lastSavedContent`, `hasUnsavedChanges`, `viewMode`, `loadFile()`, `saveFile()`, `saveAs()`, `reloadFile()` |
| `App/ViewMode.swift` | `enum ViewMode { case previewOnly, sideBySide }` |
| `App/ContentView.swift` | Root view; switches between `MarkdownPreviewView` and `SplitEditorView` with animated transitions |
| `App/MkdnCommands.swift` | Cmd+S save command, disabled when no unsaved changes |
| `Features/Editor/Views/SplitEditorView.swift` | Composes `ResizableSplitView` with `MarkdownEditorView` (left) and `MarkdownPreviewView` (right) |
| `Features/Editor/Views/MarkdownEditorView.swift` | `TextEditor` wrapper: monospaced font, theme colors, focus border, `@FocusState` tracking |
| `Features/Editor/Views/ResizableSplitView.swift` | Generic split container: `snappedSplitRatio()` function, drag gesture, hover feedback, min-width clamping |
| `Core/FileWatcher/FileWatcher.swift` | DispatchSource watcher with `pauseForSave()` / `resumeAfterSave()` for save-conflict avoidance |

### Tests (`mkdnTests/`)

| File | Covers |
|------|--------|
| `Unit/Features/SnapLogicTests.swift` | `snappedSplitRatio()`: snap-to-half, snap-to-30/70, no-snap outside threshold, min-width clamping, zero-width guard |

## Dependencies

| Dependency | Type | Purpose |
|------------|------|---------|
| `DocumentState` | Internal | Single source of truth for file content, save state, view mode |
| `AppSettings` / Theme system | Internal | Solarized Dark/Light colors for editor pane |
| `FileWatcher` | Internal | On-disk change detection; pause/resume around saves |
| `MarkdownPreviewView` | Internal | Existing render pipeline reused as the right pane |
| `AnimationConstants` | Internal | Shared spring/crossfade timing values |
| SwiftUI `TextEditor` | Framework | Native text editing with undo, redo, selection, clipboard |

No external SPM packages are required beyond what the project already uses.

## Testing

**Unit tests** (Swift Testing, `@testable import mkdnLib`):

- `SnapLogicTests` -- seven tests covering snap-to-ratio, no-snap, min-width clamping, and zero-width edge case. All pass against the pure `snappedSplitRatio()` function.
- `DocumentState` save/load/unsaved-changes logic is testable through its public API: `loadFile`, `saveFile`, `hasUnsavedChanges`, `lastSavedContent`.

**Visual verification** (test harness):

- Load a fixture in `sideBySide` mode, capture screenshots at multiple scroll positions in both Solarized themes.
- Drag divider to each snap point, verify layout at 30/70, 50/50, 70/30.
- Type in editor, confirm live preview updates.
- Cmd+S, confirm unsaved indicator clears.
- Modify file externally, confirm outdated indicator appears.
