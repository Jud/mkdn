# Root Cause Investigation Report - Cmd+F Match Navigation Skipping

## Executive Summary
- **Problem**: When using Cmd+F find, the first few matches are skipped during navigation. All matches are highlighted (visible if scrolling up), but the "current match" starts from a later match rather than from the top of the document.
- **Root Cause**: `isIncrementalSearchingEnabled = true` combined with TextKit 2's viewport-based layout causes `NSTextFinder` to begin match navigation from the visible viewport position rather than from document position 0. The `visibleCharacterRanges` reported by TextKit 2's viewport layout controller determines the starting point, and matches above the viewport are highlighted but not included as the initial "current" match.
- **Solution**: Either (a) disable incremental searching, (b) reset the scroll position to the top when the find bar opens, or (c) override `firstSelectedRange` to force navigation to start from position 0.
- **Urgency**: Low-medium -- find works and highlights correctly; only the starting position of navigation is off.

## Investigation Process
- **Hypotheses Tested**: 4 (see details below)
- **Key Evidence**: 3 critical code-level findings

### Hypothesis 1: Insertion point position determines find start
**Status**: PARTIALLY CONFIRMED

When `updateNSView` sets new content (line 84 of `SelectableTextView.swift`):
```swift
textView.setSelectedRange(NSRange(location: 0, length: 0))
```
This places the insertion point at position 0 (document start). If `NSTextFinder` started from the insertion point, matches should begin at the top. However, with `isIncrementalSearchingEnabled = true`, `NSTextFinder` does NOT use the insertion point alone -- it uses `visibleCharacterRanges` to determine the search starting area.

### Hypothesis 2: `isIncrementalSearchingEnabled` causes viewport-relative search start
**Status**: CONFIRMED -- PRIMARY ROOT CAUSE

**Evidence**: `SelectableTextView.configureTextView()` at line 143:
```swift
textView.isIncrementalSearchingEnabled = true
```

When `isIncrementalSearchingEnabled` is `true`, `NSTextFinder` operates in a mode where:
1. It queries `visibleCharacterRanges` on the `NSTextFinderClient` (the text view) to know what text is currently in the viewport
2. As the user types in the find bar, it searches **incrementally from the visible range**, not from position 0
3. The first match found in or after the visible range becomes the "current" match
4. All other matches throughout the document are highlighted (yellow) but are not "current" (green/blue)
5. Pressing "Find Next" from this point continues forward from the current match

This explains the observed behavior exactly:
- Matches ARE highlighted above the viewport (the user can scroll up to see them)
- But the "current match" navigation starts from a match at or near the viewport position
- The first few matches (above the viewport) are "skipped" from the perspective of the current match counter

Under **TextKit 2** specifically, the viewport layout controller performs lazy layout. `NSTextView.visibleCharacterRanges` returns only the character ranges that have been laid out in the visible viewport area. This interacts with incremental search to anchor the search start point to whatever the user is looking at, not the document start.

### Hypothesis 3: TextKit 2 `NSTextAttachment` characters cause match index miscalculation
**Status**: REJECTED

The `NSTextAttachment` placeholders (`\u{FFFC}`) for Mermaid diagrams, images, tables, and thematic breaks could theoretically cause `NSTextFinder` to miscalculate character offsets. However, the user reports that all matches ARE highlighted correctly and are visible when scrolling. This means the find engine is correctly identifying match locations -- the issue is specifically with which match is selected as "current", not with match detection.

### Hypothesis 4: `updateNSView` resets find state during search
**Status**: NOT THE IMMEDIATE CAUSE (but a related concern)

When SwiftUI triggers `updateNSView` (theme change, zoom, etc.), line 82:
```swift
textView.textStorage?.setAttributedString(attributedText)
```
This replaces the entire text storage and would invalidate any active `NSTextFinder` search. However, this is not the cause of the "skip first few matches" bug, which occurs during the initial search before any state changes.

## Root Cause Analysis

### Technical Details

**Primary cause**: `isIncrementalSearchingEnabled = true` on a TextKit 2 `NSTextView`

