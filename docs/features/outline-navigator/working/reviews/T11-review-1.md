# Code Review: T11 — Rebuild OutlineNavigatorView as Single Morphing Component

**Date:** 2026-03-22
**Round:** 1
**Verdict:** pass

## Summary

Clean, faithful implementation of the morphing container pattern. The shared container shell, content cross-fade transitions, pendingScrollTarget fix, and filterQuery wiring are all correct. One minor finding (double `applyFilter()` call on dismiss) that does not affect correctness.

## What This Code Does (Reviewer's Model)

`OutlineNavigatorView` is a single SwiftUI view with one shared VStack container. The container carries all visual properties (frame, background, clipShape, shadow, cornerRadius) and animates them continuously via `.animation(motion.resolved(.springSettle), value: isExpanded)`. The boolean `isExpanded` is a computed property that reads `outlineState.isHUDVisible`.

Inside the container, an `if/else` selects between HUD content (filter field + divider + heading list) and breadcrumb content. Each branch has `.transition(.opacity)`, producing a cross-fade when the content identity changes. The breadcrumb content is inlined directly (not using `OutlineBreadcrumbBar` subview), while `OutlineBreadcrumbBar.swift` is preserved as-is.

The pendingScrollTarget fix in `SelectableTextView.updateNSView` introduces a `lastScrolledTarget` property on the Coordinator. When a `pendingScrollTarget` is set, the code checks it against `lastScrolledTarget` to skip duplicate scrolls. After scrolling, it defers `pendingScrollTarget = nil` to a `Task { @MainActor in }` to avoid mutating state during the render cycle. `lastScrolledTarget` is reset to nil in `applyNewContent` when document content changes, allowing re-navigation to the same heading in a different document.

The `.onChange(of: outlineState.filterQuery)` handler calls `outlineState.applyFilter()` (from T8), replacing the old manual `selectedIndex` clamping.

## Transitions Identified

| Transition | Handled Safely? |
|---|---|
| Breadcrumb -> HUD (expand) | Yes. `isExpanded` drives `.animation(.springSettle)` on the shared container. Content cross-fades via `.transition(.opacity)`. Click-outside scrim appears for dismiss. |
| HUD -> Breadcrumb (collapse) | Yes. Same animation in reverse. `dismissHUD()` clears `filterQuery` and `isHUDVisible`. |
| Breadcrumb visibility (scroll-spy) | Yes. Separate `.animation(.fadeIn, value: isBreadcrumbVisible)` controls opacity independently from the expand/collapse animation. |
| Filter query change -> recompute | Yes. `.onChange(of: filterQuery)` calls `applyFilter()` which recomputes `filteredHeadings` and clamps `selectedIndex`. |
| pendingScrollTarget set -> consumed | Yes. Guard against `lastScrolledTarget` prevents double-scroll. Deferred nil-out avoids render-cycle mutation. |
| Content change -> lastScrolledTarget reset | Yes. `applyNewContent` sets `coordinator.lastScrolledTarget = nil`. |
| HUD open -> focus filter field | Yes. `.onChange(of: isHUDVisible)` uses `DispatchQueue.main.async` to set `isFilterFocused = true`, avoiding focus during the same layout pass. |
| selectAndNavigate -> dismiss | Yes. Sets `pendingScrollTarget` then calls `dismissHUD()`, which sets `isHUDVisible = false`. Container animates closed while Coordinator consumes the scroll target. |

## Convention Check

**Neighboring files examined:** `FindBarView.swift`, `ContentView.swift`, `SelectableTextView.swift`, `SelectableTextView+Coordinator.swift`, `OutlineBreadcrumbBar.swift`, `OutlineState.swift`, `AnimationConstants.swift`, `MotionPreference.swift`
**Convention violations found:** 0

The code follows established patterns:
- `#if os(macOS)` guard wrapping the entire file.
- `import SwiftUI` only (no AppKit import needed for a pure SwiftUI view).
- `@Environment` for state injection, `@FocusState` for focus management.
- `MotionPreference` for Reduce Motion resolution.
- MARK comments for section organization.
- Doc comment on the struct.
- Private computed properties for view decomposition (`outlineContainer`, `breadcrumbContent`, `filterField`, `headingList`).
- `@Bindable` local binding in `filterField` for two-way binding to `@Observable` state (matches `FindBarView` pattern).

