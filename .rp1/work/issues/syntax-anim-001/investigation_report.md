# Root Cause Investigation Report - syntax-anim-001

## Executive Summary
- **Problem**: Two bugs in code block rendering: (1) syntax highlighting not visible, (2) code blocks don't animate in correctly.
- **Root Cause (Bug 1)**: SwiftUI `AttributedString.foregroundColor` stores colors under the key `SwiftUI.ForegroundColor`, but `NSTextView` expects `NSAttributedString.Key.foregroundColor` (raw value `"NSColor"`). The `NSMutableAttributedString(AttributedString)` conversion preserves the SwiftUI-scoped attribute key, which `NSTextView` ignores entirely. All syntax-highlighted tokens fall back to the default text color.
- **Root Cause (Bug 2)**: `EntranceAnimator.makeCoverLayer` uses `textView.backgroundColor` (the document background) for ALL cover layers, but code blocks have a different background color (`codeBackground`). During the fade-out animation, code block regions show the wrong background color before revealing the actual code block container.
- **Solution**: (1) Convert Splash output to `NSAttributedString` directly using `NSColor` attributes instead of going through SwiftUI `AttributedString`. (2) Detect code block fragments in `makeCoverLayer` and use the appropriate background color.
- **Urgency**: Medium-High -- syntax highlighting is a core feature of the code-block-styling PRD, and these bugs make the feature appear non-functional.

## Investigation Process
- **Hypotheses Tested**: 5 for Bug 1, 3 for Bug 2
- **Key Evidence**:
  1. Empirical proof that `NSAttributedString(AttributedString)` maps SwiftUI `.foregroundColor` to the key `SwiftUI.ForegroundColor` (not `NSColor`), and `attrs[.foregroundColor]` returns `nil`
  2. The `EntranceAnimator.makeCoverLayer` unconditionally uses `textView.backgroundColor` at line 134 of `EntranceAnimator.swift`
  3. Pixel-level compliance tests pass misleadingly due to insufficient precision (counts distinct colors >= 2, not token-level coloring)

## Bug 1: Syntax Highlighting Not Working

### Root Cause Analysis

**Technical Details:**

File: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/ThemeOutputFormat.swift`
Lines: 19-22

The `ThemeOutputFormat.Builder.addToken()` method sets:
```swift
attributed.foregroundColor = tokenColorMap[type] ?? plainTextColor
```

This uses `AttributedString.foregroundColor`, which stores the color in the `SwiftUI.AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute` scope.

File: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift`
Line: 186

The conversion:
```swift
return NSMutableAttributedString(highlighted)
```

converts the SwiftUI `AttributedString` to an `NSAttributedString`. However, this conversion maps `AttributedString.foregroundColor` to the `NSAttributedString` key `SwiftUI.ForegroundColor` (NOT `NSAttributedString.Key.foregroundColor` which has raw value `"NSColor"`).

**Empirical Proof:**

```swift
var swiftUIStr = AttributedString("Hello")
swiftUIStr.foregroundColor = .red
let nsStr = NSAttributedString(swiftUIStr)
let attrs = nsStr.attributes(at: 0, effectiveRange: nil)

// Result:
// Key: "SwiftUI.ForegroundColor"  -- NOT "NSColor"
// Value type: __SwiftValue          -- NOT NSColor
// attrs[.foregroundColor] = nil     -- NSTextView cannot see this color
```

`NSTextView`'s text rendering system reads `.foregroundColor` (raw value `"NSColor"`) from the attributed string to determine text color. Since the syntax highlighting colors are stored under a different key (`SwiftUI.ForegroundColor`), they are completely invisible to the text view. All code text renders in the default foreground color.

### Causation Chain

```
1. ThemeOutputFormat.Builder.addToken() sets AttributedString.foregroundColor (SwiftUI scope)
2. SyntaxHighlighter.highlight() produces AttributedString with SwiftUI-scoped colors
3. NSMutableAttributedString(highlighted) preserves SwiftUI key "SwiftUI.ForegroundColor"
4. NSTextView reads .foregroundColor (key "NSColor") -- finds nil for syntax-highlighted runs
5. Text renders in default/fallback foreground color -- all tokens same color
6. Syntax highlighting appears broken (uniform color for all code text)
```

