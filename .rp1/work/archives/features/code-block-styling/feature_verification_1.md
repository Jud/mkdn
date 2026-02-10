# Feature Verification Report #1

**Generated**: 2026-02-09T23:35:00Z
**Feature ID**: code-block-styling
**Verification Scope**: all
**KB Context**: VERIFIED Loaded
**Field Notes**: WARNING Not available

## Executive Summary
- Overall Status: WARNING PARTIAL
- Acceptance Criteria: 9/11 functional requirements verified (82%)
- Task Completion: 5/8 tasks complete (T1-T5 done, TD1-TD3 not done)
- Unit Tests: 39/39 passing (7 CodeBlockStyling + 32 MarkdownTextStorageBuilder)
- Implementation Quality: HIGH
- Ready for Merge: NO (documentation updates pending, visual verification incomplete)

## Field Notes Context
**Field Notes Available**: WARNING No

### Documented Deviations
No field-notes.md file exists in the feature directory. However, design-decisions.md documents one intentional deviation:

- **D5**: FR-8 (horizontal scrolling) deferred -- code lines soft-wrap within the container. FR-10 (text selection, Must Have) conflicts with per-block horizontal scrolling in a single NSTextView. This is documented in both design.md and design-decisions.md.

### Undocumented Deviations
1. **codeBlockStructuralContainer known issue not updated**: The pre-existing test at `VisualComplianceTests+Structure.swift:44-63` wraps its assertion in `withKnownIssue` with text suggesting the fix is to "integrate CodeBlockView rounded-rect styling into NSTextView rendering path." This feature implements exactly that fix, but the known issue annotation has not been removed/updated. The test's pixel-level edge detection returns `hasEnoughSamples: false` (zero left/right edges found), suggesting the detection logic does not account for the new `drawBackground(in:)` rendering approach.

2. **Documentation tasks TD1, TD2, TD3 not completed**: modules.md and architecture.md have not been updated to reflect the new CodeBlockAttributes.swift, CodeBlockBackgroundTextView.swift, or the updated code block rendering pipeline.

## Acceptance Criteria Verification

### FR-1: Code blocks render with a visible full-width rounded-rectangle background box
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift`:38-73 - `drawCodeBlockContainers(in:)`
- Evidence: The `drawCodeBlockContainers` method enumerates `CodeBlockAttributes.range` in text storage, computes bounding rects from `NSTextLayoutManager.enumerateTextLayoutFragments`, extends width to `textContainer.size.width` (full-width per FR-1), and draws via `NSBezierPath(roundedRect:xRadius:yRadius:)`. The container spans the content area width minus a border inset.
- Field Notes: N/A
- Issues: None

### FR-2: Code blocks have internal padding between box edge and text content on all sides
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`:180-187 - `makeCodeBlockParagraphStyle()`
- Evidence: The `makeCodeBlockParagraphStyle()` helper sets `headIndent: codeBlockPadding` (12pt), `firstLineHeadIndent: codeBlockPadding` (12pt), and `tailIndent: -codeBlockPadding` (-12pt). Top padding is provided via `setFirstParagraphSpacing()` at lines 189-207, setting `paragraphSpacingBefore` to 8pt (with label) or 12pt (without). Bottom padding is via `setLastParagraphSpacing` at line 115. The `codeBlockPadding` constant is defined at `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift`:25 as `static let codeBlockPadding: CGFloat = 12`. Unit test at `/Users/jud/Projects/mkdn/mkdnTests/Unit/Core/CodeBlockStylingTests.swift`:79-96 confirms `headIndent == 12`, `firstLineHeadIndent == 12`, `tailIndent == -12`.
- Field Notes: N/A
- Issues: None

