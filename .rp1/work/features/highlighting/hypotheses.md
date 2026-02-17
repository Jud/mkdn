# Hypothesis Document: highlighting
**Version**: 1.0.0 | **Created**: 2026-02-17T09:30:00Z | **Status**: VALIDATED

## Hypotheses

### HYP-001: SPM-compatible Tree-Sitter Grammar Packages Exist for All 16 Target Languages
**Risk Level**: HIGH
**Status**: CONFIRMED
**Statement**: SPM-compatible packages exist for all 16 target language grammars (Swift, Python, JavaScript, TypeScript, Rust, Go, Bash/Shell, JSON, YAML, HTML, CSS, C, C++, Ruby, Java, Kotlin) with the expected C function names and Package.swift manifests. Check the tree-sitter-grammars GitHub org and fwcd for Kotlin.
**Context**: The highlighting feature requires tree-sitter grammars for all target languages to be available as SPM dependencies. If any are missing, alternative solutions or custom packaging would be needed.
**Validation Criteria**:
- CONFIRM if: All 16 language grammars have SPM-compatible packages with Package.swift manifests and the expected `tree_sitter_{lang}` C entry point functions
- REJECT if: One or more grammars lack SPM packaging or have incompatible build configurations
**Suggested Method**: EXTERNAL_RESEARCH

### HYP-002: SwiftTreeSitter Query API Supports Synchronous Iteration with Swift 6 Concurrency
**Risk Level**: HIGH
**Status**: CONFIRMED
**Statement**: SwiftTreeSitter's Query and QueryCursor API supports synchronous iteration of highlight captures with capture name resolution, compatible with Swift 6 strict concurrency. Check ChimeHQ/SwiftTreeSitter latest stable.
**Context**: The highlighting engine needs to run tree-sitter queries to extract syntax tokens, then map capture names to highlight styles. This must work under Swift 6 strict concurrency without data races.
**Validation Criteria**:
- CONFIRM if: SwiftTreeSitter provides Query/QueryCursor types that allow synchronous iteration over captures with name resolution, and these types are Sendable or safely usable under strict concurrency
- REJECT if: The API requires async/callback patterns incompatible with synchronous rendering, or types have concurrency safety issues under Swift 6
**Suggested Method**: EXTERNAL_RESEARCH

### HYP-003: Tree-Sitter Swift Grammar Token Quality Equals or Exceeds Splash
**Risk Level**: MEDIUM
**Status**: CONFIRMED
**Statement**: Tree-sitter's Swift grammar produces token quality equal to or better than Splash for Swift code highlighting. Compare tree-sitter Swift grammar highlight queries against Splash's token types for coverage of keywords, types, functions, strings, comments, @attributes, number literals, and operators.
**Context**: The project currently uses Splash for syntax highlighting. Switching to tree-sitter must not regress Swift highlighting quality, which is the primary language for the target audience.
**Validation Criteria**:
- CONFIRM if: Tree-sitter Swift highlight queries cover all token categories that Splash covers (keywords, types, functions, strings, comments, @attributes, number literals, operators) with equal or better granularity
- REJECT if: Tree-sitter Swift grammar has significant gaps in token coverage compared to Splash (missing major categories or significantly less granular)
**Suggested Method**: EXTERNAL_RESEARCH

## Validation Findings

### HYP-001 Findings
**Validated**: 2026-02-17T15:15:00Z
**Method**: EXTERNAL_RESEARCH
**Result**: CONFIRMED

**Evidence**:

The SwiftTreeSitter README (now at `tree-sitter/swift-tree-sitter` on GitHub) maintains a comprehensive table of 40+ language parsers with SPM support. All 16 target languages have been verified to have `Package.swift` manifests:

