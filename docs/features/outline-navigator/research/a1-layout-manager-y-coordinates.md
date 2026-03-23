# A1: NSTextLayoutManager Y-Coordinate Mapping for Scroll-Spy

**Date:** 2026-03-21
**Source:** `mkdn/Features/Viewer/Views/OverlayCoordinator+Positioning.swift`, `mkdn/Features/Viewer/Views/OverlayCoordinator+TableOverlays.swift`, `mkdn/Features/Viewer/Views/OverlayCoordinator+Observation.swift`, `mkdn/Features/Viewer/Views/SelectableTextView.swift`

## Finding

The codebase already uses `NSTextLayoutManager.enumerateTextLayoutFragments(from:options:)` extensively to map character ranges to y-coordinates via `fragment.layoutFragmentFrame`. This is the same API needed for scroll-spy. The `OverlayCoordinator` has a complete, battle-tested pattern for this: convert an `NSRange` location to an `NSTextContentManager` location, enumerate fragments from that location with `.ensuresLayout`, and read `layoutFragmentFrame` to get the rect. The scroll-spy can reuse this exact pattern.

Additionally, the `OverlayCoordinator` already observes `NSView.boundsDidChangeNotification` on the clip view for scroll-driven repositioning (see `observeScrollChanges(on:)` in `OverlayCoordinator+Observation.swift`). The scroll-spy needs the same observation, and can either share it or add a parallel observer in the Coordinator.

The one subtlety is that TextKit 2 uses lazy layout, so fragments outside the viewport may not be laid out yet. The codebase handles this via `reconcileLayoutThroughViewport()` which forces `.ensuresLayout` enumeration from the document start through the visible range. For scroll-spy, we only need the y-position of headings that are near the viewport top, which will always be in the laid-out region.

## Evidence

From `OverlayCoordinator+TableOverlays.swift:363-401` -- the `boundingRect(for:context:)` method maps a text range to a `CGRect`:
```swift
private func boundingRect(
    for tableRangeID: String,
    context: LayoutContext
) -> CGRect? {
    guard let tableRange = findTableTextRange(for: tableRangeID),
          tableRange.length > 0 else { return nil }

    let docStart = context.contentManager.documentRange.location
    guard let startLoc = context.contentManager.location(
        docStart, offsetBy: tableRange.location
    ),
        let endLoc = context.contentManager.location(
            docStart, offsetBy: NSMaxRange(tableRange)
        )
    else { return nil }

    var result: CGRect?
    context.layoutManager.enumerateTextLayoutFragments(
        from: startLoc, options: [.ensuresLayout]
    ) { fragment in
        let fragStart = fragment.rangeInElement.location
        guard fragStart.compare(endLoc) == .orderedAscending else { return false }
        let frame = fragment.layoutFragmentFrame
        if let existing = result {
            result = existing.union(frame)
        } else {
            result = frame
        }
        return true
    }

    guard let rect = result, rect.height > 1 else { return nil }
    return rect
}
```

From `OverlayCoordinator+Positioning.swift:134-155` -- attachment positioning uses the same fragment enumeration:
```swift
context.layoutManager.enumerateTextLayoutFragments(
    from: docLocation, options: [.ensuresLayout]
) { fragment in
    fragmentFrame = fragment.layoutFragmentFrame
    return false
}
```

From `OverlayCoordinator+Observation.swift:21-35` -- scroll observation via `boundsDidChangeNotification`:
```swift
func observeScrollChanges(on textView: NSTextView) {
    guard scrollObserver == nil,
          let clipView = textView.enclosingScrollView?.contentView
    else { return }
    clipView.postsBoundsChangedNotifications = true
    scrollObserver = NotificationCenter.default.addObserver(
        forName: NSView.boundsDidChangeNotification,
        object: clipView, queue: .main
    ) { [weak self] _ in
        Task { @MainActor [weak self] in
            self?.handleScrollBoundsChange()
        }
    }
}
```

From `SelectableTextView.swift:119` -- the text view is created with TextKit 2:
```swift
let layoutManager = NSTextLayoutManager()
layoutManager.textContainer = textContainer
let contentStorage = NSTextContentStorage()
contentStorage.addTextLayoutManager(layoutManager)
```

## Implementation Note for Scroll-Spy

The scroll-spy needs to map the viewport's `bounds.origin.y` to the "current heading." The approach:

1. On `boundsDidChangeNotification`, read `clipView.bounds.origin.y` (viewport top).
2. For each heading, find its character range in the attributed string and use `enumerateTextLayoutFragments` to get its `layoutFragmentFrame.origin.y`.
3. The current heading is the last heading whose y-position is at or above the viewport top.

The heading character ranges are not currently tracked during `MarkdownTextStorageBuilder.build()`, but they could be added by recording `result.length` before each `appendHeading` call. Alternatively, headings can be found by searching the text storage for heading font attributes or by maintaining a side table of `[blockIndex: NSRange]` during the build step.
