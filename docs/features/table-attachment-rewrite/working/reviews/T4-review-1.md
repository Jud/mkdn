# Code Review: T4 -- TableAttachmentViewProvider + pipeline switchover

**Date:** 2026-03-24
**Round:** 1
**Verdict:** redo

## Summary

The pipeline switchover correctly routes tables through attachment-based rendering (non-print) and retains inline text for print. However, the implementation diverges from the spec's `NSTextAttachmentViewProvider` approach in favor of an `OverlayCoordinator`-based approach, leaving `TableAttachmentViewProvider.swift` as 104 lines of dead code. More critically, `PassthroughHostingView` (which returns `nil` from `hitTest`) is used to host the `TableAttachmentView`, making all selection gestures and `onCopyCommand` inoperable at runtime.

## What This Code Does

**Pipeline switchover**: `MarkdownTextStorageBuilder.appendBlock()` now routes `.table` blocks through two paths:
- **Non-print (default)**: `appendTableAttachment()` creates a `TableTextAttachment` with `TableAttachmentData`, computes initial bounds via `TableColumnSizer`, and inserts it as an `NSTextAttachment` placeholder in the attributed string. The `OverlayCoordinator` sees `.table` in its `needsOverlay()` switch, creates a `TableAttachmentView` inside a `PassthroughHostingView`, and positions it over the placeholder using the standard attachment overlay mechanism.
- **Print**: `appendTableInlineText()` retains the old invisible-text approach with `TableAttributes`/`TableCellMap`.

**Selection/find/copy**: `TableAttachmentView` now holds a `@State TableSelectionState`, provides `onTapGesture` handlers with modifier-key detection (Cmd/Shift/plain click), renders selection highlights (accent color at 0.3 opacity) and find highlights (yellow at 0.15/0.4 opacity), and handles `onCopyCommand` via `TableClipboardSerializer`.

**Environment threading**: `AppSettings` is threaded from `MarkdownPreviewView` through `MarkdownTextStorageBuilder.build()` to `appendTableAttachment()`, stored as a weak reference on `TableTextAttachment`, and injected via `.environment()` when the `OverlayCoordinator` creates the hosting view.

**Cleanup**: `tableOverlays` removed from `SelectableTextView`, `MarkdownPreviewView`, `TextStorageResult` init, and `appendTableInlineText`. `selectionDragHandler` wiring removed from `SelectableTextView.makeNSView()`. `tableDelays` passed as `[:]` in entrance animation paths.

## Transitions Identified

- **Builder routing (isPrint)**: Atomic -- `if isPrint` branches cleanly. Safe.
- **Theme/scale changes**: `TableAttachmentView` reads `AppSettings` from environment; SwiftUI observation handles re-evaluation. `OverlayCoordinator` repositions overlays on layout changes. Safe.
- **Selection state transitions**: `TableSelectionState` mutations are `@MainActor`-isolated and atomic assignments. Safe in isolation -- but unreachable at runtime (see findings).
- **Content reload**: `applyNewContent` hides overlays, sets new text storage, creates new `OverlayEntry` instances. The `updateOrCreateOverlay` path carries over known heights from old attachments to prevent height-reporting races. Safe.
- **Entrance animation**: Tables now flow through `attachmentDelays` (not `tableDelays`) since they are attachment-based overlays. The `applyEntranceAnimation` lookup correctly dispatches on `entry.attachment != nil`. Safe.

## Convention Check
**Files examined for context:** `OverlayCoordinator+Factories.swift` (neighboring factory methods), `MermaidBlockView.swift` (overlay creation pattern), `ImageBlockView.swift` (overlay creation pattern), `CodeBlockBackgroundTextView.swift` (existing selectionDragHandler), `EntranceAnimator.swift` (tableDelays pattern)
**Violations:** 1

## Findings

### [TableAttachmentViewProvider.swift:1-104] Dead code: entire file is unused
**Severity:** major
**Category:** spec-compliance
```swift
final class TableAttachmentViewProvider: NSTextAttachmentViewProvider {
```
**Problem:** `TableAttachmentViewProvider` is never registered (no `registerViewProviderClass` call, no `viewProvider(for:)` override) and is never referenced anywhere in the codebase. The implementation uses `OverlayCoordinator`-based positioning instead. The spec explicitly required creating and registering the `NSTextAttachmentViewProvider` subclass -- this file is 104 lines of dead code that will confuse future readers.
**Impact:** Dead code ships. Future tasks (T5/T6) reference the view provider in their specs, creating confusion about the actual architecture.
**Fix:** Either (a) delete `TableAttachmentViewProvider.swift` and update the architecture to clearly document the overlay approach, or (b) actually wire up the view provider as specified (register it, remove the overlay factory path for tables). Given the overlay approach works and matches the existing Mermaid/image pattern, option (a) is preferable -- but the spec for T5/T6 needs updating.

