# Scroll Mechanics on macOS

**Date:** 2026-03-21
**Source:** `mkdn/Features/Viewer/Views/SelectableTextView.swift`, `mkdn/Core/TestHarness/TestHarnessHandler+Scroll.swift`, `mkdn/Core/Markdown/BlockScrollTarget.swift`

## Finding

The macOS rendering path uses a single `NSTextView` inside an `NSScrollView`. Scroll position is accessed via `scrollView.contentView.bounds.origin.y`. Programmatic scrolling uses `scrollView.contentView.scroll(to:)` + `scrollView.reflectScrolledClipView()`. The `NSScrollView` is accessible from the Coordinator, which already holds a `weak var textView: NSTextView?` reference. Scroll position observation can be done via `NSView.boundsDidChangeNotification` on the scroll view's `contentView` (the standard AppKit pattern).

`BlockScrollTarget` exists for the Platform/iOS path (`MarkdownContentView` with `ScrollViewReader`) and is not used in the macOS `SelectableTextView` path. For macOS, scroll-to-heading must use NSTextView/NSLayoutManager APIs to find the character range of a heading block and scroll to it.

## Evidence

From `TestHarnessHandler+Scroll.swift:38-40` (programmatic scroll):
```swift
scrollView.contentView.scroll(to: point)
scrollView.reflectScrolledClipView(scrollView.contentView)
```

From `SelectableTextView+Coordinator.swift:10-11`:
```swift
weak var textView: NSTextView?
weak var documentState: DocumentState?
```

For scroll-spy, the approach is:
1. The Coordinator (or a new observer) subscribes to `NSView.boundsDidChangeNotification` on the scroll view's clip view
2. On each notification, read `contentView.bounds.origin.y` to get the viewport top
3. Find which heading block is at or above that y-position using the text layout manager
4. Update the outline state's current heading path

For scroll-to-heading, the approach is:
1. Find the character range of the target heading in the attributed string
2. Use `textView.scrollRangeToVisible()` or calculate the rect via layout manager and scroll to it
