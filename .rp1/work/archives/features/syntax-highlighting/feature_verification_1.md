# Feature Verification Report #1

**Generated**: 2026-02-06T19:26:00Z
**Feature ID**: syntax-highlighting
**Verification Scope**: all
**KB Context**: VERIFIED Loaded
**Field Notes**: Not available

## Executive Summary
- Overall Status: PARTIAL
- Acceptance Criteria: 15/21 verified (71%)
- Implementation Quality: HIGH
- Ready for Merge: NO (documentation tasks TD1 and TD2 incomplete; FR-008 AC-2 requires review)

## Field Notes Context
**Field Notes Available**: No

### Documented Deviations
None -- no field-notes.md file exists for this feature.

### Undocumented Deviations
1. **T1 used `@preconcurrency import Splash`**: The design did not mention this, but the tasks.md Implementation Summary for T1 documents it as a deviation needed for Swift 6 strict concurrency (Splash's TokenType lacks Sendable conformance). This is documented in tasks.md but not in a field-notes.md file.

## Acceptance Criteria Verification

### FR-001: Theme-Agnostic Output Format Naming
**AC-1**: No type, file, or symbol in the codebase contains "SolarizedOutputFormat".
- Status: VERIFIED
- Implementation: Codebase-wide grep for "SolarizedOutputFormat" returns zero results.
- Evidence: `grep -rn "SolarizedOutputFormat" --include="*.swift" .` produces no output. The type has been fully renamed.
- Field Notes: N/A
- Issues: None

**AC-2**: `ThemeOutputFormat` exists and is the sole syntax highlighting output format type.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/ThemeOutputFormat.swift`:1-39
- Evidence: `ThemeOutputFormat` is a struct conforming to `OutputFormat` and `Sendable`. It is the only `OutputFormat` conforming type in the codebase. `CodeBlockView.swift`:61 references `ThemeOutputFormat(` as the sole output format constructor.
- Field Notes: N/A
- Issues: None

### FR-002: Generic Token-to-Color Mapping
**AC-1**: `ThemeOutputFormat` initializer accepts a token-to-color map and a plain text color parameter.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/ThemeOutputFormat.swift`:7-8
- Evidence: `let plainTextColor: SwiftUI.Color` and `let tokenColorMap: [TokenType: SwiftUI.Color]` are stored properties initialized via memberwise init. The struct accepts any arbitrary color map with no theme-specific assumptions.
- Field Notes: N/A
- Issues: None

**AC-2**: Passing different color maps produces correspondingly different `AttributedString` output.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdnTests/Unit/Core/ThemeOutputFormatTests.swift`:89-111
- Evidence: Test `differentColorMaps()` creates two `ThemeOutputFormat` instances with different keyword colors (blue vs green), feeds the same token through both builders, and asserts that `runsA[0].foregroundColor != runsB[0].foregroundColor`. This test passes (54/54 tests pass).
- Field Notes: N/A
- Issues: None

### FR-003: Swift Code Block Tokenized Highlighting
**AC-1**: A fenced code block tagged `swift` renders with at least 3 visually distinct colors for different token types.
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/CodeBlockView.swift`:53-76
- Evidence: The `highlightedCode` property creates a `ThemeOutputFormat` with 9 distinct token-to-color mappings sourced from `syntaxColors`. The SolarizedDark theme provides 8 distinct accent colors (green, cyan, base01, yellow, magenta, blue, orange, red) for the 8 SyntaxColors fields, guaranteeing well more than 3 visually distinct colors. However, actual visual rendering requires manual verification in the running app.
- Field Notes: N/A
- Issues: Requires visual verification to confirm rendering in the actual app window.

**AC-2**: The rendered output uses the active theme's `SyntaxColors` values.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/CodeBlockView.swift`:60-74
- Evidence: Line 60 reads `let syntaxColors = appState.theme.syntaxColors`, then lines 63-73 construct the `tokenColorMap` using `syntaxColors.keyword`, `.string`, `.type`, `.function`, `.number`, `.comment`, `.property`, `.preprocessor`. The `appState` is accessed via `@Environment(AppState.self)` (line 9), which is `@Observable` -- any change to `appState.theme` triggers a view re-render, re-evaluating `highlightedCode` with the new theme's colors.
- Field Notes: N/A
- Issues: None

### FR-004: Non-Swift Code Block Fallback
**AC-1**: A code block tagged `python` renders entirely in `codeForeground` color with a monospaced font.
- Status: MANUAL_REQUIRED (code logic verified)
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/CodeBlockView.swift`:53-57
- Evidence: The guard on line 53 checks `language == "swift"` -- any non-"swift" language (including "python") falls through to the else branch, which creates an `AttributedString(trimmed)` with `foregroundColor = colors.codeForeground` (lines 54-56). The body uses `.font(.system(.body, design: .monospaced))` on line 30. Visual confirmation required.
- Field Notes: N/A
- Issues: None in code logic.

**AC-2**: A code block with no language tag renders entirely in `codeForeground` color with a monospaced font.
- Status: MANUAL_REQUIRED (code logic verified)
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/CodeBlockView.swift`:53-57
- Evidence: When `language` is `nil`, `language == "swift"` is false, so the guard's else branch executes, applying `codeForeground` color. The `MarkdownVisitor` (line 25) passes `codeBlock.language?.lowercased()` which is `nil` when no language tag is present.
- Field Notes: N/A
- Issues: None in code logic.

**AC-3**: No tokenization or color differentiation is attempted for non-Swift blocks.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/CodeBlockView.swift`:53-57
- Evidence: The `guard language == "swift" else` on line 53 ensures Splash's `SyntaxHighlighter` (lines 75-76) is never reached for non-Swift blocks. The fallback creates a single-color `AttributedString` directly, with no tokenization.
- Field Notes: N/A
- Issues: None

### FR-005: Language Label Display
**AC-1**: A fenced code block with language tag "swift" displays "swift" as a label above the code content.
- Status: MANUAL_REQUIRED (code logic verified)
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/CodeBlockView.swift`:17-25
- Evidence: Lines 18-25 conditionally render `Text(language)` when `language` is non-nil and non-empty. The text uses `.font(.caption.monospaced())` and `.foregroundColor(colors.foregroundSecondary)`. For a "swift" tagged block, `language` is "swift" (lowercased by MarkdownVisitor line 25), so "swift" will be displayed above the code.
- Field Notes: N/A
- Issues: None in code logic.

**AC-2**: A fenced code block with no language tag displays no language label.
- Status: MANUAL_REQUIRED (code logic verified)
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/CodeBlockView.swift`:18
- Evidence: The `if let language, !language.isEmpty` check on line 18 guards the label rendering. When `language` is `nil` (no tag), the optional binding fails and no label is shown.
- Field Notes: N/A
- Issues: None in code logic.

### FR-006: Horizontal Scrollability for Long Lines
**AC-1**: A code block containing a line wider than the viewport displays a horizontal scroll indicator.
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/CodeBlockView.swift`:28
- Evidence: Line 28 wraps code content in `ScrollView(.horizontal, showsIndicators: true)`. The `showsIndicators: true` parameter enables scroll indicator display. Visual confirmation required in the running app.
- Field Notes: N/A
- Issues: None in code logic.

**AC-2**: The user can scroll horizontally to reveal the full line content.
- Status: MANUAL_REQUIRED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/CodeBlockView.swift`:28
- Evidence: `ScrollView(.horizontal, ...)` provides horizontal scrolling. The `Text` inside is not constrained to wrap, so long lines will extend beyond the viewport and be scrollable.
- Field Notes: N/A
- Issues: Requires manual testing with a long-line code block.

**AC-3**: Lines are not wrapped.
- Status: MANUAL_REQUIRED (code logic verified)
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/CodeBlockView.swift`:28-33
- Evidence: The `Text` view is placed inside `ScrollView(.horizontal, ...)` without any `.lineLimit()` or `.fixedSize()` modifier that would force wrapping. SwiftUI `Text` inside a horizontal `ScrollView` naturally avoids wrapping because it is not width-constrained. Visual confirmation required.
- Field Notes: N/A
- Issues: None in code logic.

### FR-007: Theme-Reactive Re-Highlighting
**AC-1**: After switching from Solarized Dark to Solarized Light, all code block colors reflect the Light theme's `SyntaxColors`.
- Status: MANUAL_REQUIRED (code logic verified)
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/CodeBlockView.swift`:9, 60-74; `/Users/jud/Projects/mkdn/mkdn/App/AppState.swift`:26
- Evidence: `CodeBlockView` accesses `appState` via `@Environment(AppState.self)` (line 9). `AppState` is `@Observable` with `var theme: AppTheme = .solarizedDark` (AppState.swift:26). When `theme` changes, the `@Observable` macro triggers view invalidation, causing `highlightedCode` to recompute with the new theme's `syntaxColors`. No stale caching is present. Visual confirmation required.
- Field Notes: N/A
- Issues: None in code logic.

**AC-2**: No manual refresh, scroll, or re-open is required to see updated colors.
- Status: MANUAL_REQUIRED (code logic verified)
- Implementation: Same as AC-1
- Evidence: The `@Observable` + `@Environment` pattern provides automatic SwiftUI view updates when `appState.theme` changes. The `highlightedCode` property is a computed property (not cached), so it re-evaluates each time the view's body is recomputed.
- Field Notes: N/A
- Issues: None in code logic.

### FR-008: Complete Token Type Coverage in Builder
**AC-1**: Each of the 9 Splash `TokenType` cases has an explicit mapping to a `SyntaxColors` field.
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/CodeBlockView.swift`:63-73
- Evidence: The `tokenColorMap` dictionary maps all 9 standard `TokenType` cases:
  1. `.keyword` -> `syntaxColors.keyword`
  2. `.string` -> `syntaxColors.string`
  3. `.type` -> `syntaxColors.type`
  4. `.call` -> `syntaxColors.function`
  5. `.number` -> `syntaxColors.number`
  6. `.comment` -> `syntaxColors.comment`
  7. `.property` -> `syntaxColors.property`
  8. `.dotAccess` -> `syntaxColors.property`
  9. `.preprocessing` -> `syntaxColors.preprocessor`
  The 10th case `.custom(String)` is not standard and falls back to `plainTextColor` via `tokenColorMap[type] ?? plainTextColor` in ThemeOutputFormat.swift:21.
- Field Notes: N/A
- Issues: None

**AC-2**: Both Solarized Dark and Solarized Light themes provide distinct, non-identical `SyntaxColors` values.
- Status: PARTIAL
- Implementation: `/Users/jud/Projects/mkdn/mkdn/UI/Theme/SolarizedDark.swift`:38-47; `/Users/jud/Projects/mkdn/mkdn/UI/Theme/SolarizedLight.swift`:38-47
- Evidence: Both themes define `SyntaxColors` instances. However, per the Solarized color specification, the accent colors (yellow, orange, red, magenta, violet, blue, cyan, green) are identical between dark and light variants. The only field that could differ is `comment`: Dark uses `base01` (0.345, 0.431, 0.459) and Light uses `base1` (0.345, 0.431, 0.459) -- but these resolve to the same RGB values. This means the two `SyntaxColors` instances are functionally identical. While this is correct per the Solarized specification (accent colors are theme-invariant), it does not satisfy the literal requirement of "distinct, non-identical SyntaxColors values."
- Field Notes: N/A
- Issues: The SyntaxColors values are identical between themes. This is technically correct per Solarized's design (where backgrounds/foregrounds change but accents stay the same), but it does not meet the literal AC as written. The visual distinction comes from the different background colors (`codeBackground`), not from different syntax colors.

### NFR-006: No Solarized-Specific Naming in Highlighting Code Path
- Status: VERIFIED
- Implementation: All highlighting adapter code is in `ThemeOutputFormat.swift` with no theme-specific naming.
- Evidence: grep for "Solarized" in `ThemeOutputFormat.swift` and `CodeBlockView.swift` (the highlighting code path) returns zero results. The `SolarizedDark` and `SolarizedLight` names correctly remain in the theme definition layer (`UI/Theme/`), which is appropriate per design decision D5.
- Field Notes: N/A
- Issues: None

### NFR-007: Sendable Compliance
- Status: VERIFIED
- Implementation: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/ThemeOutputFormat.swift`:1, 6, 14
- Evidence: Line 6: `struct ThemeOutputFormat: OutputFormat, Sendable`. Line 14: `struct Builder: OutputBuilder, Sendable`. Both explicitly conform to `Sendable`. The `@preconcurrency import Splash` on line 1 handles Splash's `TokenType` not having `Sendable` conformance. Project compiles cleanly under Swift 6 strict concurrency with `swift build`.
- Field Notes: N/A
- Issues: None

### NFR-008: SwiftLint Strict Mode
- Status: NOT VERIFIED
- Implementation: N/A
- Evidence: `swiftlint` command is not available in the current environment. Cannot verify SwiftLint compliance.
- Field Notes: N/A
- Issues: Unable to run `swiftlint lint` -- the tool is not installed or not in PATH.

## Implementation Gap Analysis

### Missing Implementations
1. **TD1 (modules.md update)**: `ThemeOutputFormat.swift` is not listed in the `Core/Markdown/` file inventory table in `.rp1/context/modules.md`. The table currently lists only `MarkdownRenderer.swift`, `MarkdownBlock.swift`, and `MarkdownVisitor.swift`.
2. **TD2 (architecture.md update)**: The Code Blocks pipeline in `.rp1/context/architecture.md` does not mention `ThemeOutputFormat` by name. It currently reads: "Code block with language tag -> Splash SyntaxHighlighter -> AttributedString with theme colors -> SwiftUI Text."

### Partial Implementations
1. **FR-008 AC-2**: SyntaxColors values are functionally identical between Solarized Dark and Solarized Light. While this is correct per the Solarized color specification (accent colors are invariant across dark/light), it does not satisfy the literal requirement of "distinct, non-identical" values. The visual distinction when switching themes comes from the different `codeBackground` and `codeForeground` colors, not from different syntax colors.

### Implementation Issues
- None. All code implementations are clean, correct, and follow established patterns.

## Code Quality Assessment

**Overall Quality: HIGH**

The implementation demonstrates excellent code quality across all dimensions:

1. **Separation of Concerns**: `ThemeOutputFormat` is correctly extracted into its own file in `Core/Markdown/`, separating the Splash adapter from the view layer. The theme definitions remain in `UI/Theme/` where they belong.

2. **Swift 6 Concurrency**: Explicit `Sendable` conformance on both `ThemeOutputFormat` and `Builder`. The `@preconcurrency import Splash` pragmatically handles the third-party dependency's lack of Sendable conformance without compromising safety.

3. **Pattern Consistency**: The implementation follows all project patterns documented in `patterns.md`:
   - Uses `@Observable` (not ObservableObject)
   - Uses `@Environment(AppState.self)` for theme access
   - Tests use Swift Testing (`@Suite`, `@Test`, `#expect`)
   - No force unwrapping in production code

4. **Test Quality**: 6 focused unit tests covering token coloring, fallback, plain text, whitespace, build output, and theme reactivity. Tests validate app-specific behavior (the mapping logic) rather than library behavior (Splash tokenization). All 54 tests pass (6 new + 48 existing).

5. **Minimal Diff**: The refactor is surgical -- extract, rename, add tests. No unnecessary changes. CodeBlockView's logic, layout, and styling are unchanged.

6. **Documentation**: Code comments explain the `highlightedCode` property's behavior, including the rationale for non-Swift fallback (BR-001 reference).

## Recommendations

1. **Complete TD1**: Add `ThemeOutputFormat.swift` to the `Core/Markdown/` file inventory in `/Users/jud/Projects/mkdn/.rp1/context/modules.md`. Suggested entry: `| ThemeOutputFormat.swift | Splash OutputFormat adapter: token-to-color mapping |`

2. **Complete TD2**: Update the Code Blocks pipeline description in `/Users/jud/Projects/mkdn/.rp1/context/architecture.md` to mention `ThemeOutputFormat` by name. Suggested text: "Code block with language tag -> ThemeOutputFormat (token-to-color mapping) -> Splash SyntaxHighlighter -> AttributedString with theme colors -> SwiftUI Text"

3. **Review FR-008 AC-2**: The SyntaxColors values being identical between themes is correct per the Solarized specification. Consider either:
   - (a) Accepting this as-is and noting that the Solarized design intentionally shares accent colors across variants, or
   - (b) Updating the Light theme's `comment` color to use a different base value (e.g., `base01` instead of `base1`, though they happen to be the same RGB in the current implementation).
   - (c) Updating the acceptance criterion to acknowledge that Solarized's accent palette is theme-invariant by design.

4. **Install SwiftLint**: Ensure `swiftlint` is available for CI/CD or local verification. NFR-008 cannot be verified without it.

5. **Perform Manual Visual Verification**: The following acceptance criteria require visual testing in the running application:
   - FR-003 AC-1: Swift code blocks display 3+ distinct colors
   - FR-004 AC-1/AC-2: Non-Swift and untagged blocks use codeForeground
   - FR-005 AC-1/AC-2: Language label presence/absence
   - FR-006 AC-1/AC-2/AC-3: Horizontal scrolling and no wrapping
   - FR-007 AC-1/AC-2: Theme switch re-highlighting

## Verification Evidence

### ThemeOutputFormat.swift (complete file)
**Path**: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/ThemeOutputFormat.swift`

```swift
@preconcurrency import Splash
import SwiftUI

struct ThemeOutputFormat: OutputFormat, Sendable {
    let plainTextColor: SwiftUI.Color
    let tokenColorMap: [TokenType: SwiftUI.Color]

    func makeBuilder() -> Builder {
        Builder(plainTextColor: plainTextColor, tokenColorMap: tokenColorMap)
    }

    struct Builder: OutputBuilder, Sendable {
        let plainTextColor: SwiftUI.Color
        let tokenColorMap: [TokenType: SwiftUI.Color]
        var result = AttributedString()

        mutating func addToken(_ token: String, ofType type: TokenType) {
            var attributed = AttributedString(token)
            attributed.foregroundColor = tokenColorMap[type] ?? plainTextColor
            result.append(attributed)
        }

        mutating func addPlainText(_ text: String) {
            var attributed = AttributedString(text)
            attributed.foregroundColor = plainTextColor
            result.append(attributed)
        }

        mutating func addWhitespace(_ whitespace: String) {
            result.append(AttributedString(whitespace))
        }

        func build() -> AttributedString {
            result
        }
    }
}
```

### CodeBlockView.swift highlightedCode property (highlighting logic)
**Path**: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/CodeBlockView.swift:50-77`

```swift
private var highlightedCode: AttributedString {
    let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)

    guard language == "swift" else {
        var result = AttributedString(trimmed)
        result.foregroundColor = colors.codeForeground
        return result
    }

    let syntaxColors = appState.theme.syntaxColors
    let outputFormat = ThemeOutputFormat(
        plainTextColor: syntaxColors.comment,
        tokenColorMap: [
            .keyword: syntaxColors.keyword,
            .string: syntaxColors.string,
            .type: syntaxColors.type,
            .call: syntaxColors.function,
            .number: syntaxColors.number,
            .comment: syntaxColors.comment,
            .property: syntaxColors.property,
            .dotAccess: syntaxColors.property,
            .preprocessing: syntaxColors.preprocessor,
        ]
    )
    let highlighter = SyntaxHighlighter(format: outputFormat)
    return highlighter.highlight(trimmed)
}
```

### Token Type Mapping Verification
**Splash TokenType** (10 cases total) vs **CodeBlockView tokenColorMap** (9 entries):

| TokenType | Mapped To | SyntaxColors Field | Status |
|-----------|-----------|-------------------|--------|
| `.keyword` | `syntaxColors.keyword` | `keyword` | Mapped |
| `.string` | `syntaxColors.string` | `string` | Mapped |
| `.type` | `syntaxColors.type` | `type` | Mapped |
| `.call` | `syntaxColors.function` | `function` | Mapped |
| `.number` | `syntaxColors.number` | `number` | Mapped |
| `.comment` | `syntaxColors.comment` | `comment` | Mapped |
| `.property` | `syntaxColors.property` | `property` | Mapped |
| `.dotAccess` | `syntaxColors.property` | `property` | Mapped |
| `.preprocessing` | `syntaxColors.preprocessor` | `preprocessor` | Mapped |
| `.custom(String)` | Falls back to `plainTextColor` | N/A | Fallback |

### SyntaxColors Comparison (Dark vs Light)

| Field | SolarizedDark | SolarizedLight | Identical? |
|-------|--------------|----------------|------------|
| keyword | green (0.522, 0.600, 0.000) | green (0.522, 0.600, 0.000) | Yes |
| string | cyan (0.165, 0.631, 0.596) | cyan (0.165, 0.631, 0.596) | Yes |
| comment | base01 (0.345, 0.431, 0.459) | base1 (0.345, 0.431, 0.459) | Yes |
| type | yellow (0.710, 0.537, 0.000) | yellow (0.710, 0.537, 0.000) | Yes |
| number | magenta (0.827, 0.212, 0.510) | magenta (0.827, 0.212, 0.510) | Yes |
| function | blue (0.149, 0.545, 0.824) | blue (0.149, 0.545, 0.824) | Yes |
| property | orange (0.796, 0.294, 0.086) | orange (0.796, 0.294, 0.086) | Yes |
| preprocessor | red (0.863, 0.196, 0.184) | red (0.863, 0.196, 0.184) | Yes |

### Test Results
All 54 tests pass, including 6 new ThemeOutputFormat tests:

```
Test run with 54 tests passed after 0.006 seconds.
Suite "ThemeOutputFormat" passed after 0.004 seconds.
```

### Build Verification
```
Build complete! (1.46s)
```
No warnings, no errors. Swift 6 strict concurrency satisfied.
