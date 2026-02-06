# Design Decisions: Split-Screen Editor

**Feature ID**: split-screen-editor
**Created**: 2026-02-06

## Decision Log

| ID | Decision | Choice | Rationale | Alternatives Considered |
|----|----------|--------|-----------|------------------------|
| D1 | State ownership for editor text | AppState.markdownContent as single source of truth | Simplest approach; MarkdownPreviewView already reads from appState.markdownContent; avoids state synchronization bugs between AppState and a separate view model | Separate EditorViewModel with its own text property (rejected: duplicates AppState, requires manual sync) |
| D2 | Unsaved changes detection mechanism | Computed property `hasUnsavedChanges` comparing `markdownContent` to `lastSavedContent` | Automatically reactive via @Observable; always accurate; no manual flag management needed | Manual `hasUnsavedChanges` boolean flag toggled on edit/save (rejected: error-prone, every code path must remember to toggle); Diffing (rejected: overkill for a boolean dirty check) |
| D3 | EditorViewModel disposition | Remove entirely; fold needed functionality into AppState | EditorViewModel duplicates AppState's text, fileURL, load(), save() methods; removing it eliminates confusion about which is the source of truth | Keep EditorViewModel as intermediary layer (rejected: adds indirection with no architectural benefit since AppState already serves this role) |
| D4 | Split view implementation | Custom ResizableSplitView using GeometryReader + DragGesture | Enables snap points (30/70, 50/50, 70/30), hover feedback on divider, minimum pane widths, and cursor changes -- none of which HSplitView provides | SwiftUI HSplitView (rejected: insufficient customization for REQ-SSE-011 snap points and hover feedback); NavigationSplitView (rejected: designed for sidebar navigation, not equal-weight split editing) |
| D5 | Live preview debounce strategy | SwiftUI `.task(id: markdownContent)` with 150ms sleep | Built-in task cancellation handles rapid typing naturally; no external timer or publisher management; aligns with SwiftUI-first patterns in the codebase | Combine debounce publisher (rejected: @Observable pattern does not use Combine; would be a pattern inconsistency); Foundation Timer (rejected: more complex lifecycle management, manual cancellation) |
| D6 | FileWatcher save-conflict prevention | Pause/resume pattern: pause before write, resume with ~200ms delay after write | Prevents DispatchSource from firing a false `.write` event when the app itself saves; delay accounts for async event delivery; simple and targeted | Disable FileWatcher entirely during edit mode (rejected: loses detection of external changes, violates REQ-SSE-008); Compare file content hash on every event (rejected: adds disk I/O on every DispatchSource event, defeats purpose of kernel-level monitoring) |
| D7 | Mode transition animation type | Spring animation with `.move(edge: .leading)` transition | Physical, organic feel per charter design philosophy; editor slides in from left (consistent with left-pane position); spring avoids mechanical feeling | Linear animation (rejected: feels mechanical); Instant swap (rejected: explicitly violates REQ-SSE-010); Fade only (rejected: less spatial coherence than slide) |
| D8 | Breathing animation timing | `Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: true)` = 5s full cycle | 5-second cycle = 12 cycles per minute, matching REQ-SSE-012 specification; easeInOut provides natural acceleration/deceleration; opacity range 0.4-1.0 is subtle but noticeable | Faster pulse at 1s cycle (rejected: too distracting, ~60 cycles/min); Static indicator (rejected: explicitly violates REQ-SSE-012) |
| D9 | Debounce duration | 150ms | Below the ~200ms perceived-instant threshold; long enough to batch rapid keystrokes; short enough that pausing feels responsive | 50ms (rejected: too short, nearly every keystroke triggers render); 300ms (rejected: approaches perceptible delay); 500ms (rejected: noticeably laggy) |
| D10 | FileWatcher ownership | AppState owns FileWatcher instance | AppState already manages file lifecycle (load, save, reload); FileWatcher is tightly coupled to file state; ownership enables pause/resume coordination during save | FileWatcher as separate @Environment object (rejected: requires coordination protocol between AppState and FileWatcher, more complex); Global singleton (rejected: conflicts with @Observable pattern) |
| D11 | Minimum pane width | 200pt | Provides enough space for meaningful content in both editor and preview; prevents accidental collapse; reasonable on smallest supported window (600pt min width) | 100pt (rejected: too narrow for comfortable editing); 300pt (rejected: too restrictive on smaller windows) |
| D12 | Snap threshold | 20pt proximity to snap point | Generous enough to be discoverable; narrow enough to allow precise positioning between snap points | 10pt (rejected: too hard to hit); 40pt (rejected: hard to position between snap points) |

## AFK Mode: Auto-Selected Technology Decisions

| Decision | Choice | Source | Rationale |
|----------|--------|--------|-----------|
| Split view approach | Custom GeometryReader + DragGesture | Codebase analysis (HSplitView in scaffolding insufficient) | HSplitView lacks snap points, hover feedback, and cursor customization required by REQ-SSE-011 |
| Debounce mechanism | SwiftUI .task(id:) with sleep | KB patterns.md (SwiftUI-first approach) | Follows existing @Observable + SwiftUI patterns; avoids introducing Combine |
| State architecture | Extend AppState, remove EditorViewModel | KB architecture.md (AppState as central hub) | AppState is the established single source of truth; EditorViewModel was scaffolding that duplicated this |
| Animation parameters | Spring(response: 0.4, dampingFraction: 0.85) | Conservative default | Standard SwiftUI spring configuration; provides organic feel without excessive bounce |
| Unsaved indicator design | Capsule with breathing dot | Codebase (OutdatedIndicator.swift pattern) | Consistent design language with existing OutdatedIndicator component |
| Save-conflict strategy | FileWatcher pause/resume with 200ms delay | Codebase analysis (DispatchSource behavior) | Simplest reliable approach to prevent false positives without losing monitoring |
| Divider visual style | 4pt bar expanding to 8pt on hover, accent color | Conservative default matching platform conventions | Standard macOS divider feel with subtle enhancement for discoverability |
