# Root Cause Investigation Report - codeblock-clip-001

## Executive Summary
- **Problem**: Code block backgrounds clip tight against the last line of code text, with no visible bottom padding inside the rounded rectangle.
- **Root Cause**: The uncommitted change moved `blockSpacing` from the last paragraph inside the `CodeBlockAttributes.range` to an external terminator, which correctly moves the inter-block gap outside the background -- but leaves the code block's trailing `\n` paragraph with `paragraphSpacing: 0`, so the layout fragment frame for that paragraph has no bottom breathing room, and `CodeBlockBackgroundTextView` unions those tight frames into a background rectangle that hugs the text baseline.
- **Solution**: Add explicit bottom padding inside the code block's attributed range (independent of the external inter-block spacing), either via `paragraphSpacing` on the trailing `\n` or via a fixed inset in the drawing code.
- **Urgency**: Low-to-medium. Visual polish issue; no functional breakage.

## Investigation Process
- **Duration**: Single session
- **Hypotheses Tested**: 3 (see below)
- **Key Evidence**: (1) The diff shows `paragraphSpacing: 0` on the code block's trailing `\n`, with no compensating internal padding. (2) `CodeBlockBackgroundTextView.fragmentFrames(for:)` unions `layoutFragmentFrame` values, which in TextKit 2 include `paragraphSpacing` in the frame height. (3) The `codeBlockPadding` constant (12pt) is applied as `paragraphSpacingBefore` on the first paragraph but has no counterpart at the bottom.

## Root Cause Analysis

### Technical Details

**The uncommitted change** (visible in `git diff HEAD`):

```diff
-        setLastParagraphSpacing(codeContent, spacing: blockSpacing, baseStyle: codeStyle)
         result.append(codeContent)
+
+        let spacerStyle = makeParagraphStyle(paragraphSpacing: blockSpacing)
+        result.append(terminator(with: spacerStyle))
```

**File**: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`, lines 119-122.

This change correctly moves the 16pt `blockSpacing` out of the `CodeBlockAttributes.range` so that `CodeBlockBackgroundTextView` no longer paints the inter-block gap as part of the code block background. However, it leaves the code block's internal structure with **no bottom padding at all**.

### How the code block's attributed string is structured (current/new code)

```
"swift\n"          -- language label paragraph (spacingBefore: 12, paragraphSpacing: 4, carries CodeBlockAttributes.range)
"let x = 1"       -- code content (paragraphSpacing: 0 from codeStyle, carries CodeBlockAttributes.range)
"\n"               -- trailing newline appended at line 112-117 (paragraphSpacing: 0 from codeStyle, carries CodeBlockAttributes.range)
"\n"               -- external spacer terminator (paragraphSpacing: 16, NO CodeBlockAttributes.range)
```

### How `CodeBlockBackgroundTextView` computes the background rect

1. `collectCodeBlocks(from:)` enumerates `CodeBlockAttributes.range` across the full text storage. It unions all character ranges sharing the same block ID into a single `NSRange`.
2. `fragmentFrames(for:layoutManager:contentManager:)` enumerates TextKit 2 `NSTextLayoutFragment` objects whose start location falls within that `NSRange`, collecting their `layoutFragmentFrame` values.
3. The frames are unioned into a bounding rect, and the background is drawn at full container width with that height.

### TextKit 2 `layoutFragmentFrame` and `paragraphSpacing`

In TextKit 2, a layout fragment corresponds to a paragraph (text between `\n` delimiters). The `layoutFragmentFrame` includes:

- The text line height(s) within the paragraph
- `paragraphSpacingBefore` (added to the top of the fragment)
- `paragraphSpacing` (added to the bottom of the fragment)
- `lineSpacing` between lines within the paragraph (if multi-line)

This is the critical behavior: **`paragraphSpacing` is included in the `layoutFragmentFrame.height`**. When the old code set `paragraphSpacing: 16` on the last paragraph inside the code block, that 16pt was included in the layout fragment frame, and therefore included in the background rect. This served double-duty as both:
1. Internal bottom padding (visual space between last code line and background edge)
2. External gap between the code block background and the next element

The new code sets `paragraphSpacing: 0` on the trailing `\n` (from `codeStyle`), so that fragment's frame is only as tall as the empty line's line height. The background rect therefore ends right at (or just past) the baseline of the last code text line, with no visual bottom padding.

### The top-padding asymmetry confirms the diagnosis

The top of the code block has explicit internal padding via `setFirstParagraphSpacing(codeContent, spacingBefore: spacingBefore)` which sets `paragraphSpacingBefore` on the first code paragraph to either `codeBlockPadding` (12pt, no label) or `codeBlockTopPaddingWithLabel` (8pt, with label). The language label itself gets `paragraphSpacingBefore: codeBlockPadding` (12pt). This `paragraphSpacingBefore` IS included in the fragment frame and therefore in the background rect.

There is no equivalent bottom padding mechanism after the change.

### Causation Chain

```
Root Cause: paragraphSpacing: 0 on last code block paragraph (from codeStyle)
    |
    v
