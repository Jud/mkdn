# Hypothesis Document: core-markdown-rendering
**Version**: 1.0.0 | **Created**: 2026-02-06T17:49Z | **Status**: VALIDATED

## Hypotheses

### HYP-001: SwiftUI Text with AttributedString .link attribute auto-opens URLs
**Risk Level**: MEDIUM
**Status**: CONFIRMED
**Statement**: SwiftUI Text view with AttributedString containing .link attributes automatically makes links tappable and opens them via the environment's openURL action (which defaults to NSWorkspace.shared.open on macOS).
**Context**: The design relies on this behavior for link interaction (D5). If links are not automatically interactive, the visitor would need to produce a richer inline model that separates link runs, and the view would need Button/Link wrappers or manual tap gestures.
**Validation Criteria**:
- CONFIRM if: Text(attributedString) with .link set on a substring renders interactive links that open in the default browser without custom gesture or openURL override.
- REJECT if: The link text renders but clicking does nothing, or requires explicit .environment(\.openURL, ...) override or manual gesture.
**Suggested Method**: CODE_EXPERIMENT + EXTERNAL_RESEARCH

### HYP-002: NSImage(contentsOf:) loads local images reliably on macOS 14+
**Risk Level**: MEDIUM
**Status**: CONFIRMED
**Statement**: NSImage(contentsOf: fileURL) works reliably for loading images from local file paths resolved relative to the open Markdown file's directory on macOS 14+.
**Context**: The design uses NSImage(contentsOf:) for local image loading in ImageBlockView (D1). If it fails for common formats or has sandbox restrictions, an alternative loading strategy would be needed.
**Validation Criteria**:
- CONFIRM if: NSImage(contentsOf: fileURL) successfully loads PNG, JPEG, and GIF files from the same directory as a Markdown file without sandbox permission issues.
- REJECT if: NSImage(contentsOf:) returns nil for valid image files, or sandbox restrictions prevent loading images from the Markdown file's directory without explicit user permission grants.
**Suggested Method**: CODE_EXPERIMENT

### HYP-003: swift-markdown parses GFM Strikethrough with default options
**Risk Level**: HIGH
**Status**: CONFIRMED
**Statement**: swift-markdown parses GFM Strikethrough nodes (~~text~~) into Strikethrough AST nodes with default parsing options (no special options flag needed).
**Context**: The design assumes Strikethrough nodes appear in the AST with default Document(parsing:) calls (D10). If strikethrough requires explicit parse options, MarkdownRenderer.parse() must be updated. If the Strikethrough type doesn't exist, the visitor must use regex-based detection.
**Validation Criteria**:
- CONFIRM if: Document(parsing: "~~deleted~~") produces an AST containing a Strikethrough node as a child of the paragraph's inline children.
- REJECT if: The parsed AST contains only plain Text nodes for ~~text~~, or swift-markdown does not export a Strikethrough type at all.
**Suggested Method**: CODE_EXPERIMENT + CODEBASE_ANALYSIS

## Validation Findings

### HYP-001 Findings
**Validated**: 2026-02-06T17:50Z
**Method**: CODE_EXPERIMENT + EXTERNAL_RESEARCH
**Result**: CONFIRMED

**Evidence**:

1. **API verification (code experiment)**: Created an AttributedString with `.link` set on a substring. Verified that the `.link` attribute is preserved in AttributedString runs and can be set on partial text ranges. Mixed text with `"Visit "` + `"our site"` (with .link) + `" for more."` correctly produces three runs where only the middle run carries the link attribute.

2. **SwiftUI Text link behavior (external research)**: Multiple authoritative sources confirm that SwiftUI 3+ (macOS 12+, iOS 15+) makes links in `Text(attributedString)` automatically interactive:
   - "SwiftUI 3 supports attributed string natively, including links that are tappable by default in any Text." (SwiftUI Recipes)
   - "When the user interacts with a link (in either a Text or Link view), SwiftUI will reach for the view openURL environment value." (Five Stars blog)
   - "The system will then receive and handle the URL, which will either open the default device browser and load a web page, or deep-link into another app." (Five Stars blog)
   - The default `openURL` implementation returns `.systemAction`, which on macOS delegates to `NSWorkspace.shared.open()`.

3. **No custom code needed**: The default behavior opens URLs in the system browser. Custom handling is only needed if the app wants to intercept link clicks (via `.environment(\.openURL, ...)` override), which is not required for the design.

4. **Platform compatibility**: macOS 12+ is required. The project targets macOS 14+, so this is fully compatible.

**Sources**:
- https://swiftuirecipes.com/blog/hyperlinks-in-swiftui-text
- https://www.fivestars.blog/articles/openurl-openurlaction/
- https://nilcoalescing.com/blog/SetCustomActionsForLinksInTextViews/

**Implications for Design**:
Design decision D5 is validated. No changes needed to the link handling approach. `Text(attributedString)` with `.link` attribute on link runs will work as designed. The visitor only needs to set `.link` and optional styling (foregroundColor, underlineStyle) on the AttributedString. No Button/Link wrappers or manual gestures are required.

---

### HYP-002 Findings
**Validated**: 2026-02-06T17:50Z
**Method**: CODE_EXPERIMENT
**Result**: CONFIRMED

**Evidence**:

1. **PNG loading**: `NSImage(contentsOf: URL(fileURLWithPath: "/tmp/.../test.png"))` successfully loaded a 10x10 PNG. Returned non-nil NSImage with size (10.0, 10.0).

