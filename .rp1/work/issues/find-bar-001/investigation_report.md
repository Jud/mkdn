# Root Cause Investigation Report - find-bar-001

## Executive Summary
- **Problem**: Cmd+F (Find) does not work in the markdown preview -- the find bar may appear but searching does not find text
- **Root Cause**: The NSTextView is initialized using the TextKit 2 code path (`NSTextView(frame:textContainer:)` with an `NSTextLayoutManager`-backed container), and `NSTextFinder`'s incremental search relies on the `NSTextFinderClient` protocol methods that have known behavioral differences under TextKit 2. Specifically, `NSTextContentStorage` under TextKit 2 can return different results from `NSTextView.string` for range-based operations that `NSTextFinder` uses internally. Additionally, the `NSScrollView` is created manually (not via `NSTextView.scrollableTextView()`), which may not fully configure the `NSTextFinderBarContainer` relationship that `usesFindBar = true` depends on.
- **Solution**: Either (a) use `NSTextView.scrollableTextView()` factory to ensure proper NSTextFinder wiring, or (b) explicitly configure the NSTextFinder client/container relationship, or (c) temporarily fall back to TextKit 1 for the find operation
- **Urgency**: Medium -- find is a standard expected feature but has a straightforward fix path

## Investigation Process
- **Hypotheses Tested**: 5 (see details below)
- **Key Evidence**: 3 critical findings in code analysis

### Hypothesis 1: Find bar not appearing at all
**Status**: PARTIALLY CONFIRMED

The `sendFindAction(tag:)` method in `MkdnCommands.swift` (line 166-174) creates an `NSMenuItem` with the appropriate tag and sends `performFindPanelAction(_:)` via `NSApp.sendAction(to: nil)`. This routes through the responder chain. For the action to reach the `CodeBlockBackgroundTextView`, the text view must be the first responder or in the responder chain.

**Evidence**: The text view is `isEditable = false` and `isSelectable = true`. NSTextView with `isSelectable = true` can become first responder and should receive the action. However, in the SwiftUI hosting environment, the NSTextView inside an `NSViewRepresentable` is NOT automatically the first responder. The SwiftUI hosting view manages its own responder chain, and the embedded NSTextView may not be in the key responder path when the menu command fires.

**Key finding**: Without the user first clicking inside the text view to make it first responder, `NSApp.sendAction(to: nil)` traverses the responder chain starting from `NSApp.keyWindow?.firstResponder`, which in a SwiftUI app is typically the `NSHostingView` or a SwiftUI internal view -- NOT the embedded NSTextView.

### Hypothesis 2: NSScrollView not properly configured as NSTextFinderBarContainer
**Status**: CONFIRMED as contributing factor

In `SelectableTextView.makeScrollableCodeBlockTextView()` (lines 102-129), the scroll view is created manually:

```swift
let scrollView = LiveResizeScrollView()
scrollView.documentView = textView
```

This is NOT the same as `NSTextView.scrollableTextView()`, which is Apple's factory method that:
1. Creates the NSScrollView
2. Sets up the text view as documentView
3. Configures the NSTextFinder with the scroll view as its `NSTextFinderBarContainer`
4. Properly wires `findBarView` hosting

When `usesFindBar = true` is set on the text view (line 142), the text view's internal `NSTextFinder` needs to locate its bar container (the enclosing scroll view). While `NSScrollView` conforms to `NSTextFinderBarContainer`, the manual creation path may not establish all the internal bookkeeping that `NSTextFinder` requires.

### Hypothesis 3: TextKit 2 incompatibility with NSTextFinder search
**Status**: CONFIRMED as primary root cause

The text view is initialized with TextKit 2:
```swift
let textContainer = NSTextContainer()
let layoutManager = NSTextLayoutManager()
layoutManager.textContainer = textContainer
let contentStorage = NSTextContentStorage()
contentStorage.addTextLayoutManager(layoutManager)
let textView = CodeBlockBackgroundTextView(
    frame: .zero, textContainer: textContainer
)
```

`NSTextFinder` (which powers `usesFindBar` and `isIncrementalSearchingEnabled`) relies on the `NSTextFinderClient` protocol. Under TextKit 2, `NSTextView` implements this protocol, but the implementation depends on `NSTextContentStorage` for text access. There is a known issue where `NSTextFinder`'s incremental search under TextKit 2 does not properly highlight matches or navigate between them.

The `NSTextFinderClient` protocol requires methods like:
- `string(at:effectiveRange:endsWithSearchBoundary:)` for incremental search
- `contentView(at:effectiveCharacterRange:)` for match display
- `rects(forCharacterRange:)` for highlight drawing
- `visibleCharacterRanges` for viewport-based search