### [OverlayCoordinator+Factories.swift:96] PassthroughHostingView blocks all user interaction
**Severity:** critical
**Category:** correctness
```swift
return PassthroughHostingView(rootView: rootView)
```
**Problem:** `PassthroughHostingView.hitTest` returns `nil` unconditionally (line 22 of `OverlayCoordinator+TableOverlays.swift`). This means mouse events never reach the hosted `TableAttachmentView`. The `onTapGesture` handlers for cell selection (click, Cmd+click, Shift+click) and the `onCopyCommand` handler added in T4 will never fire at runtime. All selection/find/copy UI added to `TableAttachmentView` is dead code.
**Impact:** Table cell selection, Cmd+click toggle, Shift+click extend, and Cmd+C copy do not work. The user cannot interact with tables at all. This violates the T4 spec requirement "Add gesture recognizers on cells" and "Add copy support."
**Fix:** Use `NSHostingView` instead of `PassthroughHostingView` for the table overlay. The old `TableBlockView` used `PassthroughHostingView` because selection was handled by the underlying `NSTextView` via `selectionDragHandler`. The new `TableAttachmentView` handles selection itself via SwiftUI gestures, so it needs to receive mouse events. Change line 96 to `return NSHostingView(rootView: rootView)`.

### [TableAttachmentData.swift:47-48] allowsTextAttachmentView = true removed from designated init
**Severity:** minor
**Category:** correctness
```swift
override public init(data contentData: Data?, ofType uti: String?) {
    super.init(data: contentData, ofType: uti)
}
```
**Problem:** T4 removed `allowsTextAttachmentView = true` from the designated init (it was present in T1). On macOS 14+, `NSTextAttachment.init(data:ofType:)` defaults `allowsTextAttachmentView` to `true`, so this works today. However, the explicit set is defensive and documents intent. The T1 review verified this property was set; removing it silently changes the contract.
**Impact:** None on macOS 14+ (the only target). Would break on hypothetical earlier versions.
**Fix:** Restore `allowsTextAttachmentView = true` in the designated init for clarity and defensive coding. This also makes the test assertion at `TableAttachmentDataTests.swift:43` test actual code rather than a platform default.

### [TableAttachmentView.swift:60-71] onCopyCommand returns empty providers while writing to pasteboard
**Severity:** minor
**Category:** correctness
```swift
.onCopyCommand {
    let text = TableClipboardSerializer.tabDelimitedText(...)
    guard !text.isEmpty else { return [] }
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    return []
}
```
**Problem:** `onCopyCommand` expects the closure to return `[NSItemProvider]` representing the copy payload. Returning `[]` tells the system there's nothing to copy. The pasteboard write is a side effect that races with the system's copy handling. This pattern works in practice because SwiftUI doesn't clear the pasteboard after receiving `[]`, but it's fragile and undocumented.
**Impact:** Copy works today as a side effect but may break in future SwiftUI versions that interpret `[]` as "cancel copy."
**Fix:** Return `[NSItemProvider(item: text as NSString, typeIdentifier: UTType.utf8PlainText.identifier)]` instead of writing to the pasteboard directly. Or keep the pasteboard write but document why `[]` is returned.

## Acceptance Criteria

| Criterion | Met? | Evidence |
|-----------|------|----------|
| `swift build` succeeds | Yes | Build complete! (1.21s) |
| `swift test` passes | Yes | 708 tests in 65 suites passed (1.114s) |
| Tables render visually via attachment | Partial | Tables are inserted as attachments and overlaid by OverlayCoordinator, but not via NSTextAttachmentViewProvider as specified |
| `swiftformat .` passes | Yes | 0/9 T4 files require formatting |
| `swiftlint lint` passes | Yes | 0 violations, 0 serious in 9 T4 files |
| Selection gestures on cells | No | Gestures exist in code but cannot fire due to PassthroughHostingView (hitTest returns nil) |
| Find highlighting in cells | Partial | Code exists but cannot be triggered interactively |
| Copy support via TableClipboardSerializer | No | onCopyCommand exists but cannot fire due to PassthroughHostingView |
| MarkdownTextStorageBuilderTableTests rewritten | Yes | 11 tests covering attachment creation, data fidelity, print fallback |
| TableAttachmentViewProvider created | Dead code | File exists but is never registered or referenced |

## Verification Trail