### Why Tests Passed Despite This Bug

1. **Unit test gap**: `CodeBlockStylingTests.swiftSyntaxHighlighting()` at `/Users/jud/Projects/mkdn/mkdnTests/Unit/Core/CodeBlockStylingTests.swift:119-155` checks `swiftRunCount > plainRunCount`. The conversion DOES create multiple attribute runs (because each SwiftUI color value is distinct), so `3 > 1` is true. But the test never checks the attribute KEY or VALUE TYPE, missing the fact that the colors use the wrong key for `NSTextView`.

2. **Pixel test gap**: `VisualComplianceTests+Syntax.swift` at `/Users/jud/Projects/mkdn/mkdnTests/UITest/VisualComplianceTests+Syntax.swift:62-103` counts `distinctCount >= 2` -- distinct non-background colors in the code block region. This passes because:
   - The language label ("swift") uses `foregroundSecondary` color set directly via `NSColor` in `appendCodeLabel`
   - The code text falls back to `NSTextView`'s default text color or the `insertionPointColor`
   - These two colors are distinct from each other and from the background, satisfying `>= 2`
   - The test doesn't verify that DIFFERENT tokens have DIFFERENT colors (which is the actual syntax highlighting requirement)

### Why It Occurred

The issue stems from a subtle distinction between two similarly-named but functionally different attribute systems:

- **SwiftUI `AttributedString.foregroundColor`**: Uses the `SwiftUI.AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute` scope, storing `SwiftUI.Color` values
- **AppKit `NSAttributedString.Key.foregroundColor`**: Uses the raw key `"NSColor"`, expecting `NSColor` values

The `NSAttributedString(AttributedString)` initializer does NOT bridge SwiftUI-scoped attributes to their AppKit equivalents. It preserves the SwiftUI key verbatim, which `NSTextView` does not recognize.

The `ThemeOutputFormat` was originally designed for SwiftUI `Text` views (which DO understand `SwiftUI.ForegroundColor`). When the rendering was migrated from SwiftUI views to `NSTextView` via `MarkdownTextStorageBuilder`, the output format was reused without adapting the color storage to use AppKit-compatible attributes.

## Bug 2: Code Blocks Don't Animate In Correctly

### Root Cause Analysis

**Technical Details:**

File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/EntranceAnimator.swift`
Lines: 124-137

```swift
private func makeCoverLayer(
    for fragment: NSTextLayoutFragment,
    in textView: NSTextView
) -> CALayer {
    let frame = fragment.layoutFragmentFrame
    let origin = textView.textContainerOrigin
    let adjustedFrame = frame.offsetBy(dx: origin.x, dy: origin.y)

    let layer = CALayer()
    layer.frame = adjustedFrame
    layer.backgroundColor = textView.backgroundColor.cgColor  // BUG: always document bg
    layer.zPosition = 1
    return layer
}
```

The cover layer ALWAYS uses `textView.backgroundColor` (the document background color), regardless of what's behind the fragment. For code block fragments, the underlying background is `codeBackground` (drawn by `CodeBlockBackgroundTextView.drawBackground(in:)`), which is a different color.

### Causation Chain

```
1. EntranceAnimator creates cover layers for each layout fragment
2. Each cover layer uses textView.backgroundColor (document bg: base03/base3)
3. CodeBlockBackgroundTextView.drawBackground(in:) draws codeBackground (base02/base2)
4. Cover layer (zPosition 1) sits on top of both code block bg and text
5. Cover layer color (document bg) mismatches code block bg underneath
6. During fade-out: document-bg color transitions to code-bg color
7. Visual artifact: code blocks "flash" the wrong background during entrance

