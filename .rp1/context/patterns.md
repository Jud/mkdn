# Implementation Patterns

**Project**: mkdn
**Last Updated**: 2026-02-25

## Naming & Organization

**Files**: PascalCase matching primary type (`MarkdownBlock.swift`, `AppSettings.swift`). Extensions use `+` suffix (`MarkdownTextStorageBuilder+Blocks.swift`, `CodeBlockBackgroundTextView+TableCopy.swift`).
**Functions**: Verb-prefixed methods (`loadFile`, `appendHeading`, `convertInline`). Static factories use `make`/`build` prefix. Boolean properties use `is`/`has`/`allows` prefix.
**Imports**: Absolute imports grouped by framework: Foundation/AppKit first, then third-party, no intra-project imports (single module).
**Organization**: Feature-Based MVVM: `Features/{Name}/Views/` and `ViewModels/`. `Core/{Domain}/` for shared logic. `UI/Theme/` for visual constants.

Evidence: `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Blocks.swift`, `mkdn/App/DocumentState.swift`

## Type & Data Modeling

**Data Representation**: Enums with associated values for domain models (`MarkdownBlock`, `CheckboxState`). Structs for data carriers (`AttachmentInfo`, `TextStorageResult`). NSObject subclasses only when required for NSAttributedString storage (`TableCellMap`).
**Type Strictness**: Strong typing throughout. Sendable conformance on value types. `@MainActor` isolation on all `@Observable` state classes. `nonisolated(unsafe)` with `@ObservationIgnored` for DispatchSource/Task fields bridging concurrency.
**Immutability**: Structs are default immutable. State classes use `private(set)` for read-only properties. Computed properties for derived state (`hasUnsavedChanges`, `theme`). `static let` for constants.

Evidence: `mkdn/Core/Markdown/MarkdownBlock.swift`, `mkdn/App/DocumentState.swift:11-12`, `mkdn/Core/FileWatcher/FileWatcher.swift:19-21`

## Error Handling

**Strategy**: Typed enums conforming to `LocalizedError` for domain errors (`MermaidError`). Throwing functions with try/catch at call site. `try?` for non-critical operations. Guard-early-return throughout.
**Propagation**: Errors thrown from Core layer, caught at UI boundary. `try?` in onAppear/onChange handlers where failure is recoverable. Optional return (`nil`) for rendering failures.
**Common Types**: `MermaidError` (LocalizedError), `String(contentsOf:)` throws, nil return for parse/render failures.

Evidence: `mkdn/App/DocumentState.swift:52-63`, `mkdn/Core/Highlighting/SyntaxHighlightEngine.swift:14-64`

## Validation & Boundaries

**Location**: At parse/conversion boundary. Guard clauses at function entry for preconditions.
**Method**: `guard let` + early return. Range bounds checking before NSAttributedString operations. `isEmpty` checks before processing. Content-sniffing for block type routing (language == "mermaid", `$$` prefix for math).

Evidence: `mkdn/Core/Markdown/MarkdownVisitor.swift:24-34`, `mkdn/Core/Math/MathRenderer.swift:28-29`

## Observability

**Logging**: None detected. No structured logging framework.
**Metrics**: None detected.
**Tracing**: None detected.

## Testing Idioms

**Organization**: `mkdnTests/Unit/` mirrors source: `Core/`, `Features/`, `UI/`, `Support/`. Tests import `@testable import mkdnLib` (two-target layout).
**Fixtures**: Inline test data in test methods. `SyntheticImage` helper for image tests. `.solarizedDark` as standard test theme.
**Levels**: Unit dominant (~55 test files). Visual verification via test harness (`scripts/mkdn-ctl`). No XCUITest.
**Mocking**: No mocking framework. Tests exercise real implementations. `@MainActor` on individual test functions (not `@Suite`).

Evidence: `mkdnTests/Unit/Core/MarkdownRendererTests.swift`, `mkdnTests/Unit/Features/DocumentStateTests.swift`

## I/O & Integration

**File Watching**: `DispatchSource.makeFileSystemObjectSource` for kernel-level file change notifications. `AsyncStream` bridges to structured concurrency. Pause/resume around saves to suppress false positives.
**File I/O**: `String(contentsOf:encoding:)` for reads, `String.write(to:atomically:encoding:)` for writes. No database layer. `UserDefaults` for settings persistence with `didSet` observers.
**IPC**: Unix domain socket (AF_UNIX SOCK_STREAM) for test harness. JSON-over-newline protocol. Semaphore-based bridge from sync socket thread to async MainActor.

Evidence: `mkdn/Core/FileWatcher/FileWatcher.swift`, `mkdn/App/AppSettings.swift:23-27`, `mkdn/Core/TestHarness/TestHarnessServer.swift:130-194`

## Key Implementation Patterns

**Stateless Service Enums**: Core computation units (`MarkdownRenderer`, `SyntaxHighlightEngine`, `TableColumnSizer`, `MathRenderer`, `PlatformTypeConverter`, `LinkNavigationHandler`) are uninhabitable enums with static methods. Thread-safe by construction.

**Per-Window State Model**: Each window gets its own `DocumentState`, `FindState`, and optionally `DirectoryState`. `AppSettings` is shared app-wide. `@Observable` + `@MainActor` throughout.

**Custom AttributedString Keys**: `CodeBlockAttributes`, `TableAttributes`, and `MathExpressionAttribute` define custom NSAttributedString keys to carry rendering metadata alongside text.

**Invisible Text Overlay**: Tables written as invisible inline text with `TableCellMap` for character-to-cell mapping. Separate overlay draws visible table. Enables native text selection, find-in-page, and copy.

**Attachment Placeholder**: Mermaid, math, images, and thematic breaks inserted as `NSTextAttachment` placeholders. Overlay views positioned via `AttachmentInfo` geometry.

**Theme Resolution Chain**: `ThemeMode` (user pref) + `ColorScheme` (system) → `AppTheme` (resolved) → `ThemeColors` + `SyntaxColors` (palettes) → concrete colors.
