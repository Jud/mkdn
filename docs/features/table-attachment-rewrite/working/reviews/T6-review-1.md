# Code Review: T6 -- Find-in-page integration for table overlays

**Date:** 2026-03-24
**Round:** 1
**Verdict:** pass

## Summary

Clean, minimal wiring of `FindState` through the overlay coordinator into `TableAttachmentView`. The implementation correctly leverages `@Observable` reference semantics so the environment-injected `FindState` stays live across overlay recycling. No correctness issues found.

## What This Code Does

Threads `FindState` from `SelectableTextView` through `OverlayCoordinator` into each table overlay's `NSHostingView` environment. When the user types in the find bar:

1. `FindState.query` mutates (it's `@Observable`).
2. `TableAttachmentView`'s `onChange(of: findState?.query)` fires.
3. `updateFindHighlights` calls `TableFindAdapter.findMatches()` to get matching cell positions.
4. Those positions are stored in `selectionState.findMatches` (a `Set<CellPosition>`).
5. `cellHighlight()` checks `selectionState.isFindMatch(row:column:)` and renders yellow backgrounds at 0.15 opacity for matches.

When find is dismissed, the `onChange(of: findState?.isVisible)` handler clears `selectionState.findMatches` and `selectionState.currentFindMatch`.

`currentFindMatch` is always nil -- table cells are document-external overlays that can't participate in the global match index navigation. All table matches get passive (non-current) highlighting.

State changes:
- `OverlayCoordinator` gains `weak var findState: FindState?` property.
- `makeTableAttachmentOverlay()` gains `findState: FindState?` parameter.
- `TableAttachmentView` gains `@Environment(FindState.self)` and three `onChange` observers.
- `refreshOverlays()` sets `coordinator.overlayCoordinator.findState = findState` before calling `updateOverlays()`.

## Transitions Identified

1. **FindState injection at overlay creation** (OverlayCoordinator+Factories.swift:100-103): `findState` is conditionally injected via `.environment(findState)`. If nil, no environment set. Since `refreshOverlays()` always sets `findState` before `updateOverlays()`, and `FindState` is `@State` per-window (stable instance), this will be non-nil for all normal paths. Safe.

2. **Overlay recycling with stale environment** (OverlayCoordinator.swift:252-277): When `blocksMatch` returns true, the existing `NSHostingView` is reused without re-injecting the environment. This is safe because `FindState` is a reference type (`@Observable class`). The original `.environment(findState)` injected the same object instance that persists for the window's lifetime. Property changes are tracked via observation, not re-injection.

3. **Find bar open/close** (TableAttachmentView.swift:68-73): When `isVisible` transitions to false, `findMatches` and `currentFindMatch` are cleared. The `isVisible != true` guard correctly handles the nil case (findState absent). Safe.

4. **Query change to empty string** (TableAttachmentView.swift:194-198): The `updateFindHighlights(query: "")` path is handled by `TableFindAdapter.findMatches()` which returns `[]` for empty queries. But wait -- the guard at line 195 checks `findState.isVisible` first. If the find bar is visible but the query is cleared, the guard passes and `TableFindAdapter.findMatches(query: "", ...)` returns `[]`, setting `findMatches` to empty. Correct.

## Convention Check
**Files examined for context:** `OverlayCoordinator+Factories.swift` (factory pattern for other overlays), `SelectableTextView.swift` (NSViewRepresentable pattern), `SelectableTextView+Coordinator.swift` (find integration for text-based highlights), `TableSelectionState.swift` (state class pattern), `FindState.swift` (observable state pattern)
**Violations:** 0

The implementation follows established patterns:
- `weak var findState` on `OverlayCoordinator` matches the existing `var appSettings: AppSettings?` pattern.
- `@Environment(FindState.self) private var findState: FindState?` is the correct Swift macro-based environment pattern for optional observable types.
- `onChange(of:)` usage matches existing SwiftUI patterns in the codebase.
- The `MARK: - Find Integration` section follows the MARK convention used elsewhere in the file.

## Findings

No critical or major findings.

## Acceptance Criteria

| Criterion | Met? | Evidence |
|-----------|------|----------|
| Table cells show yellow background highlighting when find query matches cell content | Yes | `cellHighlight()` at TableAttachmentView.swift:182-190 renders `Color.yellow.opacity(0.15)` for find matches; `onChange(of: findState?.query)` at line 62 triggers `updateFindHighlights()` which calls `TableFindAdapter.findMatches()` and populates `selectionState.findMatches` |
| Find highlights cleared when find bar is dismissed | Yes | `onChange(of: findState?.isVisible)` at line 68-73 clears `findMatches` and `currentFindMatch` when `isVisible != true` |
| `swift build` passes | Yes | Build complete! (0.15s), zero errors, zero warnings |
| `swift test` passes | Yes | 669 tests in 63 suites passed after 0.900 seconds |
| Lint clean | Yes | 4 violations, all pre-existing (MermaidTemplateLoader period_spacing x2, SelectableTextView+Coordinator file_length + orphaned_doc_comment) |
| Format clean | Yes | 0/213 files require formatting |

## Verification Trail

### What I Verified
- **Build integrity**: `swift build` in worktree -- Build complete! (0.15s), zero errors, zero warnings
- **Test integrity**: `swift test` in worktree -- 669 tests in 63 suites passed (unchanged from T5)
- **Format compliance**: `swiftformat --lint .` -- 0/213 files require formatting
- **Lint compliance**: `swiftlint lint` -- 4 violations, all pre-existing (verified same as T5 review)
- **FindState threading**: Traced `findState` from `DocumentWindow` (`@State`) through `SelectableTextView` (`let findState: FindState`) through `refreshOverlays()` (line 284 sets `coordinator.overlayCoordinator.findState`) through `updateOverlays()` -> `createAttachmentOverlay()` -> `makeTableAttachmentOverlay(findState:)` -> `.environment(findState)` into `TableAttachmentView`'s `@Environment(FindState.self)`. The reference is stable (same instance for window lifetime) and `@Observable`, so property mutations trigger SwiftUI observation.
- **Overlay recycling safety**: When `blocksMatch` returns true and overlay is reused, the injected `FindState` environment reference remains valid because it's a class reference to a stable per-window instance. No re-injection needed.
- **Diff completeness**: 4 files changed, 51 insertions, 2 deletions. All changes map to the spec.
- **Convention alignment**: `weak var findState` pattern, `@Environment` optional binding, `onChange` observers, `MARK:` sections all match codebase conventions.

### What I Dismissed
- **`currentFindMatch` always nil**: The spec explicitly states table cells can't participate in global match navigation. The `updateFindCurrentMatch()` method sets `currentFindMatch = nil` with a clear comment explaining why. The `isCurrentFindMatch` check in `cellHighlight()` (line 183) is dead code *for now* but exists for future extensibility. Not a bug.
- **No new unit tests**: The spec explicitly says "No new unit tests needed" since `TableFindAdapter` is already fully tested (10 tests in `TableFindAdapterTests.swift`). The integration is UI-level wiring that is verified visually in T7.
- **Pre-existing lint violations**: Same 4 as T5 review. Not introduced by T6.

### What I Could Not Verify
- **Visual correctness of find highlights**: Requires launching the app, opening find bar, and visually confirming yellow cell backgrounds. This is the explicit scope of T7 (visual verification).
- **`@Environment` nil safety at runtime**: The `@Environment(FindState.self) private var findState: FindState?` pattern should resolve to nil when `FindState` is absent from the environment. Cannot verify without runtime execution, but this is the documented SwiftUI behavior for optional environment values with `@Observable` types.

### Build Integrity
- `swift build` -> Build complete! (0.15s)
- `swift test` -> 669 tests in 63 suites passed after 0.900 seconds
- `swiftformat --lint .` -> 0/213 files require formatting
- `DEVELOPER_DIR=.../Xcode.app swiftlint lint` -> 4 violations, 4 serious (all pre-existing)

## What Was Done Well

- Minimal, focused change. Only 51 lines added across 4 files, with no unnecessary abstractions or over-engineering.
- Correct use of `weak var` for the `findState` reference on `OverlayCoordinator`, preventing retain cycles since the coordinator outlives individual overlay creation cycles.
- The conditional environment injection (`if let findState { return NSHostingView(rootView: rootView.environment(findState)) }`) avoids injecting a nil environment, which is cleaner than unconditionally injecting an optional.
- Setting `findState` in `refreshOverlays()` (the single entry point for overlay updates) ensures the coordinator always has the current reference before any overlay creation.