### FR-3: Code blocks display a 1pt border around the background box in both themes
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift`:75-92 - `drawRoundedContainer(in:colorInfo:)`
- Evidence: The method draws with `path.lineWidth = Self.borderWidth` where `borderWidth` is `1` (line 21). The stroke color is `colorInfo.border.withAlphaComponent(Self.borderOpacity)` where `borderOpacity` is `0.3` (line 22). Border color is resolved from the theme via `CodeBlockColorInfo.border` which comes from `ThemeColors.border`. Unit test at `/Users/jud/Projects/mkdn/mkdnTests/Unit/Core/CodeBlockStylingTests.swift`:53-75 verifies the border color matches `theme.colors.border` for both Solarized Dark and Solarized Light themes.
- Field Notes: N/A
- Issues: None

### FR-4: Code blocks have vertical spacing above and below separating them from adjacent content
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`:105-116
- Evidence: `paragraphSpacingBefore` is set on the first paragraph of the code block (8pt with label, 12pt without via `setFirstParagraphSpacing`). The last paragraph gets `paragraphSpacing: blockSpacing` (12pt) via `setLastParagraphSpacing(codeContent, spacing: blockSpacing, baseStyle: codeStyle)` at line 115. The label itself also has `paragraphSpacingBefore: codeBlockPadding` (12pt) set at line 219. This provides vertical separation from surrounding content.
- Field Notes: N/A
- Issues: None

### FR-5: Language label appears above code body when a language tag is present
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`:209-232 - `appendCodeLabel(to:language:blockID:colorInfo:colors:)`
- Evidence: The method creates a label with `captionMonospacedFont()` and `foregroundSecondary` color (smaller, secondary-colored per requirement). It is inserted before the code content (called at line 79-85 before code content is appended). The label carries the same `CodeBlockAttributes.range` (blockID) and `CodeBlockAttributes.colors` (colorInfo) as the code body, making it visually part of the same container. Unit test at `/Users/jud/Projects/mkdn/mkdnTests/Unit/Core/CodeBlockStylingTests.swift`:177-200 confirms the language label shares the same block ID as the code body.
- Field Notes: N/A
- Issues: None

### FR-6: Swift code blocks display syntax highlighting with token-level coloring
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift`:165-187 - `highlightSwiftCode(_:theme:)`
- Evidence: Splash `SyntaxHighlighter` is used with `ThemeOutputFormat` mapping token types (keyword, string, type, call, number, comment, property, dotAccess, preprocessing) to theme `SyntaxColors`. The highlighted result is applied when `language == "swift"` at `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`:88-90. Unit test at `/Users/jud/Projects/mkdn/mkdnTests/Unit/Core/CodeBlockStylingTests.swift`:119-155 confirms Swift code blocks have more attribute runs than plain code blocks, demonstrating token-level coloring.
- Field Notes: N/A
- Issues: None

### FR-7: Non-Swift code blocks render as plain monospaced text in codeForeground color
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`:91-96
- Evidence: When language is not "swift", code content is created with `attributes: [.font: monoFont, .foregroundColor: codeForeground]` where `codeForeground = PlatformTypeConverter.nsColor(from: colors.codeForeground)`. Unit test at `/Users/jud/Projects/mkdn/mkdnTests/Unit/Core/CodeBlockStylingTests.swift`:159-173 confirms a Python code block uses `codeForeground` color.
- Field Notes: N/A
- Issues: None

### FR-8: Code blocks are horizontally scrollable when content exceeds the container width
- Status: INTENTIONAL DEVIATION
- Implementation: N/A (deferred)
- Evidence: Design decision D5 in both `/Users/jud/Projects/mkdn/.rp1/work/features/code-block-styling/design.md` (line 357) and `/Users/jud/Projects/mkdn/.rp1/work/features/code-block-styling/design-decisions.md` (line 14) explicitly documents this deferral. FR-10 (text selection, Must Have) takes priority over FR-8 (horizontal scroll, Should Have). Code lines soft-wrap within the container instead.
- Field Notes: N/A (documented in design decisions, not field notes)
- Issues: This is a "Should Have" requirement deferred with documented rationale. Not a blocker.

### FR-9: Code block styling consistent across Solarized Dark and Solarized Light themes
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`:73-76
- Evidence: `CodeBlockColorInfo` is constructed from `colors.codeBackground` and `colors.border` at lines 73-76, which come from the active `ThemeColors` instance. When the theme changes, `MarkdownPreviewView.onChange(of: appSettings.theme)` (line 81-93 of MarkdownPreviewView.swift) rebuilds the entire attributed string with the new theme, creating new `CodeBlockColorInfo` with updated colors. Container shape and spacing (6pt corners, 1pt border, 12pt padding) are constants that do not vary by theme. The parameterized unit test at `/Users/jud/Projects/mkdn/mkdnTests/Unit/Core/CodeBlockStylingTests.swift`:53-75 runs against both `solarizedDark` and `solarizedLight`, verifying correct colors for each.
- Field Notes: N/A
- Issues: None

