# Code Review: T2 — OutlineState — State Management

**Date:** 2026-03-22
**Round:** 1
**Verdict:** pass

## Summary

Solid, spec-compliant implementation that correctly follows the FindState pattern. All 14 tests pass, SwiftLint reports zero violations, and the code integrates cleanly with the T1 HeadingNode/HeadingTreeBuilder types.

## Findings

### Finding 1: selectedIndex can drift when filterQuery changes
**Severity:** minor
**File:** mkdn/Features/Outline/ViewModels/OutlineState.swift
**Lines:** 38, 152-163
**Code:**
```swift
public var selectedIndex = 0
```
**Issue:** When `filterQuery` changes (user types into the filter field), `filteredHeadings` may shrink. `selectedIndex` is not automatically clamped to the new filtered count. If `selectedIndex` was 5 and the filtered list shrinks to 3 items, `moveSelectionUp`/`moveSelectionDown` will wrap correctly (they use `filteredHeadings.count`), and `selectAndNavigate` clamps with `min(selectedIndex, filtered.count - 1)`. So this is safe in practice -- the clamping in `selectAndNavigate` at line 145 handles it. However, the HUD view (T5) will need to be careful to clamp when highlighting the selected row.
**Expected:** Not a required change for T2. The spec does not mention resetting selectedIndex on filter change, and the defensive clamping in `selectAndNavigate` prevents out-of-bounds access. T5 should clamp when rendering.

### Finding 2: fuzzyScore uses greedy left-to-right matching
**Severity:** minor
**File:** mkdn/Features/Outline/ViewModels/OutlineState.swift
**Lines:** 203-234
**Code:**
```swift
private func fuzzyScore(query: [Character], target: String) -> Int? {
    // ...greedy scan...
}
```
**Issue:** The greedy left-to-right scan does not always find the highest-scoring alignment. For example, query "ab" against target "a_ab" would match positions 0,3 (score 1 for word boundary on 'a') rather than positions 2,3 (score 2 for consecutive match). The spec says "Simple scoring" and this matches the described algorithm exactly: "+2 for consecutive matches, +1 for word-boundary matches". A more optimal algorithm would backtrack, but that's beyond the spec.
**Expected:** No change needed. The spec explicitly calls for a simple scoring approach, and this implementation matches the spec's algorithm description faithfully.

## What Was Done Well

- Exact match to the FindState pattern: `#if os(macOS)`, `import Foundation`, `@MainActor @Observable public final class`, same file structure with MARK sections.
- `private(set)` correctly applied to all properties that should not be externally mutable (`headingTree`, `flatHeadings`, `currentHeadingIndex`, `breadcrumbPath`, `isBreadcrumbVisible`), while `isHUDVisible`, `filterQuery`, and `selectedIndex` are correctly public-writable (needed by the view layer).
- The `updateHeadings` method correctly resets all derived state when the heading tree becomes empty, preventing stale breadcrumb/HUD state.
- The `updateScrollPosition` method has clean guard-based early returns for edge cases (empty headings, before first heading).
- Defensive clamping in `selectAndNavigate` (`min(selectedIndex, filtered.count - 1)`) prevents index-out-of-bounds.
- Fuzzy matching implementation is clean and well-documented, with correct word-boundary detection (space, dash, string start).
- Test coverage is complete: all 14 specified test cases are present and pass. Tests use `@MainActor` on individual test functions (not `@Suite`), matching the project's testing pattern.
- The `mixedBlocks` helper in tests creates realistic scenarios with non-heading blocks interleaved.
- Documentation comments are thorough and consistent with project style.

## Redo Instructions

N/A -- verdict is pass.
