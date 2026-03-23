# Code Review: T5 — OutlineNavigatorView — HUD with Keyboard Navigation and Animation

**Date:** 2026-03-22
**Round:** 1
**Verdict:** pass

## Summary

Clean, spec-compliant implementation of the OutlineNavigatorView. The placeholder from T3 has been replaced with a full breadcrumb + HUD view with filter field, heading list, keyboard navigation, click-outside-to-dismiss, and proper spring animation with Reduce Motion fallback. The `pendingScrollTarget` property was correctly added to OutlineState. All tests pass, build succeeds, and linting is clean.

## Findings

### Finding 1: Breadcrumb animation uses .fadeIn for both directions
**Severity:** minor
**File:** mkdn/Features/Outline/Views/OutlineNavigatorView.swift
**Lines:** 52-55
**Code:**
```swift
.animation(
    motion.resolved(.fadeIn),
    value: outlineState.isBreadcrumbVisible
)
```
**Issue:** The spec says "Animate breadcrumb visibility with `motion.resolved(.fadeIn)` / `motion.resolved(.fadeOut)`", suggesting distinct animations for appearing vs disappearing. The implementation uses `.fadeIn` for both directions via a single `.animation(_:value:)` modifier. This means the disappear uses an ease-out curve (0.5s) rather than the spec's suggested ease-in curve (0.4s) from `.fadeOut`.
**Expected:** This is a cosmetic nuance. The current approach is simpler and produces an acceptable visual result. SwiftUI's `.animation(_:value:)` does not easily support asymmetric timing without `.transition()`, so the simplification is reasonable. No change required.

### Finding 2: Filter field onChange captures filteredHeadings correctly but recomputes it
**Severity:** minor
**File:** mkdn/Features/Outline/Views/OutlineNavigatorView.swift
**Lines:** 129-134
**Code:**
```swift
.onChange(of: outlineState.filterQuery) { _, _ in
    let count = outlineState.filteredHeadings.count
    if count > 0, outlineState.selectedIndex >= count {
        outlineState.selectedIndex = count - 1
    }
}
```
**Issue:** `filteredHeadings` is a computed property that runs the fuzzy matching algorithm on each access. This `onChange` accesses it to get the count, and the view body also accesses it for the list. This means the fuzzy filter runs twice per query change. For typical document sizes (tens of headings) this is negligible. Just noting for awareness — not actionable.
**Expected:** Acceptable as-is for the expected data sizes.

## What Was Done Well

- **Faithful spec implementation**: Every acceptance criterion is met. The two visual states (breadcrumb and HUD), keyboard navigation, click-outside-to-dismiss, filter field auto-focus, level-based indentation, selected/current heading indicators, and animation system are all implemented correctly.
- **Defensive index clamping**: The `onChange(of: filterQuery)` handler that clamps `selectedIndex` when filter results shrink is a good defensive addition not explicitly required by the spec but important for preventing out-of-bounds access.
- **Clean separation of concerns**: The view correctly reads all state from `OutlineState` and delegates mutations back to it. The breadcrumb bar is cleanly composed via the `OutlineBreadcrumbBar` subview from T4.
- **Proper `@Bindable` usage**: Line 118 correctly creates a `@Bindable` wrapper for the `@Observable` `outlineState` to enable `$` binding syntax for the TextField.
- **Reactive scroll-to-selection**: Using `onChange(of: selectedIndex)` to scroll the list after keyboard navigation is elegant and avoids duplicating scroll logic in each key handler.
- **DispatchQueue.main.async for focus**: The async dispatch on line 108 for setting `isFilterFocused` is a well-known SwiftUI workaround to ensure focus is set after the view hierarchy is ready.

## Redo Instructions

N/A — verdict is pass.