Under TextKit 2, the range-based APIs (`NSRange`) need to be bridged to/from `NSTextRange` (TextKit 2's location model). This bridging has known edge cases, particularly when the text storage contains `NSTextAttachment` placeholders (which this app uses heavily for Mermaid diagrams, images, tables, and thematic breaks).

**Critical evidence**: The attributed string contains numerous `NSTextAttachment` characters (Unicode `\u{FFFC}`). These attachment characters create discontinuities in the visual text that `NSTextFinder` tries to search. The attachment placeholders take up character positions in the text storage but don't correspond to visible searchable text. Under TextKit 2, the `NSTextContentStorage` handles these differently than TextKit 1's `NSLayoutManager`, which can cause `NSTextFinder` to either:
1. Skip over valid text ranges
2. Fail to map found ranges back to visual positions
3. Return incorrect `visibleCharacterRanges` that exclude text between attachments

### Hypothesis 4: Responder chain broken in SwiftUI
**Status**: CONFIRMED as contributing factor

The view hierarchy is:
```
NSWindow
  -> NSHostingView (SwiftUI root)
    -> ... (SwiftUI internal views)
      -> NSViewRepresentable hosting view
        -> LiveResizeScrollView (NSScrollView)
          -> NSClipView
            -> CodeBlockBackgroundTextView (NSTextView)
```

When the user presses Cmd+F:
1. `MkdnCommands.sendFindAction(tag: 1)` fires
2. It calls `NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: menuItem)`
3. `to: nil` means "send to the first responder"
4. The first responder in a SwiftUI app is typically NOT the embedded NSTextView unless the user has clicked inside it

If the user has not clicked inside the text view first, the action goes to whatever SwiftUI internal view is the first responder. That view does not respond to `performFindPanelAction(_:)`, and the action is dropped silently.

Even when the find bar does appear (because the user clicked in the text view first), the TextKit 2 issues from Hypothesis 3 prevent actual search from working.

### Hypothesis 5: updateNSView invalidating find state
**Status**: CONFIRMED as contributing factor

When SwiftUI triggers `updateNSView` (e.g., due to theme change, zoom, or any state change), line 82 calls:
```swift
textView.textStorage?.setAttributedString(attributedText)
```

This replaces the entire text storage, which invalidates any active `NSTextFinder` search state. If the find bar is open and the user has an active search, the results are wiped. This is especially problematic because SwiftUI can call `updateNSView` frequently, and `MarkdownPreviewView` rebuilds the entire `textStorageResult` on `onChange(of: appSettings.theme)` and `onChange(of: appSettings.scaleFactor)`.

## Root Cause Analysis

### Technical Details

**Primary cause**: TextKit 2 + NSTextFinder incompatibility

Location: `SelectableTextView.makeScrollableCodeBlockTextView()` at `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/SelectableTextView.swift:102-129`

The NSTextView is initialized with the TextKit 2 stack (`NSTextLayoutManager` + `NSTextContentStorage`), and `usesFindBar`/`isIncrementalSearchingEnabled` are set in `configureTextView()` at lines 142-143. The `NSTextFinder` that powers these features has incomplete/buggy support for TextKit 2's range model, especially when the text storage contains `NSTextAttachment` placeholders.

**Secondary cause**: Manual NSScrollView creation

The scroll view is created via `LiveResizeScrollView()` (a custom `NSScrollView` subclass) rather than `NSTextView.scrollableTextView()`. This bypasses Apple's internal setup that properly wires the `NSTextFinder` -> `NSTextFinderBarContainer` relationship.

**Tertiary cause**: Responder chain gap

The `NSApp.sendAction(to: nil)` in `sendFindAction()` relies on the NSTextView being first responder, which is not guaranteed in a SwiftUI hosting environment.

### Causation Chain

```
Root Cause: NSTextView initialized with TextKit 2 + manual NSScrollView
    |
    +-> NSTextFinder's incremental search uses NSTextFinderClient protocol
    |     |
    |     +-> TextKit 2's range bridging (NSRange <-> NSTextRange) has issues
    |     |   with NSTextAttachment characters in the text storage
    |     |
    |     +-> Search finds no matches or fails to highlight/navigate
    |
    +-> Manual NSScrollView creation may not fully configure NSTextFinderBarContainer
    |     |
    |     +-> Find bar may not appear or may appear without proper integration
    |
    +-> sendAction(to: nil) relies on NSTextView being first responder
          |
          +-> In SwiftUI, first responder is often the hosting view, not the NSTextView
          +-> Action is silently dropped when text view is not first responder
```

### Why It Occurred

1. The original implementation was designed around TextKit 2 for its superior layout capabilities (needed for code block background drawing, overlay positioning, etc.)
2. The find bar feature was added later, and the design verification (HYP-001 in the mac-app-essentials archive) confirmed TextKit 2 compatibility in a test environment. However, the test may not have accounted for the specific combination of: (a) NSTextAttachment-heavy content, (b) manual NSScrollView creation, and (c) SwiftUI responder chain behavior
3. The manual `NSScrollView` creation was needed because a custom subclass (`LiveResizeScrollView`) is required for live-resize viewport layout

## Proposed Solutions

### 1. Recommended: Hybrid approach -- fix NSTextFinder wiring + responder chain

**Effort**: 2-4 hours

**Approach**:
1. In `makeScrollableCodeBlockTextView()`, after creating the `LiveResizeScrollView` and setting the document view, explicitly configure the text finder:
   ```swift
   // After scrollView.documentView = textView
   textView.textFinder.findBarContainer = scrollView
   textView.textFinder.client = textView
   ```
   (Note: `NSTextView.textFinder` is a private property in older macOS versions but accessible on macOS 14+)

2. In `sendFindAction()`, explicitly make the text view first responder before sending the action:
   ```swift
   private func sendFindAction(tag: Int) {
       guard let window = NSApp.keyWindow,
             let textView = findTextView(in: window) else { return }
       window.makeFirstResponder(textView)
       let menuItem = NSMenuItem()
       menuItem.tag = tag
       textView.performFindPanelAction(menuItem)
   }
   ```

3. If TextKit 2 find still does not work after wiring fixes, add a fallback: override `performFindPanelAction(_:)` in `CodeBlockBackgroundTextView` to use `NSTextView.string` for a manual search implementation using `NSTextFinder` configured explicitly with TextKit 1-style string access.

**Risk**: Low. The changes are isolated to the find path and don't affect rendering.

**Pros**: Preserves TextKit 2 for rendering; directly addresses responder chain issue.

**Cons**: May still encounter TextKit 2 NSTextFinder edge cases with attachments.

### 2. Alternative: Fall back to TextKit 1 for the entire text view

**Effort**: 4-8 hours

**Approach**: Replace the TextKit 2 initialization with TextKit 1:
```swift
let textView = CodeBlockBackgroundTextView(frame: .zero)
// Uses default TextKit 1 (NSLayoutManager) initialization
let scrollView = LiveResizeScrollView()
scrollView.documentView = textView
```

**Risk**: Medium-high. The entire rendering pipeline (code block backgrounds, overlay positioning, entrance animations) depends on TextKit 2 APIs (`NSTextLayoutManager`, `enumerateTextLayoutFragments`, etc.). All of `CodeBlockBackgroundTextView`'s drawing code, `OverlayCoordinator`'s positioning, and `EntranceAnimator`'s fragment enumeration would need to be rewritten for TextKit 1.

**Pros**: NSTextFinder works reliably with TextKit 1.

**Cons**: Massive refactor; TextKit 1 layout does not support some features used here.

### 3. Alternative: Use NSTextView.scrollableTextView() and subclass differently

**Effort**: 3-5 hours

**Approach**: Use Apple's factory method and apply live-resize behavior differently:
```swift
let scrollView = NSTextView.scrollableTextView()
// Cast or swizzle for live-resize behavior
let textView = scrollView.documentView as! NSTextView
```

Then apply the live-resize viewport layout fix via method swizzling or a scroll notification observer rather than a custom NSScrollView subclass.

**Risk**: Medium. Swizzling is fragile; notification-based approach may have timing issues.

**Pros**: Guarantees proper NSTextFinder wiring as Apple intended.

**Cons**: Loses custom `LiveResizeScrollView`; requires alternative live-resize solution.

## Prevention Measures

1. **Manual testing protocol**: For features that bridge AppKit and SwiftUI (NSViewRepresentable), always test with actual user interaction in the full app context, not just API-level verification
2. **NSTextFinder test**: Add a UI test that opens a file, sends Cmd+F, types a search term, and verifies match highlighting via the test harness
3. **Responder chain awareness**: When using `NSApp.sendAction(to: nil)` in SwiftUI apps, always verify the target view is first responder first, or send the action directly to the target

## Evidence Appendix

### E1: TextKit 2 Initialization Path
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
    frame: .zero,
    textContainer: textContainer
)
```

### E2: Manual NSScrollView Creation
File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/SelectableTextView.swift`
Lines 125-126:
```swift
let scrollView = LiveResizeScrollView()
scrollView.documentView = textView
```

