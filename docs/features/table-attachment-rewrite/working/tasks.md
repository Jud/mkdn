# Build Tasks: Table Attachment Rewrite

**Status:** Complete
**Worktree:** .claude/worktrees/build-table-attachment-rewrite
**Branch:** build/table-attachment-rewrite
**Total Tasks:** 7
**Completed:** 7

## Task Graph

Batch 1 (parallel): T1, T3
Batch 2 (sequential): T2 (depends on T1 — uses CellPosition and SelectionShape)
Batch 3 (sequential): T4 (depends on T1, T2, T3)
Batch 4 (sequential): T5 (depends on T4)
Batch 5 (sequential): T6 (depends on T5)
Batch 6 (sequential): T7 (depends on T6)

## Tasks

### T1. Foundation data types: TableTextAttachment, TableAttachmentData, TableClipboardSerializer
**Status:** done
**Depends on:** —
**Files:** `mkdn/Core/Markdown/TableAttachmentData.swift` (new), `mkdn/Core/Markdown/TableClipboardSerializer.swift` (new), `mkdnTests/Unit/Core/TableAttachmentDataTests.swift` (new), `mkdnTests/Unit/Core/TableClipboardSerializerTests.swift` (new)
**Review:** reviews/T1-review-1.md
**Spec:**

(completed — see build log)

---

### T2. TableSelectionState and TableFindAdapter
**Status:** done
**Depends on:** T1
**Files:** `mkdn/Features/Viewer/Views/TableSelectionState.swift` (new), `mkdn/Features/Viewer/Views/TableFindAdapter.swift` (new), `mkdnTests/Unit/Features/TableSelectionStateTests.swift` (new), `mkdnTests/Unit/Features/TableFindAdapterTests.swift` (new)
**Review:** reviews/T2-review-1.md
**Spec:**

(completed — see build log)

---

### T3. TableAttachmentView (SwiftUI visual rendering only)
**Status:** done
**Depends on:** —
**Files:** `mkdn/Features/Viewer/Views/TableAttachmentView.swift` (new)
**Review:** reviews/T3-review-1.md
**Spec:**

(completed — see build log)

---

### T4. Pipeline switchover (overlay-based, not NSTextAttachmentViewProvider)
**Status:** done
**Depends on:** T1, T2, T3
**Files:** Multiple (see T4-build-log.md)
**Review:** reviews/T4-review-2.md
**Spec:**

(completed — see build log. Key outcome: `NSTextAttachmentViewProvider` is fundamentally broken under Swift 6 strict concurrency. Tables use the same overlay approach as Mermaid/image/math blocks: `NSTextAttachment` placeholder + `OverlayCoordinator` positions `NSHostingView(rootView: TableAttachmentView(...))` over the placeholder.)

---

### T5. Cleanup: delete obsolete table infrastructure
**Status:** done
**Depends on:** T4
**Files:** Delete 11 source files + 2 test files. Modify 8 source files + 1 test file. Rewrite print table path.
**Review:** reviews/T5-review-1.md
**Spec:**

Delete all obsolete text-range-based table rendering infrastructure and strip table-specific code from shared files. The print path must be rewritten to avoid depending on deleted types.

**IMPORTANT CONTEXT:** T4 discovered that `NSTextAttachmentViewProvider` does not work under Swift 6 strict concurrency. Tables now use the `OverlayCoordinator` attachment overlay pattern (same as Mermaid/image/math). The old text-range-based table pipeline (invisible text + `PassthroughHostingView` + `TableHighlightOverlay` + `TableCellMap`) is completely dead code. The print path still calls `appendTableInlineText` which depends on `TableCellMap`, `TableAttributes`, and `TableColorInfo` — this must be replaced with a simplified print-only method before deleting those types.

#### Step 1: Rewrite the print table path

The current print path in `MarkdownTextStorageBuilder.swift` line 246-255 calls `appendTableInlineText()` when `isPrint == true`. This depends on `TableCellMap`, `TableAttributes`, `TableColorInfo`, and `buildTableTabStops` — all of which are being deleted. Replace with a simplified print-only method.

**In `MarkdownTextStorageBuilder+TableInline.swift`**: Before deleting this file, first create the replacement method. Add a new static method to `MarkdownTextStorageBuilder` in a **new** extension file `MarkdownTextStorageBuilder+TablePrint.swift` (in `mkdn/Core/Markdown/`):

```swift
static func appendTablePrintText(
    to result: NSMutableAttributedString,
    columns: [TableColumn],
    rows: [[AttributedString]],
    colors: ThemeColors,
    scaleFactor: CGFloat
)
```

