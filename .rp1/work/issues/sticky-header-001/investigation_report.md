# Root Cause Investigation Report - sticky-header-001

## Executive Summary
- **Problem**: Sticky table headers appear for small tables that fit entirely on screen and are positioned incorrectly (floating over data rows instead of pinning to the visible top).
- **Root Cause**: Two defects in `OverlayCoordinator.handleScrollBoundsChange()`: (1) no check that the table is taller than the visible scroll area before showing a sticky header, and (2) the sticky header Y-position is computed using the clip view's `bounds.origin.y` (scroll offset in the text view's coordinate space) plus `textContainerOrigin.y`, but is applied to a subview of the text view where the Y coordinate should be `visibleRect.origin.y` alone (without the double-offset from textContainerOrigin).
- **Solution**: Add a height threshold check and fix the Y-position calculation.
- **Urgency**: Should be fixed before next release; the bug is visually disruptive for common small tables.

## Investigation Process
- **Duration**: Static code analysis
- **Hypotheses Tested**: 3 (results below)
- **Key Evidence**: Source code analysis of `OverlayCoordinator.handleScrollBoundsChange()`, coordinate system tracing, comparison with `positionEntry()` method

## Root Cause Analysis

### Bug 1: Sticky header appears for tables that fit on screen

**Location**: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/OverlayCoordinator.swift`, lines 447-479 (`handleScrollBoundsChange()`)

**Technical Details**:

The visibility condition at line 460 is:

```swift
if visibleRect.origin.y > headerBottom,
   visibleRect.origin.y < tableBottom - headerHeight
```

This checks whether the scroll offset has moved past the table's header row bottom, and whether we have not scrolled past the table's data area. However, there is **no guard** that checks whether the table is actually taller than the visible area. For a small 3-row table (header + 2 data rows), the entire table fits within the visible viewport. In that scenario, the table header never actually "scrolls out of view" in the visual sense -- the table is fully visible. But the condition `visibleRect.origin.y > headerBottom` can still be true if the table is positioned near the top of the document and the user has scrolled past the table's header Y coordinate in the document -- even though the table is still fully visible within the viewport.

The missing check is:

```swift
let tableHeight = tableFrame.height
let visibleHeight = scrollView.contentView.bounds.height
guard tableHeight > visibleHeight else { continue }  // skip sticky header for small tables
```

Without this guard, any table whose document-space header position is above the scroll offset will trigger the sticky header, regardless of whether the table itself is fully visible.

**Causation Chain**: Table renders at document Y position -> User scrolls so that `visibleRect.origin.y` exceeds the table's header bottom Y coordinate -> No height threshold check -> Sticky header is shown even though the entire table (including its header) is fully visible in the viewport.

### Bug 2: Sticky header is positioned incorrectly (floating over data rows)

**Location**: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/OverlayCoordinator.swift`, lines 469-474

**Technical Details**:

The sticky header frame is set as:

```swift
stickyHeaders[blockIndex]?.frame = CGRect(
    x: tableFrame.origin.x,
    y: visibleRect.origin.y + textView.textContainerOrigin.y,
    width: tableFrame.width,
    height: headerHeight
)
```

The problem is the `y` calculation: `visibleRect.origin.y + textView.textContainerOrigin.y`.

Here is how the coordinate system works:
- The sticky header is added as a **subview of the NSTextView** (the document view, not the scroll view).
- The NSTextView's coordinate space extends from 0 at the top to the full document height.
- `visibleRect.origin.y` is `scrollView.contentView.bounds.origin.y` -- this is the scroll offset, representing the Y position of the top of the visible area **in the NSTextView's coordinate space**.
- `textView.textContainerOrigin.y` is the inset from the text view's frame origin to where the text container begins (32pt based on `textContainerInset = NSSize(width: 32, height: 32)`).

When you place a subview on the NSTextView at Y = `visibleRect.origin.y`, it appears at the top of the visible viewport (because the scroll offset defines what part of the text view is visible). Adding `textContainerOrigin.y` pushes it **down** by the text container inset (32pt), placing it below the top of the viewport -- directly over the data rows.

Compare with how table overlays themselves are positioned in `positionEntry()` at line 379:

```swift
entry.view.frame = CGRect(
    x: context.origin.x,
    y: fragmentFrame.origin.y + context.origin.y,  // context.origin = textContainerOrigin
    width: overlayWidth,
    height: fragmentFrame.height
)
```

Here `context.origin.y` (which is `textContainerOrigin.y`) is added to `fragmentFrame.origin.y` because layout fragments are positioned relative to the text container, and overlays need to be in the text view's coordinate space. That makes sense.

But for sticky headers, the intent is to pin to the **top of the visible viewport**. The top of the visible viewport in the text view's coordinate space is simply `visibleRect.origin.y` -- no inset offset needed.