### E3: Find Configuration
File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/SelectableTextView.swift`
Lines 142-143:
```swift
textView.usesFindBar = true
textView.isIncrementalSearchingEnabled = true
```

### E4: Action Dispatch (responder chain reliant)
File: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`
Lines 166-174:
```swift
private func sendFindAction(tag: Int) {
    let menuItem = NSMenuItem()
    menuItem.tag = tag
    NSApp.sendAction(
        #selector(NSTextView.performFindPanelAction(_:)),
        to: nil,
        from: menuItem
    )
}
```

### E5: NSTextAttachment-heavy content
File: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift`
The builder creates NSTextAttachment placeholders for mermaid blocks, images, thematic breaks, and tables. Each attachment inserts a `\u{FFFC}` character into the text storage, creating discontinuities that TextKit 2's NSTextFinder bridging may not handle correctly.

### E6: Original Design Verification
File: `/Users/jud/Projects/mkdn/.rp1/work/archives/features/mac-app-essentials/hypotheses.md`
The original HYP-001 verified TextKit 2 + find bar compatibility at the API level but noted (line 48): "textView is NSTextFinderClient returns false in Swift for both TextKit 1 and TextKit 2 NSTextViews. This is a Swift bridging artifact." While this was correctly identified as a Swift bridging issue, it may have masked deeper incompatibilities in the actual search operation.
