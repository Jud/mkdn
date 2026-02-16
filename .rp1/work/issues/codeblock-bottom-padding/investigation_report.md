# Root Cause Investigation Report - codeblock-bottom-padding

## Executive Summary
- **Problem**: Code block background rectangles have no bottom padding; text sits flush against the bottom edge.
- **Root Cause**: The trailing `\n` appended with `paragraphSpacing: 12` does not create a separate paragraph. It becomes the terminator of the last code line's paragraph. TextKit 2 resolves paragraph style from the **first character** of each paragraph, so the `paragraphSpacing: 12` on the final `\n` is silently ignored.
- **Solution**: Use `setLastParagraphSpacing()` to apply `paragraphSpacing` to the entire last paragraph (first-character position), OR add extra height in `drawCodeBlockContainers()`.
- **Urgency**: Low risk, visual-only. Can be fixed at next convenience.

## Investigation Process
- **Duration**: ~30 minutes
- **Hypotheses Tested**:
  1. **Trailing `\n` does not generate its own layout fragment** -- CONFIRMED (partially). The `\n` does not create a separate paragraph at all; it merges into the preceding paragraph as its terminator character. Therefore no separate fragment exists.
  2. **`paragraphSpacing` on the last paragraph collides/collapses with the external terminator** -- NOT TESTED (moot, since the paragraphSpacing never takes effect at all).
  3. **`fragmentFrames()` method excludes trailing fragment** -- DISPROVED. The method correctly enumerates all fragments within the code block range. The issue is upstream: there is no separate trailing fragment to find.
  4. **The `\n` creates a zero-height paragraph** -- DISPROVED. It creates no separate paragraph whatsoever.
- **Key Evidence**:
  1. Debug logging shows exactly N fragments for N lines of code, with the trailing `\n` absorbed into the Nth paragraph.
  2. The paragraph style at the first character of the last paragraph has `paragraphSpacing: 0`, while the `\n` at the end has `paragraphSpacing: 12` -- but TextKit 2 only uses the first character's style.
  3. Fragment heights confirm: first fragment = 30pt (18pt line + 12pt spacingBefore = top padding works), all other fragments = 18pt (no bottom padding contribution).

## Root Cause Analysis

### Technical Details

**File**: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`
**Lines**: 112-123

The code constructs `codeContent` as follows:

1. `trimmedCode` = `"line one\nline two\nmkdn path/to/file.md"` (no trailing newline)
2. `codeStyle` (with `paragraphSpacing: 0`) is applied to the full range `{0, len}`.
3. `setFirstParagraphSpacing` correctly sets `paragraphSpacingBefore: 12` on the first paragraph -- this works because it modifies the first character's style.
4. A `"\n"` is then appended with `codeBottomStyle` (containing `paragraphSpacing: 12`).

After step 4, the string is `"line one\nline two\nmkdn path/to/file.md\n"`.

The paragraph structure per `NSString.paragraphRange`:
- Para 0: `"line one\n"` -- style at char 0 has `paragraphSpacing: 0, spacingBefore: 12`
- Para 1: `"line two\n"` -- style at char 9 has `paragraphSpacing: 0`
- Para 2: `"mkdn path/to/file.md\n"` -- style at char 18 has `paragraphSpacing: 0`, style at char 38 (the `\n`) has `paragraphSpacing: 12`

**TextKit 2 paragraph style resolution rule**: The layout engine resolves `NSParagraphStyle` properties from the **first character** of each paragraph. Mixed paragraph styles within a single paragraph are not supported -- only the first character's style governs layout. This is consistent across both TextKit 1 and TextKit 2.

Since position 18 (`m` in `mkdn`) has `codeStyle` with `paragraphSpacing: 0`, the `codeBottomStyle` with `paragraphSpacing: 12` on the trailing `\n` at position 38 has **zero effect on layout**.

### Causation Chain

```
Root Cause: "\n" appended as last char becomes the terminator of the preceding paragraph
    |
    v
TextKit 2 resolves paragraphSpacing from position 18 (first char of para), not position 38 ("\n")
    |
    v
paragraphSpacing = 0 for the last code paragraph
    |
    v
Layout fragment height = 18pt (line height only, no spacing contribution)
    |
    v
Bounding rect of all fragments has no bottom padding
    |
    v