Solarized Dark: document bg #002b36 -> code bg #073642 (slight brightening flash)
Solarized Light: document bg #fdf6e3 -> code bg #eee8d5 (slight darkening flash)
```

### Additional Animation Issues

1. **Per-fragment vs block-level coverage**: Cover layers are sized per layout fragment (per text line), but the code block background is a single rounded rectangle spanning all lines. This can cause:
   - Gaps between cover layers at fragment boundaries revealing the code bg prematurely
   - Cover layers extending beyond the rounded corners of the code block
   - Uneven reveal if fragments have slightly different widths

2. **drawBackground timing**: The `drawBackground(in:)` method is called during AppKit's drawing cycle, which renders into the view's backing layer. Cover sublayers sit on top. The code block background is always fully drawn underneath -- it's just hidden by the cover. This means the code block background "pops" into view rather than fading in smoothly, because the code block bg transitions instantly from hidden-under-cover to fully-visible.

## Proposed Solutions

### Bug 1: Syntax Highlighting Fix

#### Recommended: Convert ThemeOutputFormat to produce NSAttributedString directly

Modify `highlightSwiftCode` to either:

**Option A**: Create a new `NSThemeOutputFormat` that implements Splash's `OutputFormat` but produces `NSAttributedString` with `NSColor` values directly:

```swift
struct NSThemeOutputFormat: OutputFormat {
    let plainTextColor: NSColor
    let tokenColorMap: [TokenType: NSColor]

    struct Builder: OutputBuilder {
        // Build NSAttributedString directly with .foregroundColor = NSColor
    }
}
```

**Effort**: Small (duplicate ThemeOutputFormat with NSColor instead of SwiftUI.Color)
**Risk**: Low
**Pros**: Clean separation; ThemeOutputFormat remains usable for SwiftUI Text views
**Cons**: Slight code duplication

**Option B**: Post-process the highlighted output in `highlightSwiftCode` to convert `SwiftUI.ForegroundColor` attributes to `.foregroundColor` with `NSColor`:

```swift
let highlighted = highlighter.highlight(trimmedCode)
let nsAttr = NSMutableAttributedString(highlighted)
// Enumerate SwiftUI.ForegroundColor attributes and convert to .foregroundColor with NSColor
```

**Effort**: Small
**Risk**: Low-Medium (depends on being able to read the SwiftUI-scoped attribute values)
**Cons**: Fragile -- depends on internal SwiftUI attribute key naming

#### Alternative: Use Foundation-scoped foregroundColor in ThemeOutputFormat

Modify `ThemeOutputFormat.Builder` to use the Foundation attribute scope instead of SwiftUI:

```swift
mutating func addToken(_ token: String, ofType type: TokenType) {
    var attributed = AttributedString(token)
    // Use Foundation scope instead of SwiftUI scope
    attributed[AttributeScopes.AppKitAttributes.ForegroundColorAttribute.self] =
        NSColor(tokenColorMap[type] ?? plainTextColor)
    result.append(attributed)
}
```

**Effort**: Small
**Risk**: Low
**Pros**: Single change in the output format builder
**Cons**: ThemeOutputFormat would no longer work with SwiftUI Text views (but it's currently ONLY used in the NSTextView path, so this is acceptable)

### Bug 2: Code Block Animation Fix

#### Recommended: Detect code block fragments and use codeBackground color

Modify `makeCoverLayer` to check if the fragment falls within a code block region and use the appropriate background color:

```swift
private func makeCoverLayer(
    for fragment: NSTextLayoutFragment,
    in textView: NSTextView
) -> CALayer {
    let layer = CALayer()
    layer.frame = adjustedFrame

    // Check if this fragment is in a code block
    if isCodeBlockFragment(fragment, in: textView) {
        layer.backgroundColor = codeBlockBackgroundColor(from: textView).cgColor
    } else {
        layer.backgroundColor = textView.backgroundColor.cgColor
    }

    layer.zPosition = 1
    return layer
}
```

The code block detection can check `CodeBlockAttributes.range` on the text storage at the fragment's character range.

**Effort**: Medium
**Risk**: Low
**Pros**: Correct visual behavior for code blocks
**Cons**: Requires querying text storage attributes during animation setup

#### Alternative: Use block-level cover layers for code blocks

Instead of per-fragment covers, create a single cover layer matching the code block's rounded rectangle for code block regions. This would require:
1. Detecting contiguous code block fragment groups
2. Computing the bounding rect (same as `CodeBlockBackgroundTextView.drawCodeBlockContainers`)
3. Creating a rounded-rect cover layer with `codeBackground` color

**Effort**: Large
**Risk**: Medium
**Pros**: Perfect visual match including rounded corners
**Cons**: Significant refactoring of EntranceAnimator

## Prevention Measures

1. **Test attribute types, not just counts**: Unit tests for syntax highlighting should verify that `.foregroundColor` (the NSAttributedString key) contains `NSColor` values, not just that attribute runs exist. Add a test like:
   ```swift
   let attrs = str.attributes(at: swiftCodeLoc, effectiveRange: nil)
   let color = attrs[.foregroundColor]
   #expect(color is NSColor, "foregroundColor must be NSColor for NSTextView")
   ```

2. **Pixel-level token verification**: The visual compliance syntax test should verify that DIFFERENT token types produce DIFFERENT colors, not just that >= 2 colors exist in the region. Sample at known token positions.

3. **Animation coverage for styled regions**: Add animation compliance tests that verify entrance animation behavior for regions with custom backgrounds (code blocks).

4. **Integration testing bridge**: When migrating from one rendering technology to another (SwiftUI -> NSTextView), create bridge-verification tests that confirm attribute compatibility with the target rendering system.

## Evidence Appendix

### A. SwiftUI AttributedString foregroundColor key mismatch (empirical)

```
$ swift -e '
import SwiftUI; import AppKit
var s = AttributedString("x"); s.foregroundColor = .red
let ns = NSAttributedString(s)
let a = ns.attributes(at: 0, effectiveRange: nil)
for (k, v) in a { print("Key: \(k.rawValue), Type: \(type(of: v))") }
print("attrs[.foregroundColor] = \(String(describing: a[.foregroundColor]))")
'

