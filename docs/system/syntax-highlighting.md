# Syntax Highlighting

## What This Is

This is the code coloring engine. When a fenced code block has a language tag (```swift, ```python, etc.), this system parses the code with tree-sitter, extracts syntax tokens, and maps them to colors from the current theme's `SyntaxColors` palette. The result is an `NSMutableAttributedString` with per-token foreground colors that gets composited into the text storage builder's output.

We support 17 languages (Swift, Python, JavaScript, TypeScript, Rust, Go, Bash, JSON, YAML, HTML, CSS, C, C++, Ruby, Java, Kotlin, TOML) with real grammar-based parsing, not regex. This matters because tree-sitter produces a full syntax tree -- it knows that `for` in a Python `for` loop is a keyword but `for` in a variable name isn't. Regex-based highlighters can't make that distinction reliably.

## How It Works

The highlighting pipeline has four components, and data flows through them in sequence:

```
Language tag ("swift")
    |
    v
TreeSitterLanguageMap.configuration(for:)  -->  LanguageConfig?
    |
    v
SyntaxHighlightEngine.highlight()
    |--- cachedParser(for:config:)  -->  Parser (cached per language)
    |--- parser.parse(code)         -->  Tree
    |--- cachedQuery(for:config:)   -->  Query (cached per language)
    |--- query.execute(in: tree)    -->  QueryCursor (captures)
    |--- applyCaptures()            -->  colored NSMutableAttributedString
    |
    v
Result: NSMutableAttributedString with per-token .foregroundColor
```

**TreeSitterLanguageMap** (`mkdn/Core/Highlighting/TreeSitterLanguageMap.swift`) maps fence language tags to `LanguageConfig` structs. Each config bundles a tree-sitter `Language` (the compiled grammar) with a highlight query string. The map handles aliases (`js` -> `javascript`, `py` -> `python`, `sh` -> `bash`, `yml` -> `yaml`, `cpp` -> `c++`) and normalizes to lowercase.

**SyntaxHighlightEngine** (`mkdn/Core/Highlighting/SyntaxHighlightEngine.swift`) is the main entry point -- an `@MainActor` uninhabitable enum with a single public method: `highlight(code:language:syntaxColors:)`. It looks up the language config, gets or creates a cached parser, parses the code into a tree, gets or creates a cached query, executes the query to get captures, and applies colors.

**TokenType** (`mkdn/Core/Highlighting/TokenType.swift`) is the universal token taxonomy -- 13 cases (keyword, string, comment, type, number, function, property, preprocessor, operator, variable, constant, attribute, punctuation) that map to the 13 `SyntaxColors` palette slots. Each tree-sitter capture name (like `keyword.function`, `string.special`, `variable.member`) gets resolved to one of these 13 types via a two-level lookup: compound names first (`variable.member` -> `.property`, `variable.builtin` -> `.keyword`), then base component (`keyword.anything` -> `.keyword`).

**HighlightQueries** (`mkdn/Core/Highlighting/HighlightQueries.swift`) contains the tree-sitter query strings for all 17 languages, embedded as static `String` properties. These are `highlights.scm` files from the tree-sitter grammar repositories, adapted where needed. This is the largest file in the module (~600 lines of S-expression query patterns).

## Why It's Like This

**Why tree-sitter instead of regex?** Because regex-based highlighting is fundamentally broken for nested structures. Consider `let x = "if true { }"` in Swift -- a regex highlighter might color `if` and `true` as keywords inside the string literal. Tree-sitter builds a real parse tree, so it knows those are inside a `string_content` node, not a conditional. The cost is 17 grammar packages as dependencies, but the quality difference is night and day.

**Why embedded query strings instead of loading from files?** The highlight queries need to be available in both macOS and iOS builds, and SPM resource bundling across library targets has edge cases (see the Mermaid template loading saga). Embedding them as Swift string literals sidesteps all bundling issues. The downside is that updating a query requires changing Swift source, but these queries are rarely updated.

**Why `@MainActor` on the engine?** The parser and query caches are static mutable state. Rather than adding locks, we constrain the engine to the main actor. Syntax highlighting happens during text storage building, which is already `@MainActor`, so there's no performance impact.

**Why cache parsers and queries separately?** Parser creation involves loading and initializing the grammar, and query compilation involves parsing the S-expression query string against the language. Both are measurably expensive when called 50+ times in a document with many code blocks. The caches are dictionaries keyed by canonical language name. Parsers are reset (via `parser.reset()`) before reuse rather than recreated, which clears the parser's internal state while keeping the grammar loaded. This was added in commit `198c78a` after profiling showed parser allocation as a bottleneck.