Background rectangle drawn with bounding.height -- text sits flush at bottom edge
```

### Why It Occurred

The approach assumed that appending a `"\n"` with a different paragraph style would either:
(a) Create a new, separate paragraph that would contribute its own spacing, or
(b) Override the paragraph style for the existing paragraph.

Neither is true in NSAttributedString/TextKit:
- A `\n` terminates the current paragraph; it does not start a new one. To create a new (empty) paragraph, you would need `\n\n` (or a `\n` after an existing `\n`).
- Paragraph style resolution uses only the first character's attributes.

### Contrast with Top Padding (which works)

Top padding works correctly because `setFirstParagraphSpacing` applies `paragraphSpacingBefore: 12` to the **first character** of the first paragraph (position 0). This character IS the first in its paragraph, so TextKit 2 respects it. Fragment[0] height = 30pt confirms this (18pt line + 12pt spacingBefore).

## Git History Context

The committed version of `appendCodeBlock` (prior to the current uncommitted changes) used a different approach:

```swift
// Committed version (HEAD):
codeContent.append(NSAttributedString(string: "\n", attributes: [
    .font: monoFont,
    CodeBlockAttributes.range: blockID,
    CodeBlockAttributes.colors: colorInfo,
    .paragraphStyle: codeStyle,       // paragraphSpacing: 0
]))
setLastParagraphSpacing(codeContent, spacing: blockSpacing, baseStyle: codeStyle)
result.append(codeContent)
// No separate terminator appended
```

This committed version called `setLastParagraphSpacing` with `blockSpacing` (16pt) -- but that was for **inter-block spacing**, not for internal bottom padding. It also likely did not produce visible bottom padding inside the background, because `paragraphSpacing` (after) in TextKit 2 typically adds space between fragments rather than extending the current fragment's frame height. The current uncommitted attempt tried to fix this by switching to `codeBottomStyle` with `paragraphSpacing: codeBlockPadding` (12pt), but applied it only to the `\n` character, which has no effect due to the first-character rule.

## Proposed Solutions

### Solution A (Recommended): Add explicit bottom padding in `drawCodeBlockContainers()`

**Approach**: Add `codeBlockPadding` (12pt) to the bounding rect height in `CodeBlockBackgroundTextView.drawCodeBlockContainers()`. This is the most reliable approach because it sidesteps the uncertainty of whether TextKit 2 includes `paragraphSpacing` in fragment frame heights.

**Code changes**:

1. In `CodeBlockBackgroundTextView.swift`, add a constant and modify `drawRect`:

```swift
private static let bottomPadding: CGFloat = 12  // matches codeBlockPadding

// In drawCodeBlockContainers, change:
let drawRect = CGRect(
    x: origin.x + borderInset,
    y: bounding.minY + origin.y,
    width: containerWidth - 2 * borderInset,
    height: bounding.height + Self.bottomPadding
)
```

2. In `MarkdownTextStorageBuilder+Blocks.swift`, revert `codeBottomStyle` back to `codeStyle` and restore `setLastParagraphSpacing` for inter-block spacing (or use a separate terminator). The `paragraphSpacing` on the last code paragraph should remain 0 or be set to `blockSpacing` for inter-block gap -- NOT `codeBlockPadding`, since the drawing code now handles the internal padding.

**Effort**: ~5 minutes.
**Risk**: Very low. The drawing code directly controls the background rectangle size, independent of TextKit 2 fragment frame behavior.
**Pros**: Guaranteed to work. Symmetric with how `paragraphSpacingBefore` adds top padding (fragment height includes it), but for the bottom edge where the drawing code has direct control.
**Cons**: The padding constant is in the drawing layer rather than the text storage builder. However, since top padding also comes from TextKit layout (paragraphSpacingBefore) while this is explicit drawing, the asymmetry is acceptable and well-documented.

### Solution B: Use `setLastParagraphSpacing()` with `codeBlockPadding`

**Approach**: Call `setLastParagraphSpacing(codeContent, spacing: codeBlockPadding, baseStyle: codeStyle)` to apply `paragraphSpacing: 12` to the entire last paragraph (first-character position). TextKit 2 will then read it from the correct position.

**Code change** in `appendCodeBlock`:

```swift
codeContent.append(NSAttributedString(string: "\n", attributes: [
    .font: monoFont,
    CodeBlockAttributes.range: blockID,
    CodeBlockAttributes.colors: colorInfo,
    .paragraphStyle: codeStyle,
]))