TextKit 2 layoutFragmentFrame for trailing \n has minimal height (just line height of empty line)
    |
    v
CodeBlockBackgroundTextView.fragmentFrames() returns tight frames
    |
    v
Union of frames produces bounding rect with no bottom breathing room
    |
    v
Symptom: Code block background clips tight against last line of text
```

### Why It Occurred

The old `setLastParagraphSpacing` approach conflated two distinct concerns:
1. Internal bottom padding (visual breathing room inside the container)
2. External inter-block spacing (gap between container and next element)

The fix correctly separated concern #2 (external spacing) by moving it to an unattributed terminator, but did not add a replacement for concern #1 (internal padding).

## Proposed Solutions

### Solution A (Recommended): Set `paragraphSpacing` on the trailing `\n` to `codeBlockPadding`

In `appendCodeBlock`, change the trailing `\n` to use a paragraph style with `paragraphSpacing: codeBlockPadding` (12pt) instead of `codeStyle` (which has `paragraphSpacing: 0`).

```swift
// Create a bottom-padding style for the trailing newline
let bottomPaddingStyle = makeParagraphStyle(
    paragraphSpacing: codeBlockPadding,  // 12pt internal bottom padding
    headIndent: codeBlockPadding,
    firstLineHeadIndent: codeBlockPadding,
    tailIndent: -codeBlockPadding
)

codeContent.append(NSAttributedString(string: "\n", attributes: [
    .font: monoFont,
    CodeBlockAttributes.range: blockID,
    CodeBlockAttributes.colors: colorInfo,
    .paragraphStyle: bottomPaddingStyle,  // <-- 12pt bottom padding
]))
```

This `paragraphSpacing: 12` will be included in the fragment frame, expanding the background rect downward by 12pt. The external terminator with `paragraphSpacing: 16` (blockSpacing) then adds the inter-block gap after the background.

- **Effort**: ~5 lines changed in one method
- **Risk**: Low. The `paragraphSpacing` on the trailing `\n` is within the `CodeBlockAttributes.range`, so `CodeBlockBackgroundTextView` will include it in the background rect, which is exactly what we want.
- **Pros**: Symmetric with the top padding approach. Uses the same TextKit 2 mechanism (`paragraphSpacing` -> fragment frame height) that already works for top padding via `paragraphSpacingBefore`. Clean separation: 12pt inside, 16pt outside.
- **Cons**: The 12pt bottom padding is technically `paragraphSpacing` on an empty paragraph, which is semantically a bit odd (it is spacing _after_ nothing). But TextKit 2 handles this correctly.

### Solution B (Alternative): Add a fixed bottom inset in `CodeBlockBackgroundTextView`

Modify `drawCodeBlockContainers(in:)` to add `codeBlockPadding` to the bottom of the bounding rect:

```swift
let drawRect = CGRect(
    x: origin.x + borderInset,
    y: bounding.minY + origin.y,
    width: containerWidth - 2 * borderInset,
    height: bounding.height + codeBlockBottomPadding  // <-- extend downward
)
```

- **Effort**: ~3 lines changed + 1 constant added
- **Risk**: Medium. The drawing rect would extend past the layout fragment frames, potentially overlapping with the next element's fragment frame. The external spacer terminator provides 16pt of gap, so 12pt of extension would fit, but this creates a coupling between the drawing code and the text storage builder's spacing values. Also, the `EntranceAnimator`'s code block cover layer computation (which also unions fragment frames) would NOT include this extension, potentially leaving a visible gap during entrance animation.
- **Pros**: No change to the attributed string structure.
- **Cons**: Drawing-side hack that doesn't fix the underlying data model. Breaks the current invariant that the background rect is derived purely from fragment frames. Entrance animator cover layers would be misaligned.

### Solution C (Alternative): Use a dedicated padding paragraph

Instead of relying on `paragraphSpacing` on the trailing `\n`, insert a separate paragraph that acts as a spacer within the code block range:

```swift
let paddingStyle = makeParagraphStyle(
    paragraphSpacing: 0,
    paragraphSpacingBefore: codeBlockPadding
)
codeContent.append(NSAttributedString(string: "\n", attributes: [
    .font: NSFont.systemFont(ofSize: 1),
    CodeBlockAttributes.range: blockID,
    CodeBlockAttributes.colors: colorInfo,
    .paragraphStyle: paddingStyle,
]))
```

- **Effort**: ~8 lines
- **Risk**: Medium. Introduces a visible "empty paragraph" into the text storage, which could affect text selection (selecting all would include this padding paragraph). The 1pt font minimizes its line height contribution, but it still adds a text line. Also, the `EntranceAnimator` would see an extra fragment for this code block.
- **Pros**: Explicit and obvious padding mechanism.
- **Cons**: Adds complexity, affects selection, may produce a tiny but visible extra line.

### Recommendation

**Solution A** is recommended. It is the simplest change, maintains the existing architectural pattern (fragment frame geometry drives background drawing), and creates a clean symmetric padding model: `paragraphSpacingBefore: 12` on top, `paragraphSpacing: 12` on bottom, with the external terminator handling the 16pt inter-block gap independently.

## Prevention Measures

1. When refactoring spacing that affects background-drawing geometry, verify both the internal padding and external spacing behaviors independently.
2. Consider adding a unit test that verifies the code block's trailing paragraph has non-zero `paragraphSpacing` (to maintain internal bottom padding).
3. The existing `CodeBlockStylingTests` test the presence of attributes and indent values but do not test `paragraphSpacing` on the trailing `\n`. Adding such a test would catch regressions like this.

## Evidence Appendix

### E1: Uncommitted diff

```
$ git diff HEAD -- mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift

