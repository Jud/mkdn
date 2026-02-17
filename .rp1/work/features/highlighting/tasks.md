# Development Tasks: Multi-Language Syntax Highlighting

**Feature ID**: highlighting
**Status**: In Progress
**Progress**: 75% (6 of 8 tasks, 0 of 6 doc tasks)
**Estimated Effort**: 4 days
**Started**: 2026-02-17

## Overview

Replace Splash-based Swift-only syntax highlighting with a tree-sitter-based engine providing token-level coloring for 16 languages. Extends the SyntaxColors palette with 5 new token types, introduces a universal TokenType enum, and integrates synchronously into the existing MarkdownTextStorageBuilder pipeline.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1, T2, T3, T4] - T1 is package setup; T2 is palette extension; T3 and T4 are new type/data definitions. No data or interface dependencies between them.
2. [T5] - Engine implementation requires T1 (SwiftTreeSitter importable), T3 (TokenType enum), T4 (language map + queries).
3. [T6] - Integration requires T2 (extended SyntaxColors for new call sites) and T5 (highlight engine).
4. [T7, T8] - Splash removal requires T6 (replacement integrated). Tests require T5 + T6 (engine + integration to test).

**Dependencies**:

- T5 -> [T1, T3, T4] (interface: engine imports SwiftTreeSitter, uses TokenType and TreeSitterLanguageMap)
- T6 -> [T2, T5] (interface: appendCodeBlock uses extended SyntaxColors and SyntaxHighlightEngine)
- T7 -> T6 (sequential: Splash removed only after tree-sitter replacement is integrated)
- T8 -> [T5, T6] (interface: tests validate engine API and integration behavior)

**Critical Path**: T1 -> T5 -> T6 -> T7

## Task Breakdown

### Foundation (Parallel Group 1)