// Apply internal bottom padding via paragraphSpacing on the last paragraph
setLastParagraphSpacing(codeContent, spacing: codeBlockPadding, baseStyle: codeStyle)
result.append(codeContent)

// Separate terminator for inter-block spacing
let spacerStyle = makeParagraphStyle(paragraphSpacing: blockSpacing)
result.append(terminator(with: spacerStyle))
```

**Effort**: ~5 minutes.
**Risk**: Medium. This relies on TextKit 2 including `paragraphSpacing` in the `layoutFragmentFrame.height`. Evidence shows `paragraphSpacingBefore` IS included (fragment[0] height = 30 = 18 + 12), but `paragraphSpacing` (after) may behave differently -- it might add space between fragments rather than extending the current fragment's height. If `paragraphSpacing` is NOT in the fragment frame, the background rect (computed from fragment frames) will still lack bottom padding. Additionally, `paragraphSpacing` on the last code paragraph may collapse with the terminator's `paragraphSpacing` (TextKit uses max-of-adjacent spacing), potentially affecting inter-block gap.
**Pros**: Keeps all spacing logic in the text storage builder. Uses existing helper.
**Cons**: Uncertain fragment frame behavior. Potential spacing collapse with terminator.

### Solution C: Append `\n\n` instead of `\n` (Not Recommended)

**Approach**: Append `"\n\n"` so the second `\n` creates a genuinely separate (empty) paragraph with its own `paragraphSpacingBefore: codeBlockPadding`.

**Risk**: High. An empty paragraph may still have zero height in TextKit 2. Also, `paragraphSpacingBefore` on an empty paragraph after the code may behave unpredictably.
**Cons**: Fragile, unpredictable behavior with empty paragraphs in TextKit 2.

## Prevention Measures

1. **TextKit 2 paragraph style rule**: Always remember that `NSParagraphStyle` is resolved from the first character of each paragraph. Applying a different paragraph style to later characters within the same paragraph has no layout effect. Document this in the project's TextKit 2 gotchas.

2. **Symmetry principle**: When implementing internal padding for custom-drawn containers:
   - Top padding: use `paragraphSpacingBefore` on the first paragraph's first character (already correct).
   - Bottom padding: use `paragraphSpacing` on the last paragraph's first character (via `setLastParagraphSpacing`), OR use explicit padding in the drawing code.

3. **Debug verification**: When working with TextKit 2 layout fragment geometry, add temporary fragment frame logging to verify layout assumptions before relying on paragraph style properties.

## Evidence Appendix

### Debug Output (Full Log)

See `/Users/jud/Projects/mkdn/.rp1/work/issues/codeblock-bottom-padding/evidence/debug_output.txt`

### Key Data Points

| Measurement | Value | Significance |
|-------------|-------|--------------|
| Fragment[0] height (with spacingBefore: 12) | 30pt | Confirms paragraphSpacingBefore IS included in fragment frame |
| Fragment[1] height (paragraphSpacing: 0) | 18pt | Baseline line height for monospaced font |
| Fragment[2] height (paragraphSpacing: 0 at first char, 12 at \n) | 18pt | Confirms TextKit 2 ignores style on \n |
| Bounding rect total height | 66pt | = 30 + 18 + 18, no bottom padding |
| Gap between last code fragment and next element | 0pt | Code block ends at y=115, next fragment starts at y=115 |

### Files Examined

| File | Path | Relevance |
|------|------|-----------|
| Code block builder | `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift` | Where the trailing `\n` with codeBottomStyle is appended (lines 112-123) |
| Builder utilities | `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift` | `setLastParagraphSpacing()` helper (lines 244-272), `makeParagraphStyle()`, `terminator()` |
| Background drawing | `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift` | `fragmentFrames()` and `drawCodeBlockContainers()` -- background rect computation from fragment union |
| Attribute definitions | `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/CodeBlockAttributes.swift` | `CodeBlockAttributes.range` and `.colors` custom attribute keys |
| Text view setup | `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/SelectableTextView.swift` | `setAttributedString` call site, `textContainerInset` configuration |