## Findings

### Finding 1: Double applyFilter() call on dismissHUD/showHUD

**Severity:** minor
**Category:** performance
**File:** `mkdn/Features/Outline/Views/OutlineNavigatorView.swift`
**Lines:** 114-116
**Code:**
```swift
.onChange(of: outlineState.filterQuery) { _, _ in
    outlineState.applyFilter()
}
```
**Issue:** When `dismissHUD()` or `showHUD()` sets `filterQuery = ""`, both the internal `applyFilter()` call in those methods AND the `.onChange` handler fire, resulting in `applyFilter()` being called twice. This is not a correctness issue because `applyFilter()` is idempotent and operates on a small collection (document headings), but it is redundant work.
**Impact:** Negligible. Two calls to filter a list of typically <50 headings. No user-visible effect.
**Fix:** No action needed. If this were a hot path, the fix would be to remove the explicit `applyFilter()` calls from `dismissHUD()`/`showHUD()` and rely solely on the `.onChange` handler, but that would create a dependency on the view being mounted. The current approach is more robust.

## Acceptance Criteria Verification

| Criterion | Met? | Evidence |
|-----------|------|----------|
| Container (frame, background, clipShape, shadow, cornerRadius) is SHARED between breadcrumb and HUD states and animates continuously | yes | `OutlineNavigatorView.swift:69-81`: single VStack with all shell modifiers applied once, `.animation(.springSettle, value: isExpanded)` |
| Content inside uses `if/else` with `.transition(.opacity)` for cross-fade | yes | `OutlineNavigatorView.swift:51-67`: `if isExpanded` branches with `.transition(.opacity)` on each child |
| `.ultraThinMaterial` background is on the outer container, shared between both states | yes | `OutlineNavigatorView.swift:72`: `.background(.ultraThinMaterial)` on the VStack |
| Container dimensions animate via `springSettle` (width, height, corner radius, shadow) | yes | `OutlineNavigatorView.swift:70-71,73-78,80`: `maxWidth`, `maxHeight`, `cornerRadius`, shadow params all conditional on `isExpanded`, animated by line 80 |
| `pendingScrollTarget` uses `lastScrolledTarget` tracking to prevent double-scroll; `lastScrolledTarget` resets on content change | yes | `SelectableTextView.swift:120-128` (guard + deferred nil), `SelectableTextView.swift:202` (reset in `applyNewContent`), `Coordinator.swift:19` (property) |
| `.onChange(of: outlineState.filterQuery)` calls `outlineState.applyFilter()` (from T8) | yes | `OutlineNavigatorView.swift:114-116` |
| `OutlineBreadcrumbBar.swift` is kept as-is (not deleted) | yes | File exists unchanged at `mkdn/Features/Outline/Views/OutlineBreadcrumbBar.swift` |
| All keyboard navigation works | yes | `OutlineNavigatorView.swift:83-106`: `.onKeyPress` for up/down/return/escape, all guarded by `isExpanded` |
| Filter field auto-focuses on HUD open | yes | `OutlineNavigatorView.swift:107-112`: `.onChange(of: isHUDVisible)` sets `isFilterFocused = true` |
| `swift build` and `swift test` pass | yes | Build log: "Build complete! (4.23s)", "667 tests, 2 pre-existing failures in MermaidThemeMapper (unrelated)" |
| SwiftLint and SwiftFormat pass | yes | Build log: "0 violations", "0/3 files formatted (clean after auto-format)" |

## What Was Done Well

- The morphing container pattern is implemented cleanly: one VStack, one set of shell modifiers, one `.animation` driver. The separation between "container animates" and "content cross-fades" is clear and correct.
- The `pendingScrollTarget` fix correctly avoids both problems identified in the spec: render-cycle mutation (via deferred Task) and double-scroll (via lastScrolledTarget tracking). The reset in `applyNewContent` ensures the guard does not permanently block navigation after a single use.
- Inlining `breadcrumbContent` while keeping `OutlineBreadcrumbBar.swift` intact follows the spec precisely and preserves the standalone component for potential reuse.
- The code is well-organized with MARK sections and reads cleanly top-to-bottom.