- [x] **T1**: Add SwiftTreeSitter and 16 grammar package dependencies to Package.swift `[complexity:medium]`

    **Reference**: [design.md#t1-update-packageswift](design.md#t1-update-packageswift)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] SwiftTreeSitter (ChimeHQ/SwiftTreeSitter) added as a package dependency
    - [x] All 16 grammar packages added as package dependencies: tree-sitter-swift, tree-sitter-python, tree-sitter-javascript, tree-sitter-typescript, tree-sitter-rust, tree-sitter-go, tree-sitter-bash, tree-sitter-json, tree-sitter-yaml, tree-sitter-html, tree-sitter-css, tree-sitter-c, tree-sitter-cpp, tree-sitter-ruby, tree-sitter-java, tree-sitter-kotlin
    - [x] All grammar products added to the mkdnLib target dependencies
    - [x] `swift build` succeeds with the new dependencies

    **Implementation Summary**:

    - **Files**: `Package.swift`
    - **Approach**: Added ChimeHQ/SwiftTreeSitter 0.25.0 and 16 grammar packages. Grammar packages pinned to 0.23.x ranges for consistent ChimeHQ/SwiftTreeSitter references and static source lists (newer versions use FileManager detection which breaks as transitive dependencies). tree-sitter-swift uses alex-pinkus repo at revision pin (0.7.1-with-generated-files tag) since the semver tag lacks generated parser.c. tree-sitter-yaml pinned to exact 0.7.0 (only version with static sources). tree-sitter-kotlin from fwcd repo.
    - **Deviations**: Version pinning strategy differs from design's `from:` ranges -- required due to upstream packaging issues (FileManager-based source detection in newer grammar Package.swift files, URL mismatches between ChimeHQ and tree-sitter org SwiftTreeSitter mirrors, missing generated files in tree-sitter-swift semver tags). See field-notes.md.
    - **Tests**: 429 passing (pre-existing cycleTheme failure unrelated)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

- [x] **T2**: Extend SyntaxColors with 5 new token type fields and update all theme palettes `[complexity:simple]`

    **Reference**: [design.md#32-extended-syntaxcolors](design.md#32-extended-syntaxcolors)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] SyntaxColors struct has 5 new fields: operator, variable, constant, attribute, punctuation
    - [x] SolarizedDark.syntaxColors updated with colors per design table: operator=red, variable=base0, constant=violet, attribute=violet, punctuation=base01
    - [x] SolarizedLight.syntaxColors updated with colors per design table: operator=red, variable=base00, constant=violet, attribute=violet, punctuation=base1
    - [x] PrintPalette.syntaxColors updated with colors per design table: operator=darkRedPink, variable=nearBlack, constant=darkPurple, attribute=darkOrange, punctuation=commentGray
    - [x] All existing call sites compile without changes (backward compatible extension)

    **Implementation Summary**:

    - **Files**: `mkdn/UI/Theme/ThemeColors.swift`, `mkdn/UI/Theme/SolarizedDark.swift`, `mkdn/UI/Theme/SolarizedLight.swift`, `mkdn/UI/Theme/PrintPalette.swift`
    - **Approach**: Added 5 new fields (operator, variable, constant, attribute, punctuation) to SyntaxColors struct and updated all three palette initializers with colors per design table. Also qualified Splash.TokenType references in MarkdownTextStorageBuilder.swift and ThemeOutputFormat.swift to disambiguate from the new TokenType enum introduced in T3.
    - **Deviations**: None
    - **Tests**: 16/16 passing (ThemeTests + PrintPaletteTests)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

- [x] **T3**: Create TokenType enum with capture name mapping and color resolution `[complexity:simple]`

    **Reference**: [design.md#31-tokentype-enum](design.md#31-tokentype-enum)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] TokenType enum created at `mkdn/Core/Highlighting/TokenType.swift` with 13 cases: keyword, string, comment, type, number, function, property, preprocessor, operator, variable, constant, attribute, punctuation
    - [x] `from(captureName:)` static method maps tree-sitter capture names to TokenType, handling subcategory prefixes (e.g., "keyword.control" maps to .keyword)
    - [x] `color(from:)` method resolves each TokenType to the corresponding SyntaxColors property
    - [x] Enum conforms to Sendable
    - [x] Unknown capture names return nil from `from(captureName:)`

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Highlighting/TokenType.swift` (new)
    - **Approach**: Created TokenType enum with 13 cases matching SyntaxColors fields. Used a private static dictionary (`captureNameMap`) for capture name to token type mapping (avoids cyclomatic complexity lint violation from a 17-branch switch). `from(captureName:)` splits on "." to extract the base category, then performs dictionary lookup. `color(from:)` resolves each case to the corresponding SyntaxColors property.
    - **Deviations**: Used dictionary lookup instead of switch statement for `from(captureName:)` to satisfy SwiftLint cyclomatic_complexity rule (17 branches > 15 limit).
    - **Tests**: N/A (unit tests deferred to T8)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

- [x] **T4**: Create TreeSitterLanguageMap, LanguageConfig, and HighlightQueries for 16 languages `[complexity:complex]`

    **Reference**: [design.md#34-treesitterlanguagemap](design.md#34-treesitterlanguagemap)

    **Effort**: 8 hours

    **Acceptance Criteria**:

    - [x] LanguageConfig struct created with `language` and `highlightQuery` fields, conforming to Sendable
    - [x] TreeSitterLanguageMap enum created at `mkdn/Core/Highlighting/TreeSitterLanguageMap.swift` with alias table and `configuration(for:)` method
    - [x] All 16 languages have entries in languageConfigs: swift, python, javascript, typescript, rust, go, bash, json, yaml, html, css, c, c++, ruby, java, kotlin
    - [x] Alias table maps: js->javascript, ts->typescript, py->python, rb->ruby, sh->bash, shell->bash, yml->yaml, cpp->c++
    - [x] Language tag lookup is case-insensitive and trims whitespace
    - [x] HighlightQueries enum created at `mkdn/Core/Highlighting/HighlightQueries.swift` with embedded .scm query strings for all 16 languages sourced from grammar repositories
    - [x] `supportedLanguages` property returns sorted list of canonical names

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Highlighting/TreeSitterLanguageMap.swift` (new), `mkdn/Core/Highlighting/HighlightQueries.swift` (new), `mkdn/Core/Highlighting/TokenType.swift` (modified)
    - **Approach**: Created LanguageConfig struct and TreeSitterLanguageMap enum with case-insensitive alias resolution for all 16 languages. Embedded highlight query strings sourced verbatim from each grammar's queries/highlights.scm. TypeScript queries concatenate JavaScript base + TypeScript overrides (TypeScript inherits from JavaScript). C++ queries concatenate C base + C++ overrides. Added 6 additional capture name mappings to TokenType (conditional, repeat, exception, character, escape, delimiter) needed by nvim-treesitter-convention captures in Kotlin and other grammars. Renamed HighlightQueries.c to .cLang to satisfy SwiftLint identifier_name rule.
    - **Deviations**: Added capture name mappings to TokenType.swift (T3 file) because embedded queries use capture names not in the original mapping. Used swiftlint:disable for file_length, type_body_length, and line_length in HighlightQueries.swift (1992-line file with embedded query strings containing long regex patterns).
    - **Tests**: N/A (unit tests deferred to T8). Build succeeds, 429 tests passing (pre-existing cycleTheme failure unrelated).

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

### Engine (Parallel Group 2)

- [x] **T5**: Create SyntaxHighlightEngine with tree-sitter parsing and token coloring `[complexity:medium]`

    **Reference**: [design.md#35-syntaxhighlightengine](design.md#35-syntaxhighlightengine)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] SyntaxHighlightEngine enum created at `mkdn/Core/Highlighting/SyntaxHighlightEngine.swift` with `highlight(code:language:syntaxColors:)` static method
    - [x] Returns nil for unsupported languages (no grammar found)
    - [x] Creates parser per call (stateless, thread-safe by construction)
    - [x] Parses code with tree-sitter, executes highlight query, maps captures to TokenType
    - [x] Applies foreground colors from SyntaxColors to produce NSMutableAttributedString
    - [x] Uses PlatformTypeConverter.nsColor for SwiftUI Color to NSColor conversion
    - [x] Falls back to plain-colored text if query compilation fails (returns result without token colors)

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Highlighting/SyntaxHighlightEngine.swift` (new)
    - **Approach**: Stateless enum with single static `highlight(code:language:syntaxColors:)` method. Creates Parser per call, sets language from TreeSitterLanguageMap config, parses code to MutableTree, compiles highlight Query from embedded SCM data, executes query on parsed tree, iterates matches/captures, maps capture names to TokenType, and applies NSColor foreground attributes. Base text color uses syntaxColors.variable (standard foreground). Bounds-checks capture ranges against result length for safety.
    - **Deviations**: None
    - **Tests**: 429 passing (pre-existing cycleTheme failure unrelated)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | ✅ PASS |
    | Accuracy | ✅ PASS |
    | Completeness | ✅ PASS |
    | Quality | ✅ PASS |
    | Testing | ⏭️ N/A |
    | Commit | ✅ PASS |
    | Comments | ✅ PASS |

### Integration (Parallel Group 3)

- [x] **T6**: Replace Splash integration in MarkdownTextStorageBuilder with SyntaxHighlightEngine `[complexity:medium]`

    **Reference**: [design.md#37-integration-markdowntextstoragebuilder-changes](design.md#37-integration-markdowntextstoragebuilder-changes)

    **Effort**: 3 hours

    **Acceptance Criteria**:

    - [x] `highlightSwiftCode` method replaced with generic `highlightCode(_:language:syntaxColors:)` that delegates to SyntaxHighlightEngine
    - [x] `appendCodeBlock` in MarkdownTextStorageBuilder+Blocks.swift updated to attempt highlighting for all language-tagged code blocks, not just Swift
    - [x] Unsupported languages and untagged blocks fall through to plain monospace text path (FR-5 preserved)
    - [x] Font and paragraph style attributes applied after highlighting (not overwritten by engine)
    - [x] CodeBlockAttributes.rawCode still set with original unformatted code (BR-5 preserved)
    - [x] `import Splash` removed from MarkdownTextStorageBuilder.swift

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift`, `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`, `mkdnTests/Unit/Core/CodeBlockStylingTests.swift`
    - **Approach**: Removed `import Splash` and replaced `highlightSwiftCode()` (Splash-based, Swift-only) with `highlightCode(_:language:syntaxColors:)` that delegates to `SyntaxHighlightEngine`. Updated `appendCodeBlock` to attempt tree-sitter highlighting for all language-tagged blocks, falling back to plain monospace for unsupported/untagged blocks. Updated one test that expected Python to be unhighlighted (now uses "elixir" as the unsupported language example).
    - **Deviations**: None
    - **Tests**: 426/429 passing (3 pre-existing cycleTheme failures unrelated)

### Cleanup and Verification (Parallel Group 4)

- [ ] **T7**: Remove Splash dependency completely `[complexity:simple]`

    **Reference**: [design.md#t7-remove-splash](design.md#t7-remove-splash)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [ ] ThemeOutputFormat.swift deleted from `mkdn/Core/Markdown/`
    - [ ] Splash removed from Package.swift dependencies and mkdnLib target
    - [ ] No source file imports or references Splash (grep verification)
    - [ ] `swift build` succeeds with Splash fully removed

- [ ] **T8**: Write unit tests for language map, token mapping, and highlight engine `[complexity:medium]`

    **Reference**: [design.md#8-unit-tests](design.md#8-unit-tests)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [ ] TreeSitterLanguageMapTests created at `mkdnTests/Unit/TreeSitterLanguageMapTests.swift` using Swift Testing (@Suite, @Test, #expect)
    - [ ] Tests canonical name resolution for all 16 languages
    - [ ] Tests alias resolution: js, ts, py, rb, sh, shell, yml, cpp, c++
    - [ ] Tests case-insensitive lookup: "Python", "PYTHON", "python" all resolve
    - [ ] Tests unsupported language returns nil; empty string returns nil; whitespace-padded tags resolve
    - [ ] SyntaxHighlightEngineTests created at `mkdnTests/Unit/SyntaxHighlightEngineTests.swift` using Swift Testing
    - [ ] Tests all 16 languages produce non-nil highlighted result
    - [ ] Tests unsupported language returns nil
    - [ ] Tests result string content matches input code (text preservation)
    - [ ] Tests result contains multiple foreground colors (not monochrome) for code with mixed token types
    - [ ] Tests TokenType.from(captureName:) for known captures (keyword, string, comment) and unknown captures (returns nil)
    - [ ] `swift test` passes with all new tests

### User Docs

- [ ] **TD1**: Update modules.md Dependencies table `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Dependencies table

    **KB Source**: modules.md:Dependencies

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] SwiftTreeSitter added to Dependencies table with purpose "Tree-sitter parsing" and Used In "Core/Highlighting"
    - [ ] Splash entry removed from Dependencies table
    - [ ] 16 grammar packages noted (as a group entry or individually)

- [ ] **TD2**: Update modules.md Core Layer Markdown section `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: Core Layer / Markdown

    **KB Source**: modules.md:Core Layer

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] MarkdownTextStorageBuilder.swift description updated to reference SyntaxHighlightEngine instead of "Splash syntax highlighting for Swift"
    - [ ] ThemeOutputFormat.swift entry removed from Core/Markdown table

- [ ] **TD3**: Add modules.md Core Layer Highlighting section `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: add

    **Target**: `.rp1/context/modules.md`

    **Section**: Core Layer / Highlighting (new section)

    **KB Source**: -

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] New "Highlighting (Core/Highlighting/)" section created under Core Layer
    - [ ] Entries for SyntaxHighlightEngine.swift, TreeSitterLanguageMap.swift, TokenType.swift, HighlightQueries.swift with purpose descriptions

- [ ] **TD4**: Update architecture.md Code Blocks rendering pipeline `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: Code Blocks rendering pipeline

    **KB Source**: architecture.md:Code Blocks

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Pipeline diagram updated to reference "SyntaxHighlightEngine (tree-sitter)" instead of "Splash SyntaxHighlighter"

- [ ] **TD5**: Review and update patterns.md Anti-Patterns section `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/patterns.md`

    **Section**: Anti-Patterns

    **KB Source**: patterns.md:Anti-Patterns

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Any Splash-specific references removed or updated; generic wording preserved if already generic

- [ ] **TD6**: Add syntax highlighting entry to index.md Quick Reference `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/index.md`

    **Section**: Quick Reference

    **KB Source**: index.md:Quick Reference

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] "Syntax highlighting: mkdn/Core/Highlighting/" entry added to Quick Reference list

## Acceptance Criteria Checklist

### FR-1: Tree-Sitter-Based Multi-Language Highlighting
- [ ] AC-1.1: All 16 supported language identifiers render with colored tokens
- [ ] AC-1.2: Token coloring distinguishes keywords, strings, comments, numbers, functions/methods, types, and operators
- [ ] AC-1.3: Common language tag aliases recognized (js, ts, py, rb, sh, shell, yml, cpp, c++)

### FR-2: Extended SyntaxColors Palette
- [ ] AC-2.1: SyntaxColors includes all required token color definitions (keyword through punctuation)
- [ ] AC-2.2: Each new token type has colors in Solarized Dark, Solarized Light, and Print palettes
- [ ] AC-2.3: All token colors maintain readable contrast against code block background

### FR-3: All 16 Language Grammars Bundled
- [ ] AC-3.1: Application builds with grammars for all 16 languages
- [ ] AC-3.2: No grammar loaded from filesystem at runtime
- [ ] AC-3.3: Adding a new language requires only a new SPM dependency and mapping entry

### FR-4: Complete Splash Replacement
- [ ] AC-4.1: Splash removed from Package.swift
- [ ] AC-4.2: No source file imports or references Splash
- [ ] AC-4.3: ThemeOutputFormat.swift removed
- [ ] AC-4.4: Swift code blocks highlighted by tree-sitter with quality equal to or better than Splash

### FR-5: Graceful Fallback for Unsupported Languages
- [ ] AC-5.1: Unsupported language renders as monospace text with no coloring
- [ ] AC-5.2: No language tag renders as monospace text with no coloring
- [ ] AC-5.3: No error logged, no crash, no visual glitch for unsupported/untagged blocks

### FR-6: Synchronous Rendering Pipeline Integration
- [ ] AC-6.1: No async/await, Task, or concurrency primitives in hot path
- [ ] AC-6.2: MarkdownTextStorageBuilder calls engine synchronously
- [ ] AC-6.3: Preview rendering latency not perceptibly increased

## Definition of Done

- [ ] All 8 implementation tasks completed
- [ ] All 6 documentation tasks completed
- [ ] All acceptance criteria verified
- [ ] All unit tests pass (`swift test`)
- [ ] Code reviewed
- [ ] SwiftLint passes
- [ ] SwiftFormat applied
- [ ] Visual verification with multi-language fixture in both themes via mkdn-ctl