2. **JPEG loading**: `NSImage(contentsOf: URL(fileURLWithPath: "/tmp/.../test.jpg"))` successfully loaded a 10x10 JPEG. Returned non-nil NSImage with size (10.0, 10.0).

3. **GIF loading**: `NSImage(contentsOf: URL(fileURLWithPath: "/tmp/.../test.gif"))` successfully loaded a 1x1 GIF. Returned non-nil NSImage with size (1.0, 1.0).

4. **Relative path resolution**: Resolving a relative path (`"test.png"`) against a "markdown file directory" URL via `URL.appendingPathComponent()` produced the correct absolute file URL, and `NSImage(contentsOf:)` loaded it successfully.

5. **Non-existent file handling**: `NSImage(contentsOf: URL(fileURLWithPath: "/tmp/does-not-exist.png"))` returned `nil` as expected, without crashing.

6. **Sandbox considerations**: The mkdn project is an SPM-based CLI/SwiftUI application with no App Sandbox entitlements. No `.entitlements` file exists in the project (verified via glob search). Without App Sandbox, `NSImage(contentsOf:)` can load files from any readable filesystem path. If the app were sandboxed in the future, user-opened files would still be accessible via security-scoped bookmarks, and relative paths within the same directory would work.

**Sources**:
- Code experiment output (all 6 tests passed)
- Glob search for `*.entitlements` in project root (no sandbox entitlements found)

**Implications for Design**:
Design decision D1 is validated. `NSImage(contentsOf:)` works reliably for PNG, JPEG, and GIF from local file paths. The ImageBlockView design can proceed as specified. The path security validation (NFR-004) using `standardizedFileURL` and prefix checking is a good defensive measure but not technically required by sandbox restrictions in the current app configuration.

---

### HYP-003 Findings
**Validated**: 2026-02-06T17:50Z
**Method**: CODE_EXPERIMENT + CODEBASE_ANALYSIS
**Result**: CONFIRMED

**Evidence**:

1. **Code experiment results**: Parsing `"~~deleted~~"` with `Document(parsing:)` (no options) produced the following AST:
   ```
   Document
   +-- Paragraph
       +-- Strikethrough
           +-- Text "deleted"
   ```
   The `Strikethrough` node appears as a child of `Paragraph`, wrapping the `Text` node.

2. **Mixed content parsing**: Parsing `"This has ~~deleted text~~ in it."` produced:
   ```
   Document
   +-- Paragraph
       +-- Text "This has "
       +-- Strikethrough
       |   +-- Text "deleted text"
       +-- Text " in it."
   ```
   Strikethrough is correctly isolated as an inline container among sibling Text nodes.

3. **Source code analysis -- parser always enables strikethrough**: In `CommonMarkConverter.swift` (line 625 of the swift-markdown checkout), the parser unconditionally attaches the strikethrough extension:
   ```swift
   cmark_parser_attach_syntax_extension(parser, cmark_find_syntax_extension("strikethrough"))
   ```
   This is not guarded by any `ParseOptions` flag. The `ParseOptions` struct (`ParseOptions.swift`) only defines: `.parseBlockDirectives`, `.parseSymbolLinks`, `.disableSmartOpts`, `.parseMinimalDoxygen`, `.disableSourcePosOpts` -- none related to strikethrough.

4. **Strikethrough type is public**: The `Strikethrough` struct in `swift-markdown` is declared as `public struct Strikethrough: RecurringInlineMarkup, BasicInlineContainer` (file: `Sources/Markdown/Inline Nodes/Inline Containers/Strikethrough.swift`). It exposes `.plainText`, `.accept(_:)`, and conforms to `InlineMarkup` protocols.

5. **Visitor integration**: The library's `MarkupVisitor` protocol includes `visitStrikethrough(_ strikethrough: Strikethrough)`, which means the project's `MarkdownVisitor` can handle it via `case let strikethrough as Strikethrough` in the `convertInline` switch.

**Sources**:
- Code experiment output (AST dump confirmed Strikethrough nodes)
- `.build/checkouts/swift-markdown/Sources/Markdown/Parser/CommonMarkConverter.swift:625` (unconditional extension attachment)
- `.build/checkouts/swift-markdown/Sources/Markdown/Parser/ParseOptions.swift` (no strikethrough option)
- `.build/checkouts/swift-markdown/Sources/Markdown/Inline Nodes/Inline Containers/Strikethrough.swift` (public type definition)

**Implications for Design**:
Design decision D10 is validated. The visitor can use `case let strikethrough as Strikethrough` directly. No parsing options need to be changed in `MarkdownRenderer.parse()` -- the current `Document(parsing: text)` call already produces Strikethrough nodes. The design note in section 3.9 of design.md ("Verify during implementation whether Strikethrough nodes appear in the AST with default parsing options") is answered: they do.

## Summary

| Hypothesis | Risk | Result | Implication |
|------------|------|--------|-------------|
| HYP-001: Text .link auto-opens URLs | MEDIUM | CONFIRMED | No custom link handling needed; .link attribute on AttributedString is sufficient |
| HYP-002: NSImage loads local images | MEDIUM | CONFIRMED | NSImage(contentsOf:) works for PNG/JPEG/GIF; no sandbox issues in current config |
| HYP-003: Strikethrough with default parsing | HIGH | CONFIRMED | No parsing options change needed; Strikethrough type is public and always parsed |