### FR-10: Text within code blocks is selectable
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/SelectableTextView.swift`:97-124 - `makeScrollableCodeBlockTextView()`
- Evidence: `CodeBlockBackgroundTextView` is an `NSTextView` subclass (not an overlay or separate view), so all text remains in the same `NSTextStorage`. The `configureTextView` method at line 126-144 sets `isSelectable = true`. Code block text is part of the continuous text flow (attributed string), preserving cross-block selection. The `drawBackground(in:)` approach was specifically chosen to preserve text selection (design decision D1).
- Field Notes: N/A
- Issues: Cross-block selection requires manual runtime testing. Unit tests cannot exercise NSTextView selection behavior.

### FR-11: Code block styling is validated through the visual verification workflow
- Status: WARNING PARTIAL
- Implementation: `/Users/jud/Projects/mkdn/scripts/visual-verification/` and `/Users/jud/Projects/mkdn/mkdnTests/UITest/VisionCompliance/`
- Evidence: The visual verification dry-run was reported as successful in T5 implementation summary (8 captures, 4 batches). The `VisionCapture` test suite passes (capturing screenshots of canonical.md and theme-tokens.md fixtures). However, the full LLM vision evaluation was NOT executed -- only a dry-run confirming pipeline functionality. Additionally, the `codeBlockStructuralContainer` pixel-level test at `/Users/jud/Projects/mkdn/mkdnTests/UITest/VisualComplianceTests+Structure.swift` still reports a known issue with `hasEnoughSamples: false`, indicating the edge detection algorithm does not detect the new `drawBackground` rendering.
- Field Notes: N/A
- Issues: (1) Full LLM vision evaluation not completed. (2) The `codeBlockStructuralContainer` test's pixel detection may need updating to work with the `drawBackground(in:)` approach rather than `.backgroundColor` attribute scanning.

## Task Completion Status

| Task | Status | Notes |
|------|--------|-------|
| T1: Custom attributes + CodeBlockBackgroundTextView | VERIFIED Complete | All 10 acceptance criteria verified in code |
| T2: MarkdownTextStorageBuilder updates | VERIFIED Complete | All 11 acceptance criteria verified; 32/32 tests pass |
| T3: Wire into SelectableTextView | VERIFIED Complete | All 6 acceptance criteria verified in code |
| T4: Unit tests | VERIFIED Complete | 7/7 CodeBlockStyling tests pass; all 8 acceptance criteria met |
| T5: Integration verification | VERIFIED Complete | Build/test/lint all pass; visual dry-run succeeded |
| TD1: Update modules.md Core Markdown | NOT VERIFIED Not started | CodeBlockAttributes.swift not listed |
| TD2: Update modules.md Viewer | NOT VERIFIED Not started | CodeBlockBackgroundTextView.swift not listed |
| TD3: Update architecture.md | NOT VERIFIED Not started | Code block pipeline still shows old SwiftUI path |

## Implementation Gap Analysis

### Missing Implementations
- **TD1**: `CodeBlockAttributes.swift` is not listed in `/Users/jud/Projects/mkdn/.rp1/context/modules.md` Core Layer > Markdown table
- **TD2**: `CodeBlockBackgroundTextView.swift` is not listed in `/Users/jud/Projects/mkdn/.rp1/context/modules.md` Features Layer > Viewer table
- **TD3**: The Code Blocks rendering pipeline in `/Users/jud/Projects/mkdn/.rp1/context/architecture.md` (lines 53-58) still describes the old pipeline: "Code block with language tag -> Splash SyntaxHighlighter -> AttributedString with theme colors -> SwiftUI Text". This should be updated to describe the new pipeline through `MarkdownTextStorageBuilder` + `CodeBlockBackgroundTextView`.

### Partial Implementations
- **FR-11 (Visual Verification)**: The visual verification dry-run succeeded, confirming pipeline functionality. However, the full LLM vision evaluation was not executed. The `codeBlockStructuralContainer` pixel-level test still triggers its `withKnownIssue` block because its edge detection algorithm finds zero samples -- likely because the new `drawBackground(in:)` rendering is not captured by the pixel-level scanning approach used in that test.

### Implementation Issues
- **Known Issue annotation stale**: The `withKnownIssue` annotation in `VisualComplianceTests+Structure.swift:44-49` describes the problem this feature was designed to fix. Now that the feature is implemented, this known issue annotation should either be updated or the test should be adjusted to validate the new rendering approach.
- **Intermittent test crash**: During one test run, the `MarkdownTextStorageBuilder` test suite crashed with `NSInvalidArgumentException: nil value` in `appendCodeBlock`. This appeared to be a race condition in the concurrent test runner and did not reproduce on subsequent runs. All 39 relevant tests passed consistently on clean runs.

## Code Quality Assessment

**Overall Quality: HIGH**

1. **Architecture adherence**: The implementation follows the documented Feature-Based MVVM pattern. New types are placed in appropriate directories (`Core/Markdown/` for attributes, `Features/Viewer/Views/` for the NSTextView subclass).

2. **Design pattern consistency**: The `CodeBlockBackgroundTextView` subclass approach integrates cleanly with the existing TextKit 2 pipeline. The `drawBackground(in:)` override is the correct AppKit pattern for custom background drawing in NSTextView.

3. **Theme system compliance**: All colors are resolved from `ThemeColors` via `PlatformTypeConverter.nsColor()` -- no hardcoded color literals (BR-1 compliance). Colors are carried in `CodeBlockColorInfo` stored as attributed string attributes, making the drawing code self-contained.

4. **Spacing system compliance**: Padding values use named constants (`codeBlockPadding`, `codeBlockTopPaddingWithLabel`, `codeLabelSpacing`) defined in `MarkdownTextStorageBuilder`, following the existing pattern of static `CGFloat` constants.

5. **Swift 6 compatibility**: `CodeBlockColorInfo` is `final class: NSObject` (required for NSAttributedString attribute values). `CodeBlockBackgroundTextView` is `final class: NSTextView`. Both compile under Swift 6 strict concurrency.

6. **Test coverage**: 7 dedicated unit tests in CodeBlockStylingTests covering: range attribute presence, color info correctness (parameterized across both themes), paragraph indent values, absence of per-run background color, Swift syntax highlighting, non-Swift foreground color, and language label block ID sharing.

7. **Code documentation**: Both new files have comprehensive doc comments explaining purpose, mechanism, and relationship to requirements.

8. **Dirty rect optimization**: `CodeBlockBackgroundTextView.drawCodeBlockContainers(in:)` checks `drawRect.intersects(dirtyRect)` before drawing each container, avoiding unnecessary drawing.

## Recommendations

1. **Complete documentation updates (TD1, TD2, TD3)**: Add `CodeBlockAttributes.swift` and `CodeBlockBackgroundTextView.swift` to the module inventory in `/Users/jud/Projects/mkdn/.rp1/context/modules.md`. Update the Code Blocks rendering pipeline in `/Users/jud/Projects/mkdn/.rp1/context/architecture.md` to reflect the new `MarkdownTextStorageBuilder` + `CodeBlockBackgroundTextView` approach.

2. **Update or remove the `withKnownIssue` annotation**: The test at `/Users/jud/Projects/mkdn/mkdnTests/UITest/VisualComplianceTests+Structure.swift:44-63` describes a problem this feature solves. Update the edge detection logic to work with the `drawBackground(in:)` rendering approach, then remove the `withKnownIssue` wrapper to convert this into a proper passing test.

3. **Run full LLM visual verification**: Execute `scripts/visual-verification/verify-visual.sh` (without `--dry-run`) to perform the full LLM vision evaluation against the captured screenshots, completing FR-11 verification.

4. **Investigate intermittent crash**: The `NSInvalidArgumentException: nil value` in `appendCodeBlock` observed during concurrent test execution may indicate a thread-safety issue in the test harness or a rare edge case. Monitor for recurrence.

5. **Create field-notes.md**: Document the FR-8 deferral (D5) and any observations from the implementation process in a field-notes.md file for future reference.

## Verification Evidence

### CodeBlockAttributes.swift
File: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/CodeBlockAttributes.swift`
```swift
enum CodeBlockAttributes {
    static let range = NSAttributedString.Key("mkdn.codeBlockRange")
    static let colors = NSAttributedString.Key("mkdn.codeBlockColors")
}

final class CodeBlockColorInfo: NSObject {
    let background: NSColor
    let border: NSColor
    init(background: NSColor, border: NSColor) { ... }
}
```