| Language | Repository | SPM |
|----------|-----------|-----|
| Swift | alex-pinkus/tree-sitter-swift | Yes |
| Python | tree-sitter/tree-sitter-python | Yes |
| JavaScript | tree-sitter/tree-sitter-javascript | Yes |
| TypeScript | tree-sitter/tree-sitter-typescript | Yes |
| Rust | tree-sitter/tree-sitter-rust | Yes |
| Go | tree-sitter/tree-sitter-go | Yes |
| Bash | tree-sitter/tree-sitter-bash | Yes |
| JSON | tree-sitter/tree-sitter-json | Yes |
| YAML | mattmassicotte/tree-sitter-yaml | Yes |
| HTML | tree-sitter/tree-sitter-html | Yes |
| CSS | tree-sitter/tree-sitter-css | Yes |
| C | tree-sitter/tree-sitter-c | Yes |
| C++ | tree-sitter/tree-sitter-cpp | Yes |
| Ruby | tree-sitter/tree-sitter-ruby | Yes |
| Java | tree-sitter/tree-sitter-java | Yes |
| Kotlin | fwcd/tree-sitter-kotlin | Yes |

All grammar packages follow the standard tree-sitter convention of exposing a C function named `tree_sitter_{language}` as the parser entry point. The SPM packages wrap the C parser source (`src/parser.c`, optionally `src/scanner.c`) with Swift bindings via a public headers path at `bindings/swift/`, and include query resources (highlights.scm, etc.) in their `queries/` directory. The Package.swift pattern (verified via `tree-sitter-grammars/tree-sitter-objc` as a reference) depends on SwiftTreeSitter >= 0.8.0, uses C11 standard, and exposes a library target with the parser name in PascalCase (e.g., `TreeSitterPython`).

Note: YAML is maintained by `mattmassicotte` (the ChimeHQ maintainer) rather than the `tree-sitter` org, but has full SPM support. Kotlin is maintained by `fwcd` and confirmed to have Package.swift.

**Sources**:
- https://github.com/tree-sitter/swift-tree-sitter (README language table)
- https://github.com/fwcd/tree-sitter-kotlin (Kotlin grammar with Package.swift)
- https://github.com/tree-sitter/tree-sitter-python (Package.swift confirmed)
- https://github.com/tree-sitter/tree-sitter-java (Package.swift confirmed)
- https://github.com/tree-sitter-grammars/tree-sitter-objc/blob/master/Package.swift (reference SPM pattern)

**Implications for Design**:
All 16 grammars can be added as standard SPM dependencies in `Package.swift`. The `TreeSitterLanguageMap` component in the design can map language identifier strings to their corresponding grammar packages without requiring any custom C wrapper code. The consistent `tree_sitter_{lang}` entry point convention means `Language` initialization is uniform across all grammars.

---

### HYP-002 Findings
**Validated**: 2026-02-17T15:15:00Z
**Method**: EXTERNAL_RESEARCH
**Result**: CONFIRMED

**Evidence**:

SwiftTreeSitter (latest stable: v0.9.0, released November 2025) provides a fully synchronous Query/QueryCursor API with capture name resolution, and the core types have explicit Sendable conformance.

**Query class** (`public final class Query: Sendable`):
- Initializers: `init(language:data:)`, `init(language:url:)` -- construct from .scm query data
- Execution: `execute(node:in:) -> QueryCursor` -- synchronous, returns cursor immediately
- Name resolution: `captureName(for id: Int) -> String?` -- resolves capture index to name string (e.g., `0` -> `"keyword"`)
- Predicate access: `predicates(for patternIndex:) -> [Predicate]`

**QueryCursor class** (`public final class QueryCursor`):
- Conforms to `Sequence` and `IteratorProtocol`
- Iteration: `next() -> QueryMatch?` and `nextCapture() -> QueryCapture?` -- fully synchronous, no async/await
- Range filtering: `setByteRange()`, `setRange(NSRange)`, `setPointRange()` for limiting query scope
- The `Sequence` conformance means standard `for match in cursor` iteration works

**QueryCapture struct**:
- `node: Node` -- the syntax node
- `name: String?` -- the capture name (e.g., `"keyword"`, `"type"`, `"function.call"`)
- `nameComponents: [String]` -- dot-separated parts for hierarchical matching
- `range: NSRange` -- byte range in source text
- Conforms to `Comparable`

