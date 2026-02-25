# Syntax Highlighting

## Overview

Tree-sitter-based token-level syntax coloring for fenced code blocks in 16 languages, rendered inside styled containers with language labels and hover-to-copy. The engine replaced an earlier Splash-based approach that only covered Swift. All 16 grammar binaries are statically linked via SPM -- no runtime file loading, no network, no configuration. Unsupported or untagged code blocks fall back to plain monospace text.

The feature spans two concerns: **token coloring** (tree-sitter parsing assigns foreground colors to keywords, strings, comments, etc.) and **code block presentation** (rounded-rect container, language label, copy button). Token coloring lives in `Core/Highlighting/`; container drawing lives in the Viewer layer via custom `NSTextView.drawBackground(in:)` and `NSAttributedString.Key` attributes.

## User Experience

- Fenced code blocks tagged with any of 16 languages render with token-level coloring (keywords, strings, comments, types, numbers, functions, operators, etc.).
- Recognized aliases: `js`, `ts`, `py`, `rb`, `sh`, `shell`, `yml`, `cpp`, `c++`. Lookup is case-insensitive.
- Each code block renders inside a rounded-rectangle container (6pt corners, 1pt border at 0.3 opacity, 12pt internal padding).
- When a language tag is present, a label appears above the code body inside the container.
- Hovering a code block reveals a copy button (top-right); clicking copies the raw code (no label, no color attributes) to the clipboard.
- Token colors update immediately on theme switch (Solarized Dark / Solarized Light) and use the Print palette when printing.
- Unsupported languages and untagged blocks render as plain monospace in the theme's `codeForeground` color, inside the same styled container.

## Architecture

**Data flow (TextKit 2 path):**
Markdown parser emits `.codeBlock(language:code:)`. `MarkdownTextStorageBuilder` calls `SyntaxHighlightEngine.highlight(code:language:syntaxColors:)`, which resolves the language via `TreeSitterLanguageMap`, parses with tree-sitter, executes highlight queries from `HighlightQueries`, maps captures through `TokenType` to `SyntaxColors`, and returns an `NSMutableAttributedString` with foreground color attributes. The builder wraps the result in container attributes (`CodeBlockAttributes.range`, `.colors`, `.rawCode`) and sets paragraph indents for padding. `CodeBlockBackgroundTextView` draws rounded-rect containers behind tagged ranges in `drawBackground(in:)`.

**Data flow (SwiftUI path):**
`CodeBlockView` calls `SyntaxHighlightEngine.highlight(...)` directly, converts the `NSMutableAttributedString` to `AttributedString`, and renders it inside a SwiftUI `ScrollView` with the same rounded-rect container and border overlay.

**Key types:**

| Type | Responsibility |
|------|----------------|
| `SyntaxHighlightEngine` | Stateless API: parse + query + color in one synchronous call. Parser and query created per call -- thread-safe by construction. |
| `TreeSitterLanguageMap` | Language tag/alias resolution to `LanguageConfig` (Language + query string). Case-insensitive, whitespace-trimmed. |
| `TokenType` | 13-case enum mapping tree-sitter capture names to `SyntaxColors` properties. Prefix-matched (e.g., `keyword.control` matches `keyword`). |
| `HighlightQueries` | Embedded `.scm` query strings for all 16 grammars as static `String` constants. |
| `CodeBlockAttributes` | Custom `NSAttributedString.Key` definitions: `.range` (block ID), `.colors` (NSColor carrier), `.rawCode` (plain text for clipboard). |
| `CodeBlockColorInfo` | `NSObject` subclass carrying resolved background/border `NSColor` values for the drawing code. |
| `CodeBlockBackgroundTextView` | `NSTextView` subclass. Enumerates `.codeBlockRange` in `drawBackground(in:)`, draws rounded-rect containers, manages copy button overlay and cursor rects. |
| `CodeBlockCopyButton` | SwiftUI hover-revealed copy button with checkmark confirmation animation. |
| `CodeBlockView` | Standalone SwiftUI code block (used outside the TextKit 2 pipeline). |

**Supported languages (16):**
Swift, Python, JavaScript, TypeScript, Rust, Go, Bash, JSON, YAML, HTML, CSS, C, C++, Ruby, Java, Kotlin.

