# Code Review: T6 — Scroll-Spy and Heading Data Feed — Coordinator Integration

**Date:** 2026-03-22
**Round:** 1
**Verdict:** pass

## Summary

T6 is a solid implementation that correctly wires scroll-spy into the existing Coordinator and feeds heading data from MarkdownPreviewView. All spec requirements are met: heading character offsets are tracked in TextStorageResult, the scroll-spy maps viewport position to heading block indices, and pendingScrollTarget is consumed for scroll-to-heading navigation. The code integrates cleanly with T1-T5 without breaking existing functionality.

## Findings

### Finding 1: No deinit cleanup for scroll observer
**Severity:** minor
**File:** `mkdn/Features/Viewer/Views/SelectableTextView+Coordinator.swift`
**Lines:** 18, 67-84
**Code:**
```swift
var scrollObserver: NSObjectProtocol?

func startScrollSpy(on scrollView: NSScrollView) {
    if let existing = scrollObserver {
        NotificationCenter.default.removeObserver(existing)
        scrollObserver = nil
    }
    // ...
    scrollObserver = NotificationCenter.default.addObserver(...)
}
```
**Issue:** The Coordinator has no `deinit` to remove the scroll observer when the Coordinator is deallocated. Block-based NotificationCenter observers registered with `addObserver(forName:object:queue:)` are not automatically removed on token deallocation — Apple's docs require explicit removal.
**Expected:** Add `deinit { if let scrollObserver { NotificationCenter.default.removeObserver(scrollObserver) } }` to the Coordinator. However, this follows the existing codebase pattern (OverlayCoordinator also omits deinit cleanup), so this is a pre-existing convention rather than a T6-specific regression. Flagging as minor.

## What Was Done Well

- **TextStorageResult change is minimal and non-intrusive.** Adding `headingOffsets` with a default empty dictionary means all existing call sites continue to work without modification. The recording happens right before each heading block is appended, which is the correct position to capture the character offset.
- **Scroll-spy follows the recommended simplified approach.** O(n) reverse iteration over flatHeadings per scroll event is pragmatic for typical document sizes and avoids premature optimization with caching.
- **Clean integration with existing patterns.** The `outlineState` is passed through the same representable/coordinator channel used by `findState` and `documentState`. The `headingOffsets` are updated in both `makeNSView` and `updateNSView`, ensuring they stay current.
- **pendingScrollTarget consumption is properly placed** in `updateNSView` where SwiftUI drives state changes, and the target is nil'd immediately after scrolling to prevent repeated scrolls.
- **The scroll-spy fallback is well-handled.** When the viewport is above all headings, `firstBlockIndex - 1` is passed to `updateScrollPosition`, which correctly triggers the "before first heading" guard in OutlineState, hiding the breadcrumb.
- **startScrollSpy defensively removes any existing observer** before creating a new one, preventing duplicate observer accumulation if called multiple times.

## Redo Instructions

N/A — verdict is pass.
