# A2: Programmatic Scrolling to Heading Positions

**Date:** 2026-03-21
**Source:** `mkdn/Features/Viewer/Views/SelectableTextView+Coordinator.swift`, `mkdn/Core/TestHarness/TestHarnessHandler+Scroll.swift`, `mkdn/Features/Viewer/Views/SelectableTextView.swift`

## Finding

`scrollRangeToVisible()` is already used in the codebase for the find-in-page feature and works correctly with the custom `CodeBlockBackgroundTextView` (an `NSTextView` subclass). Additionally, the test harness uses `scrollView.contentView.scroll(to:)` + `scrollView.reflectScrolledClipView()` for absolute y-position scrolling. Both approaches are available and proven for scroll-to-heading.

The `CodeBlockBackgroundTextView` inherits from `NSTextView` and does not override any scrolling methods, so `scrollRangeToVisible()` works as expected. The text view uses TextKit 2 (`NSTextLayoutManager`), not TextKit 1 (`NSLayoutManager`), which means `scrollRangeToVisible()` works via the TextKit 2 layout pipeline.

## Evidence

From `SelectableTextView+Coordinator.swift:196-199` -- `scrollRangeToVisible` used for find navigation:
```swift
if let currentRange =
    findState.matchRanges[safe: findState.currentMatchIndex]
{
    textView.scrollRangeToVisible(currentRange)
}
```

From `TestHarnessHandler+Scroll.swift:38-40` -- absolute y-position scrolling:
```swift
scrollView.contentView.scroll(to: point)
scrollView.reflectScrolledClipView(scrollView.contentView)
```

From `SelectableTextView.swift:125-128` -- the text view is `CodeBlockBackgroundTextView`, which inherits `NSTextView`:
```swift
let textView = CodeBlockBackgroundTextView(
    frame: .zero,
    textContainer: textContainer
)
```

The Coordinator holds a `weak var textView: NSTextView?` reference (line 10), providing direct access to `scrollRangeToVisible()`.

## Two Viable Approaches

**Approach 1: `scrollRangeToVisible(NSRange)`** -- Pass the heading's character range. Simple, proven in this codebase. Scrolls the range into the visible rect but may place the heading anywhere within the viewport (not necessarily at the top).

**Approach 2: Layout manager rect + `scroll(to:)`** -- Use `enumerateTextLayoutFragments` to get the heading's y-coordinate, then `scrollView.contentView.scroll(to: NSPoint(x: 0, y: headingY))` to position the heading at the viewport top. More control over final position. Also proven in this codebase (test harness uses this).

Recommendation: Use Approach 2 for scroll-to-heading navigation (positions heading at viewport top, matching user expectations for outline navigation). Use `scrollRangeToVisible()` only as a fallback if the layout fragment is not available.
