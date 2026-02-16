# Root Cause Investigation Report - print-no-content

## Executive Summary
- **Problem**: Cmd+P shows the macOS print dialog but the printed output contains no text content
- **Root Cause**: Two independent issues -- (1) the responder chain does not reliably route `printView(_:)` to the `CodeBlockBackgroundTextView` override, and (2) the off-screen TextKit 2 clone view does not render text content during the print draw pass because it lacks a window/viewport context
- **Solution**: Print from the on-screen text view using `NSPrintOperation.run()` directly (bypassing clone approach), or use the on-screen text view's `printView(_:)` with a TextKit 1 clone
- **Urgency**: Medium -- printing is non-functional

## Investigation Process
- **Hypotheses Tested**: 6 (4 confirmed, 2 rejected)
- **Key Evidence**: 3 pieces (responder chain analysis, TextKit 2 off-screen draw test, NSTextView pagination crash test)

### Hypothesis Results

| # | Hypothesis | Result |
|---|-----------|--------|
| H1 | `printView(_:)` not called on CodeBlockBackgroundTextView | **CONFIRMED** -- depends on first responder state |
| H2 | Responder chain routes to wrong view | **CONFIRMED** -- `sendAction(to: nil)` uses first responder |
| H3 | `printBlocks` is empty at print time | **REJECTED** -- set in both `makeNSView` and `updateNSView` |
| H4 | Clone view TextKit 2 stack is misconfigured | **REJECTED** -- textStorage is populated correctly |
| H5 | Off-screen TextKit 2 view does not render during draw | **CONFIRMED** -- no text rendered into bitmap |
| H6 | NSPrintOperation pagination fails on non-windowed view | **CONFIRMED** -- `knowsPageRange` crashes without print context |

## Root Cause Analysis

### Cause 1: Responder Chain Miss (Primary)

**Location**: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`, lines 91-98

```swift
Button("Print...") {
    NSApp.sendAction(
        #selector(NSView.printView(_:)),
        to: nil,
        from: nil
    )
}
```

**Technical Details**:

`NSApp.sendAction(_:to:from:)` with `to: nil` dispatches to the **first responder** and walks up the responder chain. Every `NSView` responds to `printView(_:)` (it is defined on `NSView`), so the first `NSView` in the chain handles it.

The `CodeBlockBackgroundTextView` only becomes first responder when the user **clicks** in the text area (it is `isSelectable = true`). If the user opens a document and presses Cmd+P without clicking in the text view, the first responder is a SwiftUI infrastructure view (e.g., `NSHostingView` or a focus clip view). That view's base `NSView.printView(_:)` creates an `NSPrintOperation(view: self)` for itself, which renders the SwiftUI view hierarchy in the current theme colors (Solarized Dark/Light), not the print-friendly palette.

**Responder chain in this app**:

```
NSWindow
  -> NSHostingView (first responder if user hasn't clicked text)
    -> SwiftUI internal views
      -> NSViewRepresentableAdaptor
        -> LiveResizeScrollView (NSScrollView)
          -> NSClipView
            -> CodeBlockBackgroundTextView (first responder only if user clicked here)
```

The action travels UP from the first responder. It never traverses DOWN into subviews. So the custom `printView(_:)` override on `CodeBlockBackgroundTextView` is only reached when that view IS the first responder.

**Why It Occurred**: The `sendAction(to: nil)` pattern relies on the implicit assumption that the target view is the first responder. No explicit first responder management ensures the text view is focused before printing.

### Cause 2: TextKit 2 Off-Screen Draw Failure (Secondary)

**Location**: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift`, lines 302-336 (`makePrintTextView`)

**Technical Details**:

Even when `printView(_:)` IS called on the `CodeBlockBackgroundTextView` (user clicked in text area), the clone view approach fails because TextKit 2's viewport layout controller requires a viewport context (tied to an `NSScrollView`'s visible rect or a window) to determine which text layout fragments to render during `draw(_:)`.

The clone view is created off-screen with no window and no scroll view:

```swift
let textView = CodeBlockBackgroundTextView(
    frame: NSRect(origin: .zero, size: size),
    textContainer: textContainer
)
// ... no window, no scroll view
textView.textStorage?.setAttributedString(attributedString)
```

Despite `ensureLayout(for: documentRange)` being called (line 331), the text layout fragments are not rendered into the graphics context during `draw(_:)` because the viewport layout controller has no viewport bounds to consult. The view draws its background (white fill from `drawsBackground = true`) but no text glyphs.

**Evidence**: Direct testing with a TextKit 2 NSTextView created off-screen, populated with attributed text, and drawn into a bitmap rep produced **zero non-white pixels** in the text area. The text storage was confirmed to contain the content (length 22), but draw produced only the background fill.

**Causation Chain**:

```
printView(_:) called on CodeBlockBackgroundTextView
  -> MarkdownTextStorageBuilder.build() produces attributed string (OK)
  -> makePrintTextView creates clone with TextKit 2 (OK)
  -> textStorage.setAttributedString() populates content (OK)
  -> ensureLayout() forces layout computation (OK)
  -> NSPrintOperation(view: cloneView).run() starts print job
    -> NSPrintOperation calls draw(_:) on clone view
      -> TextKit 2 viewport layout controller has no viewport
        -> No text layout fragments are drawn
          -> White pages produced
```

## Proposed Solutions

### Solution 1: Print the On-Screen View Directly (Recommended)

**Approach**: Instead of creating a clone view, call `super.printView(sender)` on the on-screen `CodeBlockBackgroundTextView` itself. NSTextView has built-in printing support that works correctly for windowed views.

**Trade-off**: This prints in the current theme colors (Solarized Dark/Light), not the print-friendly palette. The print palette feature would be lost.

**Effort**: Minimal -- remove the clone approach and always call `super.printView(sender)`.

**Risk**: Low. But dark theme printing produces dark backgrounds which wastes ink.

### Solution 2: Temporarily Swap Attributed String for Print (Recommended)

**Approach**: Instead of creating a clone view, temporarily replace the on-screen text view's attributed string with the print-palette version, call `super.printView(sender)`, then restore the original attributed string.

```swift
override func printView(_ sender: Any?) {
    guard !printBlocks.isEmpty else {
        super.printView(sender)
        return
    }

    let original = textStorage?.copy() as? NSAttributedString
    let result = MarkdownTextStorageBuilder.build(
        blocks: printBlocks,
        colors: PrintPalette.colors,
        syntaxColors: PrintPalette.syntaxColors
    )

    let savedBg = backgroundColor
    backgroundColor = .white
    textStorage?.setAttributedString(result.attributedString)

    super.printView(sender)

    // Restore after print dialog closes
    if let original { textStorage?.setAttributedString(original) }
    backgroundColor = savedBg
}
```

**Trade-off**: Brief visual flash as the on-screen view temporarily shows print colors. This can be mitigated by running the swap/restore within a `CATransaction.setDisableActions(true)` block.

**Effort**: Low -- modify `printView(_:)` only.

**Risk**: Medium -- `super.printView(sender)` runs the print operation synchronously (modally), so the restore happens after the dialog closes. The user sees the print-palette content while the dialog is open.

### Solution 3: Fix the Responder Chain + Use TextKit 1 Clone (Best)

**Approach**: Two-part fix:

1. **Fix responder chain**: Change `MkdnCommands` to explicitly target the `CodeBlockBackgroundTextView` instead of relying on the first responder. Use `NSApp.keyWindow?.contentView` to find the text view and call `printView(_:)` directly:

```swift
Button("Print...") {
    if let textView = findCodeBlockTextView(in: NSApp.keyWindow) {
        textView.printView(nil)
    }
}
```

2. **Use TextKit 1 for the clone**: Replace the TextKit 2 clone setup with TextKit 1, which does not have the viewport-dependent rendering issue:

```swift
private static func makePrintTextView(
    attributedString: NSAttributedString,
    size: NSSize
) -> NSTextView {
    // TextKit 1 -- no viewport dependency for off-screen rendering
    let textView = NSTextView(frame: NSRect(origin: .zero, size: size))
    textView.isEditable = false
    textView.drawsBackground = true
    textView.backgroundColor = .white
    textView.textContainerInset = NSSize(width: 32, height: 32)
    textView.textStorage?.setAttributedString(attributedString)
    textView.layoutManager?.ensureLayout(for: textView.textContainer!)
    textView.sizeToFit()
    return textView
}
```

**Note**: The clone would be a plain `NSTextView` (not `CodeBlockBackgroundTextView`), so code block background containers would NOT be drawn. To preserve code block backgrounds, the clone needs to be a `CodeBlockBackgroundTextView` subclass, but using TextKit 1. Since `drawCodeBlockContainers` relies on TextKit 2 APIs (`textLayoutManager`, `enumerateTextLayoutFragments`), a TextKit 1 fallback path would need to be added.

**Effort**: Medium.

**Risk**: Low -- TextKit 1 off-screen rendering is well-established.

### Solution 4: Use NSPrintOperation on the On-Screen View with Print Palette (Alternative)

**Approach**: Instead of overriding `printView(_:)`, directly create and run `NSPrintOperation(view: self)` from the on-screen text view. Before running, temporarily swap the attributed string to the print palette version (similar to Solution 2).

**Effort**: Low.

**Risk**: Same visual flash trade-off as Solution 2.

## Prevention Measures

1. **Test printing in CI**: Add a test that verifies `printView(_:)` produces non-empty page content. The test harness could capture the print output as PDF and verify it contains text.

2. **Explicit first responder for print**: Always explicitly target the text view for print actions rather than relying on the responder chain. This is a common pattern in macOS apps -- the menu command finds the specific view to print rather than using `sendAction(to: nil)`.

3. **Avoid off-screen TextKit 2 views for drawing**: TextKit 2's viewport layout controller requires a window/viewport context. Any feature that needs off-screen rendering of text should use TextKit 1 or ensure the view is temporarily hosted in a window.

## Evidence Appendix

### E1: Responder Chain Analysis

File: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift`, lines 91-98

```swift
NSApp.sendAction(
    #selector(NSView.printView(_:)),
    to: nil,
    from: nil
)
```

With `to: nil`, dispatches to first responder. No explicit first responder management exists in the codebase (confirmed by grep for `makeFirstResponder`, `becomeFirstResponder`, `firstResponder` -- zero results).

### E2: TextKit 2 Off-Screen Draw Test

A TextKit 2 `NSTextView` created off-screen with `textStorage?.setAttributedString()` populated (confirmed length 22) and `ensureLayout(for: documentRange)` called, when drawn via `draw(_:)` into an `NSBitmapImageRep`, produced **zero non-white pixels**. The viewport layout controller did not render any text layout fragments.

### E3: NSTextView Pagination Crash on Non-Windowed View

Calling `knowsPageRange(_:)` directly on a non-windowed `NSTextView` (both TextKit 1 and TextKit 2) crashes in `_calculatePageRectsWithOperation:pageSize:layoutAssuredComplete:` at offset +816. This crash occurs because the pagination code requires an active `NSPrintOperation` context. When called through `NSPrintOperation.run()`, the operation sets up this context before calling `knowsPageRange`, so the pagination itself works. This confirms the print operation infrastructure is sound, but highlights that the clone view must be correctly configured.

### E4: printBlocks Population Confirmed

File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/SelectableTextView.swift`

- Line 42: `textView.printBlocks = blocks` in `makeNSView`
- Line 72: `textView.printBlocks = blocks` in `updateNSView`

`blocks` comes from `MarkdownPreviewView.renderedBlocks`, populated by `MarkdownRenderer.render()` in the `.task(id:)` modifier. Non-empty for any loaded document.

### E5: Clone View TextStorage Verified

Testing confirmed that `textView.textStorage?.setAttributedString(attributedString)` on a TextKit 2 `NSTextView` clone successfully populates the text storage:

```
textStorage nil? false
textStorage length: 22
NSTextContentStorage textStorage length: 22
```

The content IS in the text storage -- it just does not render during off-screen `draw(_:)`.