**The correct Y-position should be**:

```swift
y: visibleRect.origin.y
```

Not:

```swift
y: visibleRect.origin.y + textView.textContainerOrigin.y
```

**Causation Chain**: Scroll event fires -> `handleScrollBoundsChange()` computes Y as `visibleRect.origin.y + textContainerOrigin.y` -> Sticky header is placed 32pt below the visible top edge -> Header floats over the data rows instead of being flush with the visible top.

### Why It Occurred

The T5 implementation (commit `4795cd4`) introduced scroll-based sticky header positioning. Two contributing factors:

1. **Coordinate system confusion**: The text view's subview coordinate space was conflated with the text container's layout coordinate space. The `textContainerOrigin` offset is needed when converting layout fragment positions to text view coordinates (as `positionEntry()` correctly does), but it should NOT be added when computing a scroll-pinned position, because `visibleRect.origin.y` is already in the text view's coordinate space.

2. **Missing threshold check**: The implementation focused on when to show/hide based on scroll position relative to the table's header, but did not consider whether the table actually needs a sticky header (i.e., whether the table is taller than the viewport). This is a common oversight in sticky header implementations -- the "should this table have sticky behavior at all?" question was not addressed.

## Proposed Solutions

### 1. Recommended: Fix both bugs in `handleScrollBoundsChange()` (Effort: Small)

Two targeted changes in `OverlayCoordinator.swift`:

**Fix A -- Add height threshold guard**:
Before the existing visibility condition, add:

```swift
let visibleHeight = visibleRect.height
guard tableFrame.height > visibleHeight else {
    stickyHeaders[blockIndex]?.isHidden = true
    continue
}
```

This ensures sticky headers are only considered for tables taller than the visible area.

**Fix B -- Remove textContainerOrigin from Y calculation**:
Change line 472 from:

```swift
y: visibleRect.origin.y + textView.textContainerOrigin.y,
```

To:

```swift
y: visibleRect.origin.y,
```

**Pros**: Minimal change, directly addresses both root causes, no side effects on other overlay positioning.
**Cons**: None identified.
**Risk**: Low. The change is isolated to the sticky header positioning path.

### 2. Alternative: Compute Y from the scroll view's visible rect instead of clip view bounds

Instead of working with `scrollView.contentView.bounds`, convert the scroll view's visible rect into the text view's coordinate space:

```swift
let visibleInTextView = textView.convert(scrollView.contentView.bounds, from: scrollView.contentView)
```

Then use `visibleInTextView.origin.y` for positioning. This approach is more explicit about coordinate conversions but functionally equivalent to Fix B.

**Pros**: More readable intent.
**Cons**: Slightly more code; `convert(_:from:)` adds a coordinate conversion that is unnecessary since the clip view's bounds are already in the text view's coordinate space.

## Prevention Measures

1. **Add a unit/integration test** for sticky header visibility that verifies:
   - Small tables (height < viewport) never show sticky headers
   - Large tables only show sticky headers when the header row has scrolled out of view
   - Sticky header Y position matches the top of the visible area

2. **Document the coordinate system** in the OverlayCoordinator with a comment block explaining:
   - Text view coordinate space vs text container coordinate space
   - When to add `textContainerOrigin` (layout fragment -> text view subview positioning)
   - When NOT to add it (scroll-pinned positioning)

3. **Add the visual verification workflow** for sticky header behavior with a fixture that has both a small table and a large table.

## Evidence Appendix

### Evidence 1: Missing height threshold in `handleScrollBoundsChange()`

File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/OverlayCoordinator.swift`
Lines 447-479. The for-loop iterates all table entries and checks scroll position, but never compares `tableFrame.height` against `visibleRect.height`.

### Evidence 2: Incorrect Y-offset in sticky header positioning

File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/OverlayCoordinator.swift`
Line 472: `y: visibleRect.origin.y + textView.textContainerOrigin.y`

The `textContainerInset` is set to `NSSize(width: 32, height: 32)` at line 138 of `SelectableTextView.swift`:
```swift
textView.textContainerInset = NSSize(width: 32, height: 32)
```

This means `textContainerOrigin.y` = 32pt, pushing the sticky header 32pt below where it should be.

### Evidence 3: Correct pattern in `positionEntry()` for comparison

File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/OverlayCoordinator.swift`
Lines 377-386. The table overlay itself is correctly positioned using `fragmentFrame.origin.y + context.origin.y` because `fragmentFrame` is relative to the text container, not the text view. The sticky header, by contrast, should be pinned to the viewport top, which is `visibleRect.origin.y` in text view coordinates -- no text container offset needed.

### Evidence 4: T5 commit introduced both bugs

Commit `4795cd4` introduced the `handleScrollBoundsChange()` method in its entirety. Both bugs have been present since the initial implementation.