This method produces visible plain text for print rendering. It does NOT need `TableCellMap`, `TableAttributes`, `TableColorInfo`, or `buildTableTabStops`. Implementation:
- Use `TableColumnSizer.computeWidths()` at `defaultEstimationContainerWidth` to get column widths.
- For each row (header first, then data), produce a single paragraph with tab-separated cell text using the same tab-stop approach (but build tab stops inline — just a simple loop over cumulative widths, no need for the deleted `buildTableTabStops` helper since it's trivially re-creatable).
- Header text: bold font, `colors.headingColor` foreground.
- Data text: body font, `colors.foreground` foreground.
- Set paragraph style with `minimumLineHeight`/`maximumLineHeight` from `estimateInlineRowHeight` (port this helper method to the new file — it only uses `NSAttributedString.boundingRect`, no deleted types).
- Do NOT apply `TableAttributes.range` or create `TableCellMap` — print doesn't need selection/find/overlay.
- Append a newline with `blockSpacing` paragraph spacing after the last row.

**In `MarkdownTextStorageBuilder.swift`**: Change the `.table` print path (line 246-255) from:
```swift
appendTableInlineText(to:blockIndex:block:columns:rows:colors:isPrint:)
```
to:
```swift
appendTablePrintText(to:columns:rows:colors:scaleFactor: sf)
```

#### Step 2: Delete obsolete files

**Source files to DELETE** (11 files):
1. `mkdn/Core/Markdown/MarkdownTextStorageBuilder+TableInline.swift` — replaced by `+TablePrint.swift`
2. `mkdn/Core/Markdown/TableCellMap.swift` — no longer used (selection handled by `TableSelectionState`)
3. `mkdn/Core/Markdown/TableAttributes.swift` — no longer used (no text-range-based tables)
4. `mkdn/Features/Viewer/Views/TableBlockView.swift` — replaced by `TableAttachmentView`
5. `mkdn/Features/Viewer/Views/TableHeaderView.swift` — was used by old `TableBlockView` and sticky headers
6. `mkdn/Features/Viewer/Views/TableHighlightOverlay.swift` — replaced by SwiftUI highlights in `TableAttachmentView`
7. `mkdn/Features/Viewer/Views/OverlayCoordinator+TableOverlays.swift` — text-range table overlay API + `PassthroughHostingView`
8. `mkdn/Features/Viewer/Views/OverlayCoordinator+TableHeights.swift` — row height correction for invisible text
9. `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView+TableSelection.swift` — text-level table selection suppression
10. `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView+TableCopy.swift` — text-level table copy (TSV/RTF)
11. `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView+TablePrint.swift` — text-level table print

**Test files to DELETE** (2 files):
1. `mkdnTests/Unit/Core/TableCellMapTests.swift`
2. `mkdnTests/Unit/Core/TableAttributesTests.swift`

#### Step 3: Strip table references from surviving files

1. **`OverlayCoordinator.swift`** — remove these from `OverlayEntry`:
   - Fields: `tableRangeID: String?`, `highlightOverlay: TableHighlightOverlay?`, `cellMap: TableCellMap?`, `lastAppliedVisualHeight: CGFloat?`
   - Corresponding init parameters.
   - Remove properties from the class: `stickyHeaders: [Int: NSView]`, `tableRangeIndex: [String: NSRange]`, `pendingVisualHeights: [Int: CGFloat]`.
   - In `hideAllOverlays()`: remove `entry.highlightOverlay?.isHidden = true` and the `stickyHeaders` loop.
   - In `repositionOverlays()`: remove `stickyHeaders.values.forEach { $0.removeFromSuperview() }; stickyHeaders.removeAll()` from the `widthChanged` block. Remove `invalidateReconciliation()` call and `for key in entries.keys { entries[key]?.lastAppliedVisualHeight = nil }` from the `widthChanged` block.
   - Remove `shouldPositionEntry()` method entirely (it checks `entry.tableRangeID`).
   - In `repositionOverlays()`: change the for loop from `where shouldPositionEntry(entry, context:)` to just iterate all entries directly.
   - In `removeAllOverlays()`: remove `entry.highlightOverlay?.removeFromSuperview()` from the loop, and remove `stickyHeaders.values.forEach { ... }; stickyHeaders.removeAll()`.
   - In `removeStaleAttachmentOverlays()`: remove the `guard entry.tableRangeID == nil else { continue }` check, and remove `stickyHeaders[index]?.removeFromSuperview(); stickyHeaders.removeValue(forKey: index)`.
   - In `createAttachmentOverlay()`: remove `entries[info.blockIndex]?.highlightOverlay?.removeFromSuperview()`.
   - Remove `reconciledThroughOffset`, `reconcileLayoutThroughViewport()`, and `invalidateReconciliation()`. These were for the text-range table path. The `reconcileLayoutThroughViewport` call in `repositionOverlays()` should be removed. (NOTE: There is one call to `invalidateReconciliation()` from `invalidateAttachmentHeight` — this can be removed since it was only needed for text-range positioning.)
   - Remove `pendingVisualHeights` dictionary.

2. **`OverlayCoordinator+Positioning.swift`**:
   - In `positionEntry()`: Remove the `if entry.tableRangeID != nil` branch — tables are now attachment-based. Simplify to only call `positionAttachmentEntry()` when `entry.attachment != nil`, else hide.

3. **`OverlayCoordinator+PositionIndex.swift`**:
   - Remove `tableRangeIndex.removeAll()`.
   - Remove the entire `enumerateAttribute(TableAttributes.range, ...)` block. Keep only the `enumerateAttribute(.attachment, ...)` block.

4. **`OverlayCoordinator+Observation.swift`**:
   - In `handleScrollBoundsChange()`: Remove ALL sticky header logic — the entire `for (blockIndex, entry) in entries` loop that checks `entry.block` for `.table` and manages `stickyHeaders`. Reduce `handleScrollBoundsChange()` to just call `repositionOverlays()`.
   - Remove `stickyHeaderHeight()` method entirely.

5. **`OverlayCoordinator+EntranceAnimation.swift`**:
   - Remove the `tableDelays` parameter from `applyEntranceAnimation()`.
   - Remove the `else if let tableRangeID = entry.tableRangeID` branch — tables now use the attachment path.
   - Update the method signature to only take `attachmentDelays` and `fadeInDuration`.
   - Remove `entry.highlightOverlay?.alphaValue = 0` and `entry.highlightOverlay?.animator().alphaValue = 1`.

6. **`CodeBlockBackgroundTextView.swift`**:
   - Remove `cachedTableRanges: [String: NSRange]` and `isTableRangeCacheValid: Bool` properties.
   - Remove `selectionDragHandler: ((NSRange) -> Void)?` property.
   - In `copy(_:)`: Remove `if !handleTableCopy()` — just call `super.copy(sender)` directly.
   - In `setSelectedRanges()`: Remove the `selectionDragHandler?(range.rangeValue)` call. Keep the super call.
   - In `draw(_:)`: Remove `eraseTableSelectionHighlights(in: dirtyRect)`.
   - In `drawBackground(in:)`: Remove `drawTableContainers(in: rect)`.
   - In `invalidateCodeBlockCache()`: Remove `isTableRangeCacheValid = false`.

7. **`EntranceAnimator.swift`**:
   - Remove `tableDelays: [String: CFTimeInterval]` property.
   - Remove all `tableDelays.removeAll()` calls from `beginEntrance()`, `reset()`, and `animateVisibleFragments()`.
   - In `processBlockGroups()`: Remove the `if groupID.hasPrefix("table-")` branch entirely. Tables are now attachments and go through the `recordAttachmentDelay` path automatically.
   - In `blockGroupID()`: Remove the `TableAttributes.range` check (the `if let tableID = ...` block). Keep only the `CodeBlockAttributes.range` check.

8. **`SelectableTextView.swift`** and **`SelectableTextView+Coordinator.swift`**:
   - In `SelectableTextView.swift`: All three `tableDelays:` argument passes at lines 57, 245, 279 — remove them. Update `applyEntranceAnimation()` calls to only pass `attachmentDelays` and `fadeInDuration`.
   - In `SelectableTextView+Coordinator.swift`: Remove both `overlayCoordinator.updateTableFindHighlights(...)` calls (lines 372-375 and 467-470). Table find highlights are now handled internally by `TableAttachmentView`.

9. **`MarkdownTextStorageBuilder.swift`**:
   - Remove the `TableOverlayInfo` struct definition (lines 15-24). It is no longer used.
   - Remove the `import` or reference to `TableCellMap` if any remain after deletion.

10. **`mkdnTests/Unit/Features/OverlayCoordinatorTests.swift`**:
   - Remove `buildPositionIndexTableRange()` test (lines 196-206) — tests `tableRangeIndex` which no longer exists.
   - Remove `buildPositionIndexMergesTableRanges()` test (lines 208-229) — tests `tableRangeIndex` which no longer exists.

#### Step 4: Verify cleanup completeness

After all deletions and modifications, run:
```bash
swift build
swift test
```

Then verify no stale references remain:
```bash
grep -r 'TableCellMap\|TableAttributes\|TableOverlayInfo\|TableHighlightOverlay\|TableHeaderView\|TableBlockView\|PassthroughHostingView\|tableOverlays\|tableRangeID\|tableRangeIndex\|cachedTableRanges\|selectionDragHandler\|pendingVisualHeights\|stickyHeaders\|tableDelays\|handleTableCopy\|eraseTableSelectionHighlights\|drawTableContainers\|appendTableInlineText\|TableRowContext\|TableColorInfo\|buildTableTabStops' --include='*.swift' mkdn/ mkdnTests/
```

The ONLY match should be `TableBlockViewiOS.swift` (the iOS table view — NOT being deleted, different platform). `MarkdownContentView.swift` may reference `TableBlockViewiOS` inside `#if os(iOS)` — that is correct and expected.

**Acceptance criteria:**
- `swift build` succeeds with zero warnings related to table deletions.
- `swift test` passes — test count will drop by the deleted test files plus the 2 removed OverlayCoordinator tests.
- The grep above returns zero matches in non-iOS files (only `TableBlockViewiOS` references in `Platform/iOS/` are acceptable).
- `swiftformat .` and `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swiftlint lint` pass.

**Before committing:** Run `swiftformat .` then `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swiftlint lint`.

---

### T6. Find-in-page integration for table overlays
**Status:** done
**Depends on:** T5
**Files:** `mkdn/Features/Viewer/Views/TableAttachmentView.swift` (modify), `mkdn/Features/Viewer/Views/OverlayCoordinator+Factories.swift` (modify), `mkdn/Features/Viewer/ViewModels/FindState.swift` (read-only reference)
**Review:** —
**Spec:**

Wire up find-in-page so that `TableAttachmentView` receives `FindState` and populates its `selectionState.findMatches`. The view-level find highlight rendering (yellow backgrounds at 0.15/0.4 opacity) already exists from T4 — this task is about driving it with actual data.

**IMPORTANT CONTEXT:** T4 added find highlight rendering to `TableAttachmentView.cellHighlight()` — it checks `selectionState.isFindMatch(row:column:)` and `selectionState.isCurrentFindMatch(row:column:)`. But `selectionState.findMatches` is never populated because `FindState` is not injected into the `NSHostingView` environment and no code calls `TableFindAdapter`.

**Problem:** The table overlay is created by `OverlayCoordinator+Factories.makeTableAttachmentOverlay()` which returns `NSHostingView(rootView: TableAttachmentView(...).environment(appSettings))`. The `NSHostingView` is a standalone view — it does NOT inherit SwiftUI environment from the `NSTextView`'s SwiftUI hierarchy. So `@Environment(FindState.self)` would crash or return nil.

**Solution:** Thread `FindState` through `OverlayCoordinator` to the hosting view environment, and add an `onChange` observer in `TableAttachmentView` that calls `TableFindAdapter` when the query changes.

#### Changes to `OverlayCoordinator+Factories.swift`:

In `makeTableAttachmentOverlay()`, add `FindState` to the environment injection:

1. Add a `findState: FindState?` parameter to `makeTableAttachmentOverlay()`.
2. In the root view chain, add `.environment(findState)` after `.environment(appSettings)` (only if findState is non-nil — use `if let` or optional chaining).
3. Update the call site in `OverlayCoordinator.createAttachmentOverlay()` to pass the find state. The coordinator already has access to the text view via `self.textView` — but it doesn't directly hold `FindState`. Two options:
   - **Option A (preferred):** Add a `weak var findState: FindState?` property to `OverlayCoordinator`. Set it from `SelectableTextView.updateNSView()` alongside the existing `appSettings` pass. Then pass `self.findState` to `makeTableAttachmentOverlay()`.
   - **Option B:** Access FindState from the coordinator chain in `SelectableTextView+Coordinator.swift` and pass it through `updateOverlays()`.

Use Option A for simplicity.

#### Changes to `OverlayCoordinator.swift`:

Add `weak var findState: FindState?` property alongside the existing `appSettings`.

#### Changes to `SelectableTextView.swift` or `SelectableTextView+Coordinator.swift`:

In the method that calls `updateOverlays()`, set `coordinator.overlayCoordinator.findState = findState` before the call. The `findState` property is already available on `SelectableTextView` (line 28: `let findState: FindState`).

Find where `overlayCoordinator.updateOverlays()` is called. Before that call, add:
```swift
coordinator.overlayCoordinator.findState = findState
```

#### Changes to `TableAttachmentView.swift`:

1. Add an optional `FindState` environment property:
   ```swift
   @Environment(FindState.self) private var findState: FindState?
   ```
   (Use optional binding since `FindState` may not always be in the environment.)

2. Add an `onChange` modifier in the body that watches find state changes:
   ```swift
   .onChange(of: findState?.query) { _, newQuery in
       updateFindHighlights(query: newQuery ?? "")
   }
   .onChange(of: findState?.currentMatchIndex) { _, _ in
       updateFindCurrentMatch()
   }
   .onChange(of: findState?.isVisible) { _, isVisible in
       if isVisible != true {
           selectionState.findMatches = []
           selectionState.currentFindMatch = nil
       }
   }
   ```

3. Add helper methods:
   ```swift
   private func updateFindHighlights(query: String) {
       guard let findState, findState.isVisible else {
           selectionState.findMatches = []
           selectionState.currentFindMatch = nil
           return
       }
       let matches = TableFindAdapter.findMatches(
           query: query,
           columns: columns,
           rows: rows
       )
       selectionState.findMatches = Set(matches)
       updateFindCurrentMatch()
   }

   private func updateFindCurrentMatch() {
       guard let findState, findState.isVisible else {
           selectionState.currentFindMatch = nil
           return
       }
       // The current match index is global (across the whole document).
       // Table cells don't participate in the global match index — they
       // just highlight all matches. Set currentFindMatch to nil (no
       // "current" concept for table cells, just passive highlighting).
       selectionState.currentFindMatch = nil
   }
   ```

   Note: The global find state tracks match indices across the whole attributed string. Table cells are overlays that don't appear in the attributed string text, so they can't participate in the global current-match navigation. All table cell matches should show passive find highlighting (yellow at 0.15 opacity). The `currentFindMatch` feature in `TableSelectionState` exists for potential future use but will be nil for now.

#### Testing approach

No new unit tests needed — `TableFindAdapter` is already tested (T2). The integration is verified visually:
1. Build: `swift build`
2. Launch: `swift run mkdn --test-harness &`
3. Load: `scripts/mkdn-ctl load fixtures/table-test.md`
4. Open find bar (Cmd+F), search for a term that appears in table cells.
5. Capture screenshots and verify yellow highlighting appears in matching cells.

**Acceptance criteria:**
- When find bar is open and a query matches table cell content, those cells show yellow background highlighting.
- When find bar is dismissed, table cell find highlights are cleared.
- `swift build` and `swift test` pass. Lint and format clean.

**Before committing:** Run `swiftformat .` then `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swiftlint lint`.

---

### T7. Visual verification and polish
**Status:** done
**Depends on:** T6
**Files:** Various (polish fixes as needed)
**Review:** —
**Spec:**

Perform comprehensive visual verification and fix any rendering issues.

**Verification checklist:**

1. Build the project: `swift build`
2. Launch test harness: `swift run mkdn --test-harness &`
3. Load table fixture: `scripts/mkdn-ctl load fixtures/table-test.md`
4. **Both themes, multiple scroll positions:**
   - `scripts/mkdn-ctl theme solarizedLight`
   - `scripts/mkdn-ctl capture /tmp/table-light-top.png`
   - `scripts/mkdn-ctl scroll 500`
   - `scripts/mkdn-ctl capture /tmp/table-light-scroll.png`
   - `scripts/mkdn-ctl theme solarizedDark`
   - `scripts/mkdn-ctl capture /tmp/table-dark-top.png`
   - `scripts/mkdn-ctl scroll 0`
   - `scripts/mkdn-ctl capture /tmp/table-dark-scroll0.png`
5. Read each captured PNG and visually inspect:
   - Table borders render correctly (rounded corners, 1px stroke).
   - Header row has correct background and bold text.
   - Zebra striping on data rows.
   - Column alignment (left, center, right) is correct.
   - Text wrapping within cells looks correct.
   - No visual glitches or misalignment.
   - Theme colors match between light and dark.
   - Tables resize correctly with window (capture at different widths if possible).

6. Run `./scripts/install-dev` to install and relaunch mkdn2.

7. Run full test suite: `swift test` — verify all tests pass.

**Fix any issues found** during visual verification:
- Spacing or padding mismatches vs the old rendering.
- Color differences.
- Layout glitches at edge cases (very narrow window, very wide table, empty table, single-column table).
- Entrance animation timing (tables should fade in with the stagger animation like other attachments).

**Acceptance criteria:**
- Visual rendering matches or improves upon the old table rendering in both themes.
- All tests pass. Lint and format clean.
- `./scripts/install-dev` completes successfully.
- No visual regressions reported.

**Before committing:** Run `swiftformat .` then `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swiftlint lint`.