-        setLastParagraphSpacing(codeContent, spacing: blockSpacing, baseStyle: codeStyle)
         result.append(codeContent)
+
+        let spacerStyle = makeParagraphStyle(paragraphSpacing: blockSpacing)
+        result.append(terminator(with: spacerStyle))
```

### E2: `codeStyle` paragraph style has `paragraphSpacing: 0`

From `makeCodeBlockParagraphStyle()` at line 190-196:

```swift
private static func makeCodeBlockParagraphStyle() -> NSParagraphStyle {
    makeParagraphStyle(
        paragraphSpacing: 0,       // <-- zero bottom spacing
        headIndent: codeBlockPadding,
        firstLineHeadIndent: codeBlockPadding,
        tailIndent: -codeBlockPadding
    )
}
```

### E3: Trailing `\n` carries `codeStyle` (paragraphSpacing: 0)

From `appendCodeBlock` at lines 112-117:

```swift
codeContent.append(NSAttributedString(string: "\n", attributes: [
    .font: monoFont,
    CodeBlockAttributes.range: blockID,
    CodeBlockAttributes.colors: colorInfo,
    .paragraphStyle: codeStyle,       // <-- paragraphSpacing: 0
]))
```

### E4: Background rect derived from fragment frames

From `CodeBlockBackgroundTextView` at lines 59-64:

```swift
let bounding = frames.reduce(frames[0]) { $0.union($1) }
let drawRect = CGRect(
    x: origin.x + borderInset,
    y: bounding.minY + origin.y,
    width: containerWidth - 2 * borderInset,
    height: bounding.height     // <-- no additional padding
)
```

### E5: Top padding is present via `paragraphSpacingBefore`

From `appendCodeBlock` at lines 109-110:

```swift
let spacingBefore: CGFloat = hasLabel ? codeBlockTopPaddingWithLabel : codeBlockPadding
setFirstParagraphSpacing(codeContent, spacingBefore: spacingBefore)
```

This confirms the asymmetry: top has 12pt (or 8pt with label), bottom has 0pt.

### E6: External spacer terminator does NOT carry `CodeBlockAttributes.range`

From `appendCodeBlock` at lines 121-122:

```swift
let spacerStyle = makeParagraphStyle(paragraphSpacing: blockSpacing)
result.append(terminator(with: spacerStyle))
```

The `terminator(with:)` method creates `NSAttributedString(string: "\n", attributes: [.paragraphStyle: style])` -- no `CodeBlockAttributes.range` attribute. Therefore `CodeBlockBackgroundTextView.collectCodeBlocks()` will not include this paragraph in the code block's range, and its fragment frame will not be included in the background rect. This is correct for external spacing but means no internal bottom padding exists.