## Implementation Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Engine statefulness | Stateless -- parser/query created per call | Thread-safe by construction with no shared mutable state. Tree-sitter object creation is sub-millisecond; caching adds concurrency complexity without meaningful gain. |
| Query embedding | String constants in `HighlightQueries.swift` | Eliminates runtime file loading, resource bundle configuration, and missing-file error handling. Queries are compile-time verifiable via tests. |
| Token type granularity | 13 cases (keyword, string, comment, type, number, function, property, preprocessor, operator, variable, constant, attribute, punctuation) | Balances tree-sitter's hundreds of node types against a manageable palette that fits within Solarized's 8-accent scheme. |
| Capture name mapping | Prefix match on first `.`-separated segment | Handles subcategories automatically (`keyword.control`, `string.regex`, `comment.documentation` all resolve via their base). New subcategories work without code changes. |
| Container drawing | Custom `NSTextView.drawBackground(in:)` with `NSAttributedString.Key` attributes | Preserves cross-block text selection. No external state needed during drawing -- theme colors travel with the text as attribute values. |
| Raw code as attribute | `CodeBlockAttributes.rawCode` stores trimmed, unformatted code | Copy button always copies plain text regardless of highlighting state. Decoupled from display attributes. |
| Base foreground color | `syntaxColors.variable` (standard foreground) | Tokens not captured by any query render in the neutral foreground color. Variables are the most common uncaptured token, so this keeps visual noise low. |

## Files

| File | Role |
|------|------|
| `mkdn/Core/Highlighting/SyntaxHighlightEngine.swift` | Public API: synchronous `highlight(code:language:syntaxColors:)` returning `NSMutableAttributedString?` |
| `mkdn/Core/Highlighting/TreeSitterLanguageMap.swift` | Language tag + alias resolution to `LanguageConfig`. 8 aliases, 16 canonical names. |
| `mkdn/Core/Highlighting/TokenType.swift` | Capture name to `SyntaxColors` mapping. 13 cases, 30 capture name entries in the lookup table. |
| `mkdn/Core/Highlighting/HighlightQueries.swift` | Embedded `.scm` highlight queries for 16 languages (~1200 lines total). |
| `mkdn/Core/Markdown/CodeBlockAttributes.swift` | Custom `NSAttributedString.Key` definitions (`.range`, `.colors`, `.rawCode`) and `CodeBlockColorInfo` carrier. |
| `mkdn/Features/Viewer/Views/CodeBlockBackgroundTextView.swift` | `NSTextView` subclass: container drawing, copy button overlay, cursor rect management. |
| `mkdn/Features/Viewer/Views/CodeBlockCopyButton.swift` | SwiftUI hover-to-copy button with checkmark confirmation. |
| `mkdn/Features/Viewer/Views/CodeBlockView.swift` | Standalone SwiftUI code block with tree-sitter highlighting (used outside TextKit 2 pipeline). |

## Dependencies

- **External**: `SwiftTreeSitter` (ChimeHQ), 16 grammar SPM packages (`TreeSitterSwift`, `TreeSitterPython`, `TreeSitterJavaScript`, `TreeSitterTypeScript`, `TreeSitterRust`, `TreeSitterGo`, `TreeSitterBash`, `TreeSitterJSON`, `TreeSitterYAML`, `TreeSitterHTML`, `TreeSitterCSS`, `TreeSitterC`, `TreeSitterCPP`, `TreeSitterRuby`, `TreeSitterJava`, `TreeSitterKotlin`). All statically linked, no runtime loading.
- **Internal**: `SyntaxColors` / `ThemeColors` (color palette per theme), `MarkdownTextStorageBuilder` (TextKit 2 rendering pipeline), `PlatformTypeConverter` (SwiftUI `Color` to `NSColor` bridge), `OverlayCoordinator` (positions copy button overlay).

## Testing

| Test File | Coverage |
|-----------|----------|
| `mkdnTests/Unit/Core/SyntaxHighlightEngineTests.swift` | All 16 languages produce non-nil output; unsupported/empty returns nil; text content preservation across languages; multiple distinct foreground colors in mixed-token code; keyword color verification (`func` gets keyword color); string literal color verification; `TokenType` capture name mapping for all 30 known entries, unknown names, and subcategory prefix resolution. |
| `mkdnTests/Unit/Core/TreeSitterLanguageMapTests.swift` | 16 canonical names resolve; `supportedLanguages` count and sort order; 8 aliases resolve to correct canonical config; case-insensitive lookup (mixed case variants); alias case insensitivity; unsupported language returns nil; empty string returns nil; whitespace-padded tags resolve correctly. |
| `mkdnTests/Unit/Core/CodeBlockStylingTests.swift` | `codeBlockRange` attribute present with non-empty ID; `codeBlockColors` correct per theme (both Solarized variants); paragraph indent values (headIndent, tailIndent = 12pt/-12pt); no per-run `backgroundColor`; Swift highlighting produces multiple foreground color runs with `NSColor`; unsupported language falls back to `codeForeground`; `rawCode` attribute carries trimmed code; raw code excludes language label text; language label shares block range ID with code body. |
