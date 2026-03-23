# Code Review: T8 — Cache filteredHeadings in OutlineState

**Date:** 2026-03-22
**Round:** 1
**Verdict:** pass

## Summary

T8 is a clean, spec-compliant refactor. The conversion from computed to cached stored property is implemented exactly as specified, with correct call sites and proper test coverage.

## What This Code Does (Reviewer's Model)

`filteredHeadings` was previously a computed property that re-executed fuzzy scoring on every access. This change converts it to a stored `public private(set) var` and adds an `applyFilter()` method that recomputes the cached value and clamps `selectedIndex` to a valid range. The method is called at three mutation points: `updateHeadings(from:)` (after rebuilding `flatHeadings`), `showHUD()` (after resetting `filterQuery`), and `dismissHUD()` (after resetting `filterQuery`). The observable behavior is identical to the previous implementation -- the only change is when computation happens (on explicit call vs. on every access).

## Transitions Identified

| Transition | Handled Safely? |
|-----------|----------------|
| `updateHeadings` -> `applyFilter()` | Yes. Called after `flatHeadings` is set, before any conditional logic that reads `headingTree.isEmpty`. |
| `showHUD` -> `applyFilter()` -> auto-select | Yes. Filter is applied first (resetting to all headings since `filterQuery = ""`), then `selectedIndex` is set to the current heading's position in the filtered list. Order is correct. |
| `dismissHUD` -> `applyFilter()` | Yes. Filter is applied after clearing `filterQuery`, resetting cache to all headings. |
| `selectAndNavigate` -> `dismissHUD` -> `applyFilter()` | Yes. The return value is computed from `filteredHeadings` before `dismissHUD()` is called, so the cache reset doesn't affect the returned blockIndex. |
| `moveSelectionUp/Down` reads `filteredHeadings.count` | Safe. `filteredHeadings` is a stable stored value, not recomputed on access. No risk of inconsistency between the `.count` read and the modulo arithmetic. |
| View sets `filterQuery` directly (T11 responsibility) | Correctly deferred to T11. The spec notes that T11's `.onChange(of: filterQuery)` handler will call `applyFilter()`. |

## Convention Check
**Neighboring files examined:** `FindState.swift`, `OutlineState.swift` (full file), `OutlineStateTests.swift` (full file), `FindStateTests.swift` (directory listing)
**Convention violations found:** 0

The implementation follows established conventions:
- `public private(set) var` for externally-readable, internally-managed state (matches `FindState.matchRanges`)
- MARK sections organized consistently
- Doc comments on the new method follow the existing style
- Test naming convention matches existing tests (`applyFilterRecomputes`, `applyFilterClampsSelectedIndex`)

## Findings

No critical or major findings.

### Finding 1: Minor redundancy in applyFilter call within showHUD
**Severity:** minor
**Category:** correctness
**File:** `mkdn/Features/Outline/ViewModels/OutlineState.swift`
**Lines:** 128-143
**Code:**
```swift
public func showHUD() {
    isHUDVisible = true
    filterQuery = ""
    applyFilter()

    // Auto-select the current heading in the filtered list.
    if let current = currentHeadingIndex {
        if let matchIndex = filteredHeadings.firstIndex(where: { $0.blockIndex == current }) {
            selectedIndex = matchIndex
        } else {
            selectedIndex = 0
        }
    } else {
        selectedIndex = 0
    }
}
```
**Issue:** `applyFilter()` clamps `selectedIndex` at its end, but then `showHUD()` immediately overwrites `selectedIndex` with the auto-select logic. The clamping inside `applyFilter()` is therefore redundant in this specific call path. This is not a bug -- the auto-select logic always produces a valid index (either a found index or 0), so the clamping has no effect. It's a minor observation about unnecessary work, not a correctness issue.
**Impact:** None. The redundant clamp is O(1) and has no observable effect.
**Fix:** No fix needed. The redundancy is acceptable for code clarity -- `applyFilter()` always maintaining the invariant is simpler than special-casing.

## Acceptance Criteria Verification

| Criterion | Met? | Evidence |
|-----------|------|----------|
| `filteredHeadings` is a stored `public private(set) var`, not a computed property | yes | `OutlineState.swift:52` |
| `applyFilter()` recomputes `filteredHeadings` AND clamps `selectedIndex` | yes | `OutlineState.swift:189-218` |
| `applyFilter()` is called from `updateHeadings` | yes | `OutlineState.swift:71` |
| `applyFilter()` is called from `showHUD` | yes | `OutlineState.swift:131` |
| `applyFilter()` is called from `dismissHUD` | yes | `OutlineState.swift:149` |
| All existing OutlineState tests pass | yes | Build log: 16/16 tests passed |
| `swift build` and `swift test` pass | yes | Build log confirms |
| SwiftLint and SwiftFormat pass | yes | Build log: 0 violations, 0 files reformatted |

## What Was Done Well

- **Exact spec adherence.** The `applyFilter()` implementation matches the spec's pseudocode character-for-character, including the scoring logic, sort order, and clamping logic. No improvisation.
- **Minimal test modification.** Only 2 existing tests needed `applyFilter()` calls added (the two that set `filterQuery` directly). The remaining 12 tests pass without modification because they either don't touch `filterQuery` or use `showHUD()`/`dismissHUD()` which call `applyFilter()` internally.
- **Good new test coverage.** The `applyFilterClampsSelectedIndex` test specifically verifies the clamping invariant with `selectedIndex = 2` and a filter that reduces to 1 result, confirming the index is clamped to 0.
- **Self-contained invariant.** The state class now owns the `selectedIndex` clamping invariant inside `applyFilter()`, rather than leaving it to callers. This is a clean architectural improvement.

## Redo Instructions

N/A -- verdict is pass.
