# Code Review: T10 — Cache Heading Y-Positions for Scroll-Spy Performance

**Date:** 2026-03-22
**Round:** 1
**Verdict:** pass

## Summary

Clean, spec-faithful implementation. The caching layer, binary search, invalidation strategy, and observer lifecycle are all correct. No correctness or data-safety issues found.

## What This Code Does (Reviewer's Model)

The change adds a caching layer to the scroll-spy hot path in `SelectableTextView+Coordinator`. Previously, every scroll event triggered O(n) calls to `yPosition(forCharacterOffset:)`, each forcing a layout pass via `.ensuresLayout`. The new code:

1. Stores a sorted array of `(blockIndex, y)` tuples (`cachedHeadingPositions`) alongside a validity flag (`headingPositionsCacheValid`).
2. On scroll, lazily rebuilds the cache if invalid, then performs a binary search (O(log n)) to find the last heading at or above the viewport top.
3. Invalidates the cache on two triggers: (a) `headingOffsets` changing in `updateNSView` (content change), and (b) `NSView.frameDidChangeNotification` on the text view (resize).
4. Adds a `deinit` to cleanly remove both the scroll and frame notification observers.
5. Modifies `updateNSView` to compare `headingOffsets` before assignment, preventing spurious cache invalidation on every render cycle.

The `yPosition(forCharacterOffset:)` method with `.ensuresLayout` is preserved unchanged for cache-building (runs infrequently) and `scrollToHeading()` (runs on user action). The hot path no longer touches the layout manager.

## Transitions Identified

| Transition | Handled Safely? |
|---|---|
| Cache invalid -> rebuild (lazy on next scroll) | Yes. `rebuildHeadingPositionCache()` sets flag to true atomically with populating the array. |
| Content change -> headingOffsets differ -> invalidation | Yes. `updateNSView` compares before assigning, then calls `invalidateHeadingPositionCache()`. |
| Frame resize -> invalidation | Yes. Notification observer sets `headingPositionsCacheValid = false`. Stale array entries are harmless since they are never read when the flag is false. |
| Observer start -> cleanup on restart | Yes. `startScrollSpy` removes existing `frameObserver` and `scrollObserver` before adding new ones. |
| Observer lifecycle -> deinit | Yes. `deinit` removes both observers. Properties are `nonisolated(unsafe)` for Swift 6 deinit access. |
| outlineState becomes nil (weak ref) | Yes. `rebuildHeadingPositionCache` guards on `outlineState`, clears cache and sets flag to false. `handleScrollForSpy` guards and returns early. |
| Empty cache after rebuild (no valid heading positions) | Yes. Falls through to setting `currentBlockIndex` to `firstBlockIndex - 1`. |

## Convention Check

**Neighboring files examined:** `SelectableTextView.swift`, `OutlineState.swift`, `EntranceAnimator.swift`, `OverlayCoordinator.swift`, `FindBarView.swift`
**Convention violations found:** 0

The code follows established patterns:
- `nonisolated(unsafe)` for observer tokens matches the existing `scrollObserver` pattern.
- Guard-early-return throughout.
- MARK comments for section organization.
- Doc comments on cache properties.
- Private visibility for cache internals, internal visibility for `invalidateHeadingPositionCache()` (needed cross-extension).

## Findings

### Finding 1: swiftlint type_body_length disable

**Severity:** minor
**Category:** convention
**File:** `mkdn/Features/Viewer/Views/SelectableTextView+Coordinator.swift`
**Lines:** 9
**Code:**
```swift
// swiftlint:disable:next type_body_length
```
**Issue:** The Coordinator class exceeded the `type_body_length` threshold after the cache additions, requiring an inline disable.
**Impact:** None functionally. The disable is pragmatic and the build log justifies it (Coordinator is a cohesive unit where splitting would add complexity). This is a pre-existing pressure point, not something T10 introduced poorly.
**Fix:** No action needed. If the Coordinator grows further in future tasks, consider extracting the find-highlight logic into a helper type to bring the body length back under the threshold.

## Acceptance Criteria Verification

| Criterion | Met? | Evidence |
|-----------|------|----------|
| `handleScrollForSpy()` does zero `enumerateTextLayoutFragments` calls when cache is valid | yes | Lines 124-167: when `headingPositionsCacheValid` is true, skips `rebuildHeadingPositionCache()` and only does binary search on the array |
| Cache invalidated only when `headingOffsets` actually changes or text view frame changes | yes | `SelectableTextView.swift:93-96` (compares before assigning), `Coordinator.swift:117-121` (frame observer) |
| `headingOffsets` comparison in `updateNSView` prevents spurious invalidation | yes | `SelectableTextView.swift:93`: `if coordinator.headingOffsets != headingOffsets` |
| Cache lazily rebuilt on next scroll event after invalidation | yes | `Coordinator.swift:134-137`: checks flag, calls rebuild |
| Binary search for O(log n) lookup | yes | `Coordinator.swift:146-157`: standard binary search on sorted array |
| `scrollToHeading` still works correctly (uses `yPosition` directly) | yes | `Coordinator.swift:220-228`: calls `yPosition(forCharacterOffset:)` directly, no cache involvement |
| Explicit `deinit` removes both observers | yes | `Coordinator.swift:27-34` |
| `swift build` passes | yes | Build log: "Build complete! (3.85s)" |
| SwiftLint and SwiftFormat pass | yes | Build log: "0 violations", "0/2 files formatted (already clean)" |

## What Was Done Well

- The binary search implementation is textbook-correct, finding the rightmost element with `y <= viewportTop`.
- Cache invalidation is conservative (clear on any content or layout change) without being wasteful (compare-before-assign in `updateNSView` prevents spurious rebuilds).
- The frame observer is correctly scoped to the text view (not the scroll view or clip view), which is the right object to observe for layout-affecting size changes.
- Observer cleanup in `startScrollSpy` removes existing observers before adding new ones, preventing leaks on re-entry.
- The `rebuildHeadingPositionCache` guard-on-nil-outlineState path correctly clears the cache and resets the flag, rather than leaving stale data.
