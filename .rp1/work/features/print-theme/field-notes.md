# Field Notes: print-theme

## FN-1: Design Deviations from HYP-001 Validation

The hypothesis tester (HYP-001) validated the print approach and found three corrections needed to the design document:

### Correct AppKit print method: `printView(_:)` not `print(_:)`

The design document specifies overriding `print(_:)` but this is not an overridable method on NSView/NSTextView. The correct AppKit method is `printView(_ sender: Any?)` which is the standard NSView print action method. Swift's `print()` function name collision makes this easy to confuse.

### TextKit 2 required for print clone (D4 revision)

Design decision D4 specified TextKit 1 for the temporary print view. This is incorrect:

1. On macOS 15.x, `NSTextView(frame:)` actually uses TextKit 2 (not TextKit 1 as documented)
2. `CodeBlockBackgroundTextView.drawCodeBlockContainers` uses TextKit 2 APIs (`textLayoutManager`, `enumerateTextLayoutFragments`)
3. Accessing the `.layoutManager` property on a TextKit 2 view **irreversibly destroys** the `textLayoutManager`
4. The print clone MUST use the same explicit TextKit 2 init pattern as `SelectableTextView.makeScrollableCodeBlockTextView()`

### `draw(_:)` override required for offscreen dispatch

For offscreen (non-windowed) NSTextView instances using TextKit 2, `drawBackground(in:)` is only called during print/PDF rendering if the subclass also overrides `draw(_:)`. Without the override, TextKit 2's rendering pipeline skips the dispatch. A `draw(_:)` that simply calls `super.draw(dirtyRect)` is sufficient.

### Correct NSPrintOperation API

The design references `printView.printOperation(for: printInfo)` which is not a valid NSTextView API. The correct API is `NSPrintOperation(view: printView, printInfo: printInfo)`.

## FN-2: ensureLayout Required Before Print

After setting the attributed string on the TextKit 2 print clone view, `ensureLayout(for: documentRange)` must be called on the `NSTextLayoutManager` before the print operation generates pages. Without this, the layout may be incomplete for offscreen views.