Output:
  Key: SwiftUI.ForegroundColor, Type: __SwiftValue
  attrs[.foregroundColor] = nil
```

### B. Multiple runs exist but with wrong key

```
$ swift -e '... simulate ThemeOutputFormat output ...'

Output:
  Run: "func" -> attrs: ["SwiftUI.ForegroundColor"]
  Run: " " -> attrs: ["SwiftUI.ForegroundColor"]
  Run: "greet" -> attrs: ["SwiftUI.ForegroundColor"]
  Total runs: 3
  Has NSColor foregroundColor? false
```

### C. EntranceAnimator cover layer color (line 134)

File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/EntranceAnimator.swift:134`
```swift
layer.backgroundColor = textView.backgroundColor.cgColor
// Always document bg, never codeBackground
```

### D. Solarized color differences

| Color | Dark | Light |
|-------|------|-------|
| Document bg | #002b36 (base03) | #fdf6e3 (base3) |
| Code block bg | #073642 (base02) | #eee8d5 (base2) |
| Difference | Lighter (+slight) | Darker (+slight) |

### E. Test gap analysis

| Test | What it checks | Why it passes despite bug |
|------|---------------|--------------------------|
| `swiftSyntaxHighlighting` | Run count: swift > plain | SwiftUI-scoped attrs create distinct runs |
| `syntaxTokensDark/Light` | >= 2 distinct colors | Language label + fallback text color = 2 |
| `codeBlockStructuralContainer` | Edge consistency | Wrapped in `withKnownIssue` (expected to fail) |

### F. Key files involved

| File | Role in Bug 1 | Role in Bug 2 |
|------|---------------|---------------|
| `ThemeOutputFormat.swift` | Sets SwiftUI-scoped foregroundColor | N/A |
| `MarkdownTextStorageBuilder.swift:186` | NSMutableAttributedString(highlighted) conversion | N/A |
| `MarkdownTextStorageBuilder+Blocks.swift:88-90` | Swift code block rendering path | N/A |
| `EntranceAnimator.swift:124-137` | N/A | Cover layer uses wrong bg color |
| `CodeBlockBackgroundTextView.swift` | N/A | Draws correct bg but hidden by cover |