**Why the sorted capture application?** This fixed a real bug (commit `19f430c`). Dictionary iteration order in Swift is randomized per process, so when two tree-sitter captures overlapped on the same range, the color depended on which one was applied last -- which changed every time the app launched. Sorting by `patternIndex` before applying ensures that later patterns (which are conventionally more specific in tree-sitter grammars) always win deterministically.

## Where the Complexity Lives

**The `applyCaptures` method** is the heart of the engine and the most delicate code. It does a two-pass strategy:

1. **Collection pass**: Iterates all matches from the query cursor, extracts captures, maps capture names to `TokenType` via `TokenType.from(captureName:)`, and records them in a `bestCapture` dictionary keyed by `NSRange`. When two captures cover the same range, the one with the higher `patternIndex` wins (this is the tree-sitter convention -- more specific patterns appear later in the query file).

2. **Application pass**: Sorts the collected captures by `patternIndex` (ascending), then applies foreground colors. Sorting ensures deterministic results -- without it, dictionary iteration order causes color flickering between app launches.

**TokenType's two-level resolution** handles the diversity of capture naming across 17 grammars. Tree-sitter grammars use dotted capture names (`keyword.function`, `string.special.key`, `variable.member`, `constant.builtin`), but our color palette has only 13 slots. The compound name map catches important specializations (`variable.member` -> property, `variable.builtin` -> keyword, `string.special.key` -> property, `constant.builtin` -> constant), and the base component map catches everything else by taking the first segment before the dot.

**Range validation** in `applyCaptures` guards against tree-sitter returning ranges that extend past the string length. This shouldn't happen with correct grammars, but incorrect ranges would crash `NSMutableAttributedString.addAttribute` with an out-of-bounds exception.

## The Grain of the Wood

**Adding a new language** follows a mechanical process:

1. Add the tree-sitter grammar package to `Package.swift`
2. Add the `import` and config entry in `TreeSitterLanguageMap.swift`
3. Write or adapt the `highlights.scm` query in `HighlightQueries.swift`
4. Add an alias entry if the language has common aliases (e.g., `yml` -> `yaml`)

The query writing is the only creative part. Refer to existing queries for the capture naming conventions this codebase uses. The 13 `TokenType` cases define what colors are available -- you should use standard capture names that map to these types.

**Adding a new token type** (which is rare -- 13 covers most needs) means:

1. Add a case to `TokenType`
2. Add a color slot to `SyntaxColors`
3. Add the mapping in `TokenType.from(captureName:)`
4. Add the color resolution in `TokenType.color(from:)`
5. Define the actual color values in `SolarizedDark` and `SolarizedLight`

## Watch Out For

**Parser reuse requires `reset()`.** The cached parsers accumulate internal state from previous parses. Without `reset()` before reuse, incremental parsing logic in tree-sitter can produce incorrect trees. The `cachedParser` method calls `reset()` every time it returns a cached parser.

**Query compilation can throw.** If a highlight query has invalid S-expression syntax for the grammar, `Query(language:data:)` throws. The engine catches this and returns the plain-text-colored result (all variable color). This is a graceful degradation, but it means a broken query silently disables highlighting for that language.

**The engine returns `nil` for unsupported languages** (no matching config in the map). The caller (the text storage builder) falls back to monospace text with `codeForeground` color. This is the correct behavior -- unknown languages should render as plain text, not crash.

**Color palette changes require a full rebuild.** There's no way to update just the colors of an already-highlighted string. When the theme changes, the entire document is re-rendered from blocks, and every code block is re-highlighted with the new `SyntaxColors`. This is fast enough in practice because of the parser/query caches.

## Key Files

| File | What It Is |
|------|------------|
| `mkdn/Core/Highlighting/SyntaxHighlightEngine.swift` | Main engine: parser/query caching, capture collection and application |
| `mkdn/Core/Highlighting/TreeSitterLanguageMap.swift` | Language tag to LanguageConfig mapping with aliases, all 17 configs |
| `mkdn/Core/Highlighting/TokenType.swift` | Universal 13-type token taxonomy, capture name resolution, color mapping |
| `mkdn/Core/Highlighting/HighlightQueries.swift` | Embedded highlights.scm query strings for all 17 languages |
| `mkdn/UI/Theme/ThemeColors.swift` | SyntaxColors struct with the 13 color slots consumed by TokenType |
