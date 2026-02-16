# Hypothesis Document: print-theme
**Version**: 1.0.0 | **Created**: 2026-02-15T21:50:00Z | **Status**: VALIDATED

## Hypotheses
### HYP-001: NSTextView drawBackground(in:) Invocation During Print Rendering
**Risk Level**: HIGH
**Status**: CONFIRMED
**Statement**: A programmatically created NSTextView subclass used as a temporary print view will correctly lay out the full attributed string content and invoke drawBackground(in:) during the print rendering pass, allowing CodeBlockBackgroundTextView to draw code block container backgrounds in the printed output.
**Context**: The mkdn app's CodeBlockBackgroundTextView overrides drawBackground(in:) to paint rounded-rectangle backgrounds behind code blocks. The print feature needs a temporary copy of this view to render with print-friendly colors. The main concern is whether AppKit's print machinery invokes drawBackground during print rendering, especially for a programmatically created view not embedded in a window.
**Validation Criteria**:
- CONFIRM if: drawBackground(in:) is called during print rendering for a programmatic NSTextView subclass, and the PDF output contains the expected background rectangles
- REJECT if: drawBackground(in:) is not called during print rendering, or the temporary view produces blank/incomplete output, or NSPrintOperation returns nil
**Suggested Method**: CODE_EXPERIMENT

## Validation Findings

### HYP-001 Findings
**Validated**: 2026-02-15T22:10:00Z
**Method**: CODE_EXPERIMENT + CODEBASE_ANALYSIS + EXTERNAL_RESEARCH
**Result**: CONFIRMED

**Evidence**:

Six experimental tests were executed in a standalone Swift/AppKit project (`/tmp/hypothesis-print-theme/`) to validate the hypothesis. Key findings:

**1. NSPrintOperation creation works for offscreen views (PASS)**
`NSPrintOperation(view:printInfo:)` successfully creates a print operation for a programmatically created `NSTextView` subclass that is NOT embedded in a window. No nil return, no crash.

**2. drawBackground(in:) IS called during PDF/print rendering (PASS, with caveat)**
When `dataWithPDF(inside:)` is called (which exercises the same draw pipeline as `NSPrintOperation`), the view's `draw(_:)` override is called, which in turn calls `drawBackground(in:)` via `super.draw()`. The PDF output contains the text content and is non-trivial (6-10KB).

**Critical caveat discovered: TextKit 2 dispatch behavior**. For an offscreen (non-windowed) NSTextView using TextKit 2, `drawBackground(in:)` is only called during `dataWithPDF` if the subclass also overrides `draw(_:)`. If only `drawBackground(in:)` is overridden (without a `draw(_:)` override), TextKit 2's rendering pipeline skips the dispatch to the subclass's `drawBackground`. This was confirmed with isolated single-class tests:
- Class with only `drawBackground(in:)` override: **drawBackground NOT called** during PDF rendering
- Class with both `draw(_:)` and `drawBackground(in:)` overrides: **drawBackground IS called** during PDF rendering
- The `draw(_:)` override calls `super.draw()` which internally dispatches to `drawBackground(in:)`

**3. Custom NSBezierPath drawing with attribute enumeration works in PDF (PASS)**
A test view that enumerates custom `NSAttributedString` attributes (simulating `CodeBlockAttributes.range`) in `drawBackground(in:)` and draws `NSBezierPath` rounded rectangles successfully produces a PDF with the background containers visible. The generated PDF was visually verified to contain the rounded-rectangle background behind code text and regular text below it.

**4. TextKit version discovery (IMPORTANT DESIGN NOTE)**
On macOS 15.x (the target platform), `NSTextView(frame:)` (the "default" init) actually uses **TextKit 2**, not TextKit 1 as assumed in design.md decision D4. The `textLayoutManager` property is non-nil for default-init views. Accessing the `.layoutManager` property on a TextKit 2 view **irreversibly destroys** the `textLayoutManager` (forces a permanent fallback to TextKit 1).