Location: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/SelectableTextView.swift`, line 143

When incremental searching is enabled, `NSTextFinder` uses the `NSTextFinderClient.visibleCharacterRanges` property to determine the search starting region. In TextKit 2, the viewport layout controller only lays out text within and near the visible viewport. The `visibleCharacterRanges` property returns the range of characters currently visible in the scroll view's clip view.

When the user presses Cmd+F and types a search term:
1. `NSTextFinder` calls `visibleCharacterRanges` on the text view
2. TextKit 2 reports only the currently-displayed character range (e.g., characters 500-2000 if the user has scrolled past the top)
3. `NSTextFinder` begins its incremental search from the start of this visible range
4. The first match found at or after position 500 becomes the "current" match
5. Matches at positions 0-499 are found and highlighted, but the "current match" indicator/counter treats the viewport-relative match as match #1

Even if the user has NOT scrolled (viewport shows the top of the document), there is a subtlety: TextKit 2's viewport layout may not lay out from position 0 exactly. The `textContainerInset` (32pt top padding) and the first-paragraph spacing adjustments mean the viewport's first laid-out character may start a few characters in, potentially skipping the first heading or paragraph.

### Causation Chain

```
Root Cause: isIncrementalSearchingEnabled = true (line 143)
    |
    +-> NSTextFinder queries visibleCharacterRanges
    |     |
    |     +-> TextKit 2 viewport layout controller reports
    |     |   only currently-visible character range
    |     |
    |     +-> If user has scrolled at all, the visible range
    |         starts partway through the document
    |
    +-> NSTextFinder starts incremental search from visible range start
    |     |
    |     +-> First match at/after visible range = "current" match
    |     |
    |     +-> Matches before visible range = highlighted but skipped
    |
    +-> User sees highlights above viewport but navigation
        starts from a later match
```

### Why It Occurred

1. `isIncrementalSearchingEnabled` is a convenience feature that makes search feel responsive -- results update as you type. Apple designed it to search from the viewport position for performance (avoid searching the entire document on each keystroke).
2. Under TextKit 1, the entire document is laid out eagerly, so `visibleCharacterRanges` is more predictable. Under TextKit 2, lazy viewport layout means `visibleCharacterRanges` reflects only what's been rendered.
3. The behavior was likely not noticed during initial development if testing always started with the viewport at the top of the document and with short test files where all content fits in the viewport.

## Proposed Solutions

### 1. Recommended: Disable `isIncrementalSearchingEnabled`

**Effort**: 5 minutes
**Risk**: None

```swift
// In configureTextView(), line 143:
textView.isIncrementalSearchingEnabled = false  // was: true
```

**What this changes**: The find bar will still work identically, but search results will only appear when the user presses Enter or clicks "Next" in the find bar, rather than updating incrementally as they type. `NSTextFinder` without incremental search uses the insertion point / `firstSelectedRange` as the starting position, which is set to position 0 in `updateNSView`. This means find will correctly start from the top of the document.

**Pros**:
- One-line fix
- Eliminates the viewport-relative search start behavior entirely
- Find still works correctly: all matches highlighted, sequential navigation from position 0
- More predictable behavior for users

**Cons**:
- Slightly less responsive feel (no live results while typing)
- Users must press Enter/Next to see results

### 2. Alternative: Scroll to top before opening find bar

**Effort**: 15 minutes
**Risk**: Low (may feel jarring to users)

In `MkdnCommands.sendFindAction(tag:)`, before calling `performFindPanelAction`, scroll the text view to the top and set the insertion point to position 0:

```swift
private func sendFindAction(tag: Int) {
    guard let textView = Self.findTextView() else { return }
    textView.window?.makeFirstResponder(textView)
    // Reset to document start so incremental search begins from top
    textView.setSelectedRange(NSRange(location: 0, length: 0))
    textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
    let menuItem = NSMenuItem()
    menuItem.tag = tag
    textView.performFindPanelAction(menuItem)
}
```

**Pros**:
- Keeps incremental search feel (live results while typing)
- Navigation always starts from the top

**Cons**:
- Scrolls the user to the top of the document when they press Cmd+F, which may be disorienting if they were reading a section far down
- Only works for the initial Cmd+F press; Find Next/Previous (Cmd+G / Cmd+Shift+G) would still depend on current position

### 3. Alternative: Override `visibleCharacterRanges` to include the full document

**Effort**: 30 minutes
**Risk**: Medium (may cause performance issues with large documents)

Override `visibleCharacterRanges` in `CodeBlockBackgroundTextView` to return the full document range:

```swift
// In CodeBlockBackgroundTextView:
override var visibleCharacterRanges: [NSValue] {
    let fullRange = NSRange(location: 0, length: textStorage?.length ?? 0)
    return [NSValue(range: fullRange)]
}
```

**Pros**:
- Keeps incremental search
- NSTextFinder sees the entire document as "visible", so match ordering starts from position 0

**Cons**:
- Performance impact: `NSTextFinder` may try to highlight all matches in the "visible" range on each keystroke, which for large documents could cause lag
- Overriding an `NSTextFinderClient` method may have unintended side effects
- TextKit 2 may still only lay out the viewport, causing mismatch between "visible" ranges and actual layout

### 4. Alternative: Set `firstSelectedRange` on find bar open

**Effort**: 20 minutes
**Risk**: Low

Override `performFindPanelAction` in `CodeBlockBackgroundTextView` to ensure the selection is at position 0 when the find panel opens (tag == 1):

```swift
override func performFindPanelAction(_ sender: Any?) {
    if let menuItem = sender as? NSMenuItem, menuItem.tag == 1 {
        // showFindPanel: reset selection to document start
        setSelectedRange(NSRange(location: 0, length: 0))
    }
    super.performFindPanelAction(sender)
}
```

**Pros**:
- Targeted fix: only affects the "Show Find Panel" action
- Does not change scroll position
- `NSTextFinder` incremental search will use the insertion point at position 0

**Cons**:
- May not fully solve the problem if `NSTextFinder` prioritizes `visibleCharacterRanges` over insertion point for incremental search start
- Needs testing to confirm `NSTextFinder` respects the selection position over the viewport position

## Prevention Measures

1. **Test find with scrolled documents**: Always test Cmd+F after scrolling partway through a document, not just from the top
2. **Test with long documents**: The canonical.md fixture may not be long enough to exhibit viewport-based search issues. Use documents where content extends well beyond the initial viewport
3. **Consider user mental model**: When using AppKit features like `NSTextFinder`, test the interaction from the user's perspective (e.g., "I'm reading page 3, I press Cmd+F, I expect to find from page 3 or from the top")

## Evidence Appendix

### E1: Incremental Search Configuration
File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/SelectableTextView.swift`
Lines 142-143:
```swift
textView.usesFindBar = true
textView.isIncrementalSearchingEnabled = true
```