### What I Verified
- **Build integrity**: `swift build` in worktree -- Build complete! (1.21s)
- **Test integrity**: `swift test` in worktree -- 708 tests in 65 suites passed (1.114s). Test count consistent: 713 (T2 baseline) - 5 tests removed from `MarkdownTextStorageBuilderTableTests` + 0 new non-T4 tests = expected ~708.
- **Lint compliance**: `swiftlint lint` on 9 T4 files -- 0 violations, 0 serious
- **Format compliance**: `swiftformat --lint` on 9 T4 files -- 0/9 files require formatting
- **Commit scope**: `git diff 4257791..902ef48 --stat` confirmed 11 files changed (410 insertions, 296 deletions)
- **Convention alignment**: Read `OverlayCoordinator+Factories.swift` (neighboring factory), `OverlayCoordinator+TableOverlays.swift` (PassthroughHostingView definition), `EntranceAnimator.swift` (tableDelays), `OverlayCoordinator+Positioning.swift` (attachment vs text-range dispatch)
- **Dead code**: `grep -r TableAttachmentViewProvider` returns only the definition file -- no references
- **allowsTextAttachmentView default**: Verified `NSTextAttachment(data:nil, ofType:nil).allowsTextAttachmentView == true` on macOS 14+ via swift REPL
- **PassthroughHostingView behavior**: Read definition at `OverlayCoordinator+TableOverlays.swift:10-25` -- `hitTest` returns `nil` unconditionally, blocking all mouse events to hosted SwiftUI views
- **Entrance animation**: Verified new table overlay entries have `attachment != nil` and `tableRangeID == nil`, so `applyEntranceAnimation` correctly uses `attachmentDelays` path

### What I Dismissed
- **`TableOverlayInfo` struct still defined**: It's still referenced by `OverlayCoordinator+TableOverlays.swift` (old path retained for T5 deletion). Not a problem for T4.
- **`tableDelays` still in `EntranceAnimator`**: Used by old text-range table path; T5 will remove. `SelectableTextView` passes `[:]` for the two non-`onLayoutInvalidation` paths; the `onLayoutInvalidation` path passes the actual dictionary (line 57) which is always empty for new tables since they use `attachmentDelays`. Not a bug.
- **`blockIndex` and `block` parameters marked `_` in `appendTableInlineText`**: Spec-compliant -- these were only needed for `tableOverlays` accumulation which is removed.
- **`selectionDragHandler` still in `CodeBlockBackgroundTextView`**: T5 spec handles its removal.
- **Test count dropped from 713 to 708**: T2 baseline was 713. The old `MarkdownTextStorageBuilderTableTests` had more tests (covering inline text, table overlays, cell maps); the rewritten suite has 11 tests focused on attachment behavior. Net loss of ~5 tests is expected.

### What I Could Not Verify
- **Visual rendering**: Cannot verify tables render correctly without running the app with the test harness. The overlay-based approach should work (same pattern as Mermaid/image), but the interaction (selection/copy) is broken.
- **Print rendering**: The print path retains `appendTableInlineText` but no longer creates `TableOverlayInfo`. The old table overlay rendering for print relied on `updateTableOverlays` which is no longer called. Whether print tables render correctly depends on whether the inline text path alone produces visible output (it does for `isPrint: true` since foreground color is not `.clear`).

### Build Integrity
- `swift build` -> Build complete! (1.21s)
- `swift test` -> 708 tests in 65 suites passed after 1.114 seconds
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swiftlint lint` (T4 files) -> 0 violations, 0 serious in 9 files
- `swiftformat --lint` (T4 files) -> 0/9 files require formatting

## What Was Done Well

- The overlay-based approach (table as attachment placeholder + OverlayCoordinator) is architecturally sound and consistent with the existing Mermaid/image/math pattern. It avoids the complexity of environment injection through `NSTextAttachmentViewProvider`.
- The `OverlayCoordinator` additions are minimal and clean: `needsOverlay` gains `.table`, `createAttachmentOverlay` gains a `.table` case, and `OverlayCoordinator+Factories` gains `makeTableAttachmentOverlay` matching the existing factory pattern.
- The print/non-print split is clean: a simple `if isPrint` in the `.table` case routes to the appropriate path.
- The `onGeometryChange` callback on the table overlay correctly reports the SwiftUI view's actual rendered height back to the `OverlayCoordinator` for placeholder sizing.
- The `OverlayCoordinatorTests` additions (deep table comparison, position index tests) are thorough.
- The `MarkdownTextStorageBuilderTableTests` rewrite covers all spec-required scenarios plus edge cases (empty rows, multiple tables, bounds, print mode).

## Redo Instructions

1. **Fix PassthroughHostingView** (critical): In `OverlayCoordinator+Factories.swift:96`, change `PassthroughHostingView(rootView: rootView)` to `NSHostingView(rootView: rootView)`. This allows mouse events to reach `TableAttachmentView`'s gesture handlers. Verify cell selection works by building, launching the test harness, loading `fixtures/table-test.md`, and clicking table cells.

2. **Delete or wire up `TableAttachmentViewProvider.swift`** (major): Either delete the file entirely (preferred, since the overlay approach is correct) or actually register it. If deleting, also remove it from the source tree and verify `swift build` still succeeds.

3. **Restore `allowsTextAttachmentView = true`** (minor): In `TableAttachmentData.swift`, restore `allowsTextAttachmentView = true` in the designated `init(data:ofType:)` for defensive coding and clarity.

4. **Fix `onCopyCommand` return** (minor, can defer): Either return a proper `[NSItemProvider]` or add a comment explaining the side-effect pattern. This is low priority since it works today.