### CodeBlockBackgroundTextView.swift - Drawing Constants
File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift`
```swift
private static let cornerRadius: CGFloat = 6
private static let borderWidth: CGFloat = 1
private static let borderOpacity: CGFloat = 0.3
```

### CodeBlockBackgroundTextView.swift - Rounded Rect Drawing
```swift
private func drawRoundedContainer(in rect: NSRect, colorInfo: CodeBlockColorInfo) {
    let path = NSBezierPath(roundedRect: rect, xRadius: Self.cornerRadius, yRadius: Self.cornerRadius)
    colorInfo.background.setFill()
    path.fill()
    colorInfo.border.withAlphaComponent(Self.borderOpacity).setStroke()
    path.lineWidth = Self.borderWidth
    path.stroke()
}
```

### MarkdownTextStorageBuilder - Padding Constants
File: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift`
```swift
static let codeBlockPadding: CGFloat = 12
static let codeBlockTopPaddingWithLabel: CGFloat = 8
```

### MarkdownTextStorageBuilder+Blocks.swift - Code Block Attribute Application
File: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`
```swift
let blockID = UUID().uuidString
let colorInfo = CodeBlockColorInfo(
    background: PlatformTypeConverter.nsColor(from: colors.codeBackground),
    border: PlatformTypeConverter.nsColor(from: colors.border)
)
// ...
codeContent.addAttribute(CodeBlockAttributes.range, value: blockID, range: fullRange)
codeContent.addAttribute(CodeBlockAttributes.colors, value: colorInfo, range: fullRange)
```

### SelectableTextView.swift - CodeBlockBackgroundTextView Integration
File: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/SelectableTextView.swift`
```swift
private static func makeScrollableCodeBlockTextView() -> (
    NSScrollView, CodeBlockBackgroundTextView
) {
    let textContainer = NSTextContainer()
    textContainer.widthTracksTextView = true
    let layoutManager = NSTextLayoutManager()
    layoutManager.textContainer = textContainer
    let contentStorage = NSTextContentStorage()
    contentStorage.addTextLayoutManager(layoutManager)
    let textView = CodeBlockBackgroundTextView(frame: .zero, textContainer: textContainer)
    // ...
}
```

### Unit Test Results
```
Suite "CodeBlockStyling" - 7/7 passed
Suite "MarkdownTextStorageBuilder" - 32/32 passed
Total unit tests: 39/39 passing
```

### Build Status
```
swift build: Build complete! (0.41s)
```