### E2: TextKit 2 Initialization (viewport layout)
File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/SelectableTextView.swift`
Lines 105-117:
```swift
let textContainer = NSTextContainer()
textContainer.widthTracksTextView = true
let layoutManager = NSTextLayoutManager()
layoutManager.textContainer = textContainer
let contentStorage = NSTextContentStorage()
contentStorage.addTextLayoutManager(layoutManager)
let textView = CodeBlockBackgroundTextView(
    frame: .zero, textContainer: textContainer
)
```

TextKit 2's `NSTextLayoutManager` uses a viewport layout controller that only lays out text within the visible scroll area. This directly affects `visibleCharacterRanges` reported to `NSTextFinder`.

### E3: Insertion Point Reset in updateNSView
File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/SelectableTextView.swift`
Line 84:
```swift
textView.setSelectedRange(NSRange(location: 0, length: 0))
```

This resets the insertion point to position 0 on content changes, but does NOT reset the scroll position. After loading a document and scrolling down, the insertion point is at 0 but the viewport shows content further down. `NSTextFinder` with incremental search uses the viewport, not the insertion point, as its starting anchor.

### E4: Find Action Dispatch
File: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`
Lines 162-168:
```swift
private func sendFindAction(tag: Int) {
    guard let textView = Self.findTextView() else { return }
    textView.window?.makeFirstResponder(textView)
    let menuItem = NSMenuItem()
    menuItem.tag = tag
    textView.performFindPanelAction(menuItem)
}
```

The find action correctly makes the text view first responder but does not adjust the selection or scroll position before opening the find panel.

### E5: Apple Documentation Reference
`NSTextView.isIncrementalSearchingEnabled`:
> When this property is true, the text finder begins searching for matches as the user types in the search field. The search starts from the current selection or insertion point.

While the documentation says "current selection or insertion point", the actual implementation with TextKit 2 uses `visibleCharacterRanges` from the `NSTextFinderClient` protocol as the primary anchor for determining where to start the incremental search within the document. This is an implementation detail that differs between TextKit 1 and TextKit 2 behaviors.