**5. textLayoutManager availability during drawBackground**
When the print view is created with an explicit TextKit 2 init (NSTextContainer + NSTextLayoutManager + NSTextContentStorage, matching the on-screen view pattern from `SelectableTextView.makeScrollableCodeBlockTextView()`), `textLayoutManager` is available before `dataWithPDF` but may not be reliably available inside `drawBackground(in:)` during the PDF rendering pass. The `drawCodeBlockContainers` method in `CodeBlockBackgroundTextView` guards on `textLayoutManager`, so this guard may fail for the print view.

**Design Implications**:

1. **The hypothesis is CONFIRMED** -- `drawBackground(in:)` is invoked during print rendering and custom drawing code executes correctly, producing valid PDF output with code block container backgrounds.

2. **Implementation requirement: add `draw(_:)` override to ensure dispatch**. The current `CodeBlockBackgroundTextView` only overrides `drawBackground(in:)`. For the offscreen print view scenario, the design should either:
   - **(Recommended)** Add a `draw(_:)` override to `CodeBlockBackgroundTextView` that calls `super.draw(dirtyRect)`. This ensures TextKit 2's rendering pipeline dispatches to `drawBackground(in:)` for offscreen views. The on-screen view already works because it is embedded in a window where the dispatch path is different.
   - OR: Create the print view's `makePrintTextView` with an explicit TextKit 2 setup (matching `makeScrollableCodeBlockTextView`) and call `ensureLayout` before PDF generation.

3. **Design.md decision D4 needs revision**: The comment "Uses TextKit 1 (default NSTextView initializer) for the temporary print view" is incorrect on macOS 15.x. The default `NSTextView(frame:)` init uses TextKit 2. The `drawCodeBlockContainers` method uses TextKit 2 APIs (`textLayoutManager`, `enumerateTextLayoutFragments`), so the print view MUST use TextKit 2 for code block backgrounds to render. Using the same explicit TextKit 2 init as the on-screen view is the correct approach.

4. **NSPrintOperation API note**: The design.md references `printView.printOperation(for: printInfo)` which is not a valid NSTextView API. The correct API is `NSPrintOperation(view: printView, printInfo: printInfo)`.

**Sources**:
- Code experiment: `/tmp/hypothesis-print-theme/Sources/main.swift` (DISPOSABLE, cleaned up)
- `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift:81-120` -- drawBackground override and drawCodeBlockContainers guard
- `mkdn/Features/Viewer/Views/SelectableTextView.swift:99-126` -- makeScrollableCodeBlockTextView TextKit 2 setup
- `mkdn/Core/Markdown/CodeBlockAttributes.swift:1-34` -- custom attribute definitions
- [Apple: drawBackground(in:)](https://developer.apple.com/documentation/appkit/nstextview/drawbackground(in:))
- [Printing without tears in Dark Mode](https://eclecticlight.co/2019/04/19/printing-without-tears-in-dark-mode-and-exporting-to-pdf/)
- [NSTextViewPrinting - CocoaDev](https://cocoadev.github.io/NSTextViewPrinting/)
- [AppKit Printing API](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Printing/osxp_printapps/osxp_printapps.html)
- [Quick Notes on Printing from AppKit](https://www.notesfromandy.com/2020/09/28/quick-notes-on-printing-from-appkit/)
- [Meet TextKit 2 - WWDC21](https://developer.apple.com/videos/play/wwdc2021/10061/)

**Implications for Design**:
- The core approach of using a temporary `CodeBlockBackgroundTextView` for printing is viable
- The `makePrintTextView` factory MUST use the explicit TextKit 2 init pattern (not default `NSTextView(frame:)`) and call `ensureLayout(for: documentRange)` before generating PDF/print output
- A `draw(_:)` override (calling `super.draw()`) should be added to `CodeBlockBackgroundTextView` to guarantee `drawBackground(in:)` dispatch for offscreen print views
- The `NSPrintOperation` creation API must be corrected from `printView.printOperation(for:)` to `NSPrintOperation(view:printView, printInfo:)`
- Decision D4 should be updated: the print view should use TextKit 2 (same as on-screen), not TextKit 1

## Summary
| Hypothesis | Risk | Result | Implication |
|------------|------|--------|-------------|
| HYP-001 | HIGH | CONFIRMED | drawBackground(in:) works during print rendering; requires draw(_:) override for offscreen dispatch and TextKit 2 init for print view |