**Swift 6 Concurrency Compatibility**:
- `Query` is explicitly `Sendable` -- can be safely shared across isolation domains
- The Package.swift uses `.enableExperimentalFeature("StrictConcurrency")` on all targets, meaning the library is compiled with strict concurrency checking enabled
- Swift tools version is 5.9, which means it uses the `StrictConcurrency` experimental feature rather than Swift 6 language mode, but the effect is the same: all concurrency violations are caught at compile time
- `LanguageConfiguration` (introduced in v0.8.0) provides structured loading of highlight queries from grammar SPM packages

**Workflow for highlighting**:
```swift
let query = try Query(language: language, data: highlightsData)
let cursor = query.execute(node: tree.rootNode!, in: tree)
for match in cursor {
    for capture in match.captures {
        let name = capture.name  // e.g., "keyword", "type"
        let range = capture.range // NSRange
        // Apply styling based on name -> TokenType mapping
    }
}
```

This is entirely synchronous and compatible with the existing `MarkdownTextStorageBuilder` pipeline.

**Sources**:
- https://github.com/ChimeHQ/SwiftTreeSitter/blob/main/Sources/SwiftTreeSitter/Query.swift (Query API source)
- https://github.com/ChimeHQ/SwiftTreeSitter/releases/tag/0.8.0 (v0.8.0 Sendable conformances)
- https://github.com/tree-sitter/swift-tree-sitter/releases (v0.9.0 latest)
- https://github.com/tree-sitter/swift-tree-sitter/blob/main/Package.swift (StrictConcurrency enabled)

**Implications for Design**:
The `SyntaxHighlightEngine` can use `Query` and `QueryCursor` synchronously in the rendering pipeline without any concurrency hazards. `Query` objects can be cached as `Sendable` values. The `captureName(for:)` method on `Query` or the `name` property on `QueryCapture` provides direct capture name resolution for mapping to `TokenType`. No async bridging or actor isolation is needed for the highlight execution path. The `LanguageConfiguration` type simplifies loading bundled highlight queries from grammar packages.

---

### HYP-003 Findings
**Validated**: 2026-02-17T15:15:00Z
**Method**: EXTERNAL_RESEARCH
**Result**: CONFIRMED

**Evidence**:

**Splash TokenType coverage** (from `TokenType.swift` in the project's `.build/checkouts/`):

| Splash TokenType | Description |
|-----------------|-------------|
| `.keyword` | Keywords (`if`, `class`, `let`) and attributes (`@available`) |
| `.string` | String literals |
| `.type` | Type references |
| `.call` | Function/method calls |
| `.number` | Integer and floating-point numbers |
| `.comment` | Single-line and multi-line comments |
| `.property` | Property access (`object.property`) |
| `.dotAccess` | Dot notation symbols (`.myCase`) |
| `.preprocessing` | Preprocessor symbols (`#if`) |
| `.custom(String)` | Arbitrary custom types (unused in SwiftGrammar) |

Splash's `SwiftGrammar` implements 13 syntax rules mapping to these 9 token types.

**Tree-sitter Swift grammar capture coverage** (from `alex-pinkus/tree-sitter-swift` `highlights.scm`, 87 rules, 39+ unique captures):

| Category | Tree-sitter Captures | Splash Equivalent |
|----------|---------------------|-------------------|
| Keywords | `@keyword`, `@keyword.function`, `@keyword.modifier`, `@keyword.type`, `@keyword.coroutine`, `@keyword.directive`, `@keyword.import`, `@keyword.repeat`, `@keyword.conditional`, `@keyword.conditional.ternary`, `@keyword.exception`, `@keyword.return` | `.keyword` (single type) |
| Types | `@type`, `@constructor` | `.type` |
| Functions | `@function.call`, `@function.method`, `@function.macro` | `.call` |
| Strings | `@string`, `@string.escape`, `@string.regexp` | `.string` |
| Comments | `@comment`, `@comment.documentation`, `@spell` | `.comment` |
| Attributes | `@attribute` | `.keyword` (conflated) |
| Numbers | `@number`, `@number.float`, `@boolean` | `.number` |
| Operators | `@operator` | Not covered by Splash |
| Variables | `@variable`, `@variable.builtin`, `@variable.parameter`, `@variable.member` | `.property` (partial) |
| Punctuation | `@punctuation.delimiter`, `@punctuation.bracket`, `@punctuation.special` | Not covered by Splash |
| Labels | `@label` | Not covered by Splash |
| Constants | `@constant.builtin`, `@constant.macro` | Not covered by Splash |
| Characters | `@character.special` | Not covered by Splash |

**Comparison summary**:

Tree-sitter's Swift grammar provides **strictly superior** token coverage compared to Splash:

1. **Keywords**: Tree-sitter distinguishes 12 keyword subcategories (function keywords, control flow, imports, etc.) vs. Splash's single `.keyword` type. This enables finer-grained coloring.
2. **Attributes**: Tree-sitter has a dedicated `@attribute` capture for `@available`, `@MainActor`, etc. Splash conflates these with `.keyword`.
3. **Operators**: Tree-sitter has explicit `@operator` coverage. Splash has no operator tokenization at all.
4. **Documentation comments**: Tree-sitter distinguishes `@comment.documentation` from regular `@comment`. Splash treats all comments identically.
5. **String escapes**: Tree-sitter provides `@string.escape` for `\n`, `\(...)` etc. Splash treats entire strings uniformly.
6. **Variables/parameters**: Tree-sitter distinguishes `@variable.parameter`, `@variable.builtin` (`self`), and `@variable.member`. Splash has limited `.property` coverage.
7. **Booleans**: Tree-sitter has explicit `@boolean` capture. Splash does not distinguish booleans.
8. **Punctuation**: Tree-sitter tokenizes brackets, delimiters, and special punctuation. Splash does not.
9. **Preprocessing**: Both cover this (`@keyword.directive` vs `.preprocessing`).

Every token category that Splash covers is also covered by tree-sitter, with equal or greater granularity. Tree-sitter additionally covers 6+ categories that Splash lacks entirely (operators, punctuation, labels, constants, boolean literals, character specials).

**Sources**:
- https://github.com/alex-pinkus/tree-sitter-swift (Swift grammar repo)
- https://raw.githubusercontent.com/alex-pinkus/tree-sitter-swift/main/queries/highlights.scm (highlight queries)
- https://github.com/JohnSundell/Splash/blob/master/Sources/Splash/Grammar/SwiftGrammar.swift (Splash rules)
- `/Users/jud/Projects/mkdn/.build/checkouts/Splash/Sources/Splash/Tokenizing/TokenType.swift` (Splash TokenType enum, 9 cases + custom)

**Implications for Design**:
The switch from Splash to tree-sitter for Swift highlighting will not regress quality -- it will improve it. The design's `TokenType` enum should leverage tree-sitter's finer granularity (e.g., separate `attribute` from `keyword`, add `operator` support). The existing `ThemeOutputFormat` mapping of Splash's 9 token types can be expanded to the design's proposed 14 token types without losing any current highlighting capability. The `@attribute` capture is particularly valuable for Swift developers who heavily use property wrappers and macros.

---

## Summary
| Hypothesis | Risk | Result | Implication |
|------------|------|--------|-------------|
| HYP-001 | HIGH | CONFIRMED | All 16 grammar packages have SPM support with Package.swift; can be added as standard dependencies |
| HYP-002 | HIGH | CONFIRMED | Query/QueryCursor API is synchronous, Sendable, and compatible with Swift 6 strict concurrency |
| HYP-003 | MEDIUM | CONFIRMED | Tree-sitter Swift grammar has 39+ capture types vs Splash's 9; strictly superior coverage |
