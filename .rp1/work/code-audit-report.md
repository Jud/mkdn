# Comprehensive Code Quality Audit Report

**Project**: mkdn
**Audit Date**: 2026-02-25
**Overall Quality Score**: 82/100

## Executive Summary

The mkdn codebase is well-organized and demonstrates strong architectural discipline. The Feature-Based MVVM pattern is consistently applied, `@Observable` is used uniformly (zero `ObservableObject` violations), and the stateless-service-enum pattern for Core computation units is clean and thread-safe by construction. The rendering pipeline (`MarkdownVisitor` -> `MarkdownTextStorageBuilder`) is well-decomposed with thoughtful extension-file splitting.

Key areas for improvement center on: dead code that should be removed, duplicated Markdown-extension-checking logic across four locations, a significant render-logic duplication in `MarkdownPreviewView`, hardcoded magic numbers in the `main.swift` entry point, and test coverage gaps for View-layer logic.

### Critical Issues: 0
### High Priority: 5
### Medium Priority: 9
### Low Priority: 6

---

## Critical Issues (Must Fix)

No critical issues found. The codebase is in a healthy state for a shipping application.

---

## High Priority Issues

### HIGH-001: Triplicated Render Logic in MarkdownPreviewView

**Location**: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownPreviewView.swift:50-102`
**Impact**: Maintenance burden -- identical render-then-build logic is copy-pasted three times (`.task`, `.onChange(of: theme)`, `.onChange(of: scaleFactor)`). Any change to the render pipeline must be made in three places.

**Current Code** (three near-identical blocks):
```swift
// Block 1: .task(id:) lines 58-73
let newBlocks = MarkdownRenderer.render(
    text: documentState.markdownContent,
    theme: appSettings.theme
)
let anyKnown = newBlocks.contains { knownBlockIDs.contains($0.id) }
let shouldAnimate = !anyKnown && !reduceMotion && !newBlocks.isEmpty
renderedBlocks = newBlocks
knownBlockIDs = Set(newBlocks.map(\.id))
isFullReload = shouldAnimate
textStorageResult = MarkdownTextStorageBuilder.build(
    blocks: newBlocks,
    theme: appSettings.theme,
    scaleFactor: appSettings.scaleFactor
)

// Block 2: .onChange(of: theme) lines 76-88 -- same except isFullReload = false
// Block 3: .onChange(of: scaleFactor) lines 89-102 -- same except isFullReload = false
```

**Recommended Fix**: Extract a private method:
```swift
private func rerender(animate: Bool) {
    let newBlocks = MarkdownRenderer.render(
        text: documentState.markdownContent,
        theme: appSettings.theme
    )
    if animate {
        let anyKnown = newBlocks.contains { knownBlockIDs.contains($0.id) }
        isFullReload = !anyKnown && !reduceMotion && !newBlocks.isEmpty
    } else {
        isFullReload = false
    }
    renderedBlocks = newBlocks
    knownBlockIDs = Set(newBlocks.map(\.id))
    textStorageResult = MarkdownTextStorageBuilder.build(
        blocks: newBlocks,
        theme: appSettings.theme,
        scaleFactor: appSettings.scaleFactor
    )
}
```

**Effort**: 15 minutes

---

### HIGH-002: Markdown Extension Checking Duplicated in Four Locations

**Location**: Four separate files each define their own Markdown-extension check:
1. `/Users/jud/Projects/mkdn/mkdn/App/FileOpenCoordinator.swift:25-27` -- `isMarkdownURL(_:)` inline check
2. `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/LinkNavigationHandler.swift:20` -- `markdownExtensions: Set<String>`
3. `/Users/jud/Projects/mkdn/mkdn/Core/DirectoryScanner/DirectoryScanner.swift:6` -- `markdownExtensions: Set<String>`
4. `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift:73` -- hardcoded inline `url.pathExtension == "md" || url.pathExtension == "markdown"`

Additionally, `/Users/jud/Projects/mkdn/mkdn/Core/CLI/FileValidator.swift:4` has `acceptedExtensions: Set<String>`.

**Impact**: If a new extension is ever added (e.g., `.mdx`), five files need updating. The `ContentView` version also lacks case-insensitive comparison, which is a subtle bug for edge cases.

**Recommended Fix**: Consolidate into a single source of truth. `FileOpenCoordinator.isMarkdownURL` could become the canonical check, or better, create a shared utility:
```swift
enum MarkdownFileType {
    static let extensions: Set<String> = ["md", "markdown"]

    static func isMarkdown(_ url: URL) -> Bool {
        extensions.contains(url.pathExtension.lowercased())
    }
}
```

Then replace all five locations with calls to this.

**Effort**: 30 minutes

---

### HIGH-003: Dead Code -- PreviewViewModel is Unused

**Location**: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/ViewModels/PreviewViewModel.swift`
**Impact**: 32 lines of dead code. No file in the source tree references `PreviewViewModel`. The project's own PRD archives confirm this: "appears to be unused (no references from any other file)". `MarkdownPreviewView` calls `MarkdownRenderer.render()` directly. The file was kept "for the editor's live-preview use case" per design notes, but `SplitEditorView` also does not use it.

**Recommended Fix**: Delete the file. If the editor use case arises in the future, it can be recreated.

**Effort**: 2 minutes

---

### HIGH-004: Dead Code -- MarkdownBlockView is Unused

**Location**: `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownBlockView.swift`
**Impact**: 167 lines of dead code. This was the original pure-SwiftUI block rendering view, superseded by the `NSAttributedString` + `SelectableTextView` pipeline. No source file references `MarkdownBlockView`. It also duplicates `bulletStyles` from `MarkdownTextStorageBuilder` and heading font sizes from `PlatformTypeConverter`.

**Recommended Fix**: Delete the file.

**Effort**: 2 minutes

---

### HIGH-005: Dead Code -- Legacy appendTable Method and estimatedTableAttachmentHeight

**Location**: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder+Complex.swift:110-156` -- `appendTable` method marked "Legacy Table (fallback, unused)"
**Location**: `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift:266-284` -- `estimatedTableAttachmentHeight` (only called by nothing)

**Impact**: The comment itself says "Legacy Table (fallback, unused)". `appendTable` is never called -- tables now go through `appendTableInlineText`. `estimatedTableAttachmentHeight` is a private method with zero call sites.

**Recommended Fix**: Delete both methods.

**Effort**: 5 minutes

---

## Medium Priority Issues

### MED-001: main.swift is 200 Lines of Duplicated Branching Logic

**Location**: `/Users/jud/Projects/mkdn/mkdnEntry/main.swift`
**Impact**: The `main.swift` entry point has three major branches (test-harness, env-var relaunch, CLI parse) with significant code duplication. The env-var reading logic (`MKDN_LAUNCH_FILE` / `MKDN_LAUNCH_DIR` -> URL parsing) appears three times (lines 73-78, 95-106, 111-124). The `execv` re-launch logic appears twice (lines 80-93, 181-188).

**Recommended Fix**: Extract shared helpers:
```swift
func readLaunchURLs(envKey: String) -> [URL] { ... }
func execvRelaunch(args: [String]) -> Never { ... }
```

**Effort**: 45 minutes

---

### MED-002: ThemePickerView is Likely Dead Code

**Location**: `/Users/jud/Projects/mkdn/mkdn/Features/Theming/ThemePickerView.swift`
**Impact**: No source file references `ThemePickerView`. Theme cycling is handled via `MkdnCommands` Cmd+T shortcut. This 30-line file appears to be a leftover from an earlier UI iteration.

**Recommended Fix**: Delete the file and the `Features/Theming/` directory.

**Effort**: 2 minutes

---

### MED-003: Inconsistent Error Handling at Call Sites -- Silent try?

**Location**: Multiple files use `try?` to silently swallow errors from `DocumentState.loadFile(at:)`:
- `/Users/jud/Projects/mkdn/mkdn/App/DocumentWindow.swift:68,92,109`
- `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift:77`
- `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift:48,115,215`
- `/Users/jud/Projects/mkdn/mkdn/Features/Sidebar/ViewModels/DirectoryState.swift:123`
- `/Users/jud/Projects/mkdn/mkdn/UI/Components/TheOrbView.swift:161,242`

**Impact**: File load/save failures are silently ignored. The user gets no feedback when a file fails to load (e.g., encoding error, permission denied). The `DocumentState.saveFile()` failure at `MkdnCommands.swift:48` is particularly concerning -- a save failure should be surfaced.

**Recommended Fix**: At minimum, add user-facing error handling for `saveFile()`. For `loadFile()`, consider a toast or alert overlay pattern. Where `try?` is intentional (e.g., reload in TheOrbView auto-reload), add a comment explaining why.

**Effort**: 1-2 hours

---

### MED-004: Bullet Styles Duplicated Between MarkdownBlockView and MarkdownTextStorageBuilder

**Location**:
- `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownBlockView.swift:10-15` (dead code, but illustrative)
- `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift:84-89`

**Impact**: Same four Unicode bullet characters defined in two places. If `MarkdownBlockView` is deleted (per HIGH-004), this becomes moot. But if it is ever resurrected, the values should come from one source.

**Recommended Fix**: Resolve by deleting `MarkdownBlockView` (HIGH-004).

**Effort**: 0 (resolved by HIGH-004)

---

### MED-005: ContentView File Drop Handler Lacks Case-Insensitive Extension Check

**Location**: `/Users/jud/Projects/mkdn/mkdn/App/ContentView.swift:73`

**Current Code**:
```swift
guard let url, url.pathExtension == "md" || url.pathExtension == "markdown" else {
    return
}
```

**Impact**: A file with extension `.MD` or `.Markdown` would be rejected on drag-and-drop, while being accepted everywhere else (FileValidator, DirectoryScanner, etc. all do `.lowercased()`).

**Recommended Fix**: Use the consolidated utility (HIGH-002) or at minimum:
```swift
let ext = url.pathExtension.lowercased()
guard ext == "md" || ext == "markdown" else { return }
```

**Effort**: 5 minutes

---

### MED-006: Heading Font Sizes Duplicated Between PlatformTypeConverter and MarkdownBlockView

**Location**:
- `/Users/jud/Projects/mkdn/mkdn/Core/Markdown/PlatformTypeConverter.swift:15-22`
- `/Users/jud/Projects/mkdn/mkdn/Features/Viewer/Views/MarkdownBlockView.swift:79-86`

**Impact**: Both define heading fonts with levels 1-6 mapped to sizes 28, 24, 20, 18, 16, 14. The `PlatformTypeConverter` version adds weight differentiation. If sizes ever change, both would need updating. Resolved by deleting `MarkdownBlockView` (HIGH-004).

**Effort**: 0 (resolved by HIGH-004)

---

### MED-007: DocumentState.saveAs() Silently Swallows Write Errors

**Location**: `/Users/jud/Projects/mkdn/mkdn/App/DocumentState.swift:98-106`

**Current Code**:
```swift
do {
    try markdownContent.write(to: url, atomically: true, encoding: .utf8)
    // ...
} catch {
    // Write failure; leave state unchanged
}
```

**Impact**: User selects Save As, picks a location, and the save silently fails. No feedback provided. This is distinct from the `try?` pattern in MED-003 because it catches inside a do/catch but discards the error.

**Recommended Fix**: Surface the error via an NSAlert or mode overlay:
```swift
} catch {
    modeOverlayLabel = "Save failed: \(error.localizedDescription)"
}
```

**Effort**: 10 minutes

---

### MED-008: FileTreeNode Has Redundant id and url Properties

**Location**: `/Users/jud/Projects/mkdn/mkdn/Core/DirectoryScanner/FileTreeNode.swift:8-10`

**Current Code**:
```swift
public let id: URL
public let name: String
public let url: URL
```

Where `id = url` in the initializer.

**Impact**: `id` and `url` always hold the same value. This is a minor waste and source of potential confusion.

**Recommended Fix**: Use a computed `id`:
```swift
public var id: URL { url }
```

**Effort**: 5 minutes

---

### MED-009: Some Test Files Are at Wrong Nesting Level

**Location**:
- `/Users/jud/Projects/mkdn/mkdnTests/Unit/FindStateTests.swift` (should be `Unit/Features/`)
- `/Users/jud/Projects/mkdn/mkdnTests/Unit/SyntaxHighlightEngineTests.swift` (should be `Unit/Core/`)
- `/Users/jud/Projects/mkdn/mkdnTests/Unit/ThemeModeTests.swift` (should be `Unit/UI/`)
- `/Users/jud/Projects/mkdn/mkdnTests/Unit/TreeSitterLanguageMapTests.swift` (should be `Unit/Core/`)

**Impact**: The test organization pattern mirrors source: `Unit/Core/`, `Unit/Features/`, `Unit/UI/`. Four test files sit at `Unit/` root instead of their correct subdirectory.

**Recommended Fix**: Move to correct subdirectories.

**Effort**: 5 minutes

---

## Low Priority Issues

### LOW-001: swiftlint:disable Comments Could Be Reduced

**Location**: 22 inline `swiftlint:disable` directives across the codebase.

**Impact**: Most are legitimate (`legacy_objc_type` for `NSString` bridging, `force_cast` for `NSMutableParagraphStyle`, `function_parameter_count` for builder methods). However, the pattern of needing `legacy_objc_type` in 5+ locations suggests a helper function could eliminate most:

```swift
extension NSMutableAttributedString {
    func paragraphRange(at location: Int) -> NSRange {
        (string as NSString).paragraphRange(for: NSRange(location: location, length: 0))
    }
}
```

**Effort**: 30 minutes

---

### LOW-002: MotionPreference Pattern Is Not Consistently Used in MkdnCommands

**Location**: `/Users/jud/Projects/mkdn/mkdn/App/MkdnCommands.swift:168-170`

**Current Code** (Cycle Theme):
```swift
let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
let themeAnimation = reduceMotion
    ? AnimationConstants.reducedCrossfade
    : AnimationConstants.crossfade
```

While the `motionAnimation` helper at line 200 does use `MotionPreference`, the Cycle Theme handler bypasses it and manually checks `NSWorkspace`. This is inconsistent with the rest of the app which uses `MotionPreference.resolved()`.

**Recommended Fix**: Use `motionAnimation(.crossfade)` which is already defined in the same file.

**Effort**: 5 minutes

---

### LOW-003: Popover Animation Pattern Duplicated in TheOrbView

**Location**: `/Users/jud/Projects/mkdn/mkdn/UI/Components/TheOrbView.swift:219-225` and `264-270`

Both `defaultHandlerPopover` and `fileChangedPopover` have identical onAppear animation blocks:
```swift
.onAppear {
    let animation = reduceMotion
        ? AnimationConstants.reducedCrossfade
        : AnimationConstants.springSettle
    withAnimation(animation) {
        popoverAppeared = true
    }
}
```

**Recommended Fix**: Extract a shared `popoverEntrance` ViewModifier or use the existing `MotionPreference` pattern.

**Effort**: 10 minutes

---

### LOW-004: No Logging Framework

**Location**: Project-wide

**Impact**: As noted in `patterns.md`, there is no structured logging. All errors are either silently swallowed (`try?`) or shown via UI overlays. For debugging production issues, there is no way to trace what happened. This is a long-term maintainability concern.

**Recommended Fix**: Consider adopting `os.Logger` (Apple's structured logging) for at least file I/O failures, rendering errors, and FileWatcher lifecycle events.

**Effort**: 2-4 hours

---

### LOW-005: MkdnCLI Has a Hardcoded Version "0.0.0"

**Location**: `/Users/jud/Projects/mkdn/mkdn/Core/CLI/MkdnCLI.swift:5`

```swift
version: "0.0.0"
```

**Impact**: `mkdn --version` prints "0.0.0". Should be updated before release or derived from build configuration.

**Effort**: 10 minutes

---

### LOW-006: FileWatcher Does Not Close File Descriptor in stopWatching

**Location**: `/Users/jud/Projects/mkdn/mkdn/Core/FileWatcher/FileWatcher.swift:70-78`

The `stopWatching()` method cancels the dispatch source and sets `fileDescriptor = -1`, but the file descriptor is only closed in the dispatch source's `setCancelHandler`. If `dispatchSource` is nil when `stopWatching()` is called (e.g., if `watch()` failed to create a source but succeeded in opening the fd), the fd would leak.

In practice this is unlikely since `guard fileDescriptor >= 0` prevents source creation from proceeding after fd open failure, and the cancel handler always runs. But it's worth noting as a defensive programming gap.

**Effort**: 5 minutes

---

## Quality Metrics Dashboard

| Category | Score | Issues | Priority |
|----------|-------|--------|----------|
| Pattern Consistency | 85/100 | 5 violations | Medium |
| Comment Quality | 92/100 | 1 issue (legacy comment on dead code) | Low |
| Code Duplication | 72/100 | 4 instances | High |
| Documentation Drift | 88/100 | 2 minor items | Medium |
| Code Structure | 85/100 | 5 issues | Medium |
| Test Coverage | 78/100 | Gaps in Viewer/Editor layer | Medium |

---

## Detailed Pattern Consistency Analysis

### Positive Patterns (Consistently Applied)

1. **@Observable everywhere**: All 8 `@Observable` classes correctly use `@MainActor` isolation. Zero `ObservableObject` instances found.

2. **Stateless service enums**: `MarkdownRenderer`, `SyntaxHighlightEngine`, `TableColumnSizer`, `MathRenderer`, `PlatformTypeConverter`, `LinkNavigationHandler`, `DirectoryScanner`, `DefaultHandlerService` all correctly use uninhabitable enums with static methods.

3. **Extension file naming**: Consistent `+` suffix pattern (`MarkdownTextStorageBuilder+Blocks.swift`, `CodeBlockBackgroundTextView+TableCopy.swift`).

4. **Error type pattern**: `MermaidError` and `CLIError` both conform to `LocalizedError` with `errorDescription`. Consistent.

5. **Custom NSAttributedString keys**: `CodeBlockAttributes` and `TableAttributes` follow the same pattern (enum namespace, static `NSAttributedString.Key` constants, companion `NSObject` info class).

6. **DispatchSource concurrency pattern**: `FileWatcher` and `DirectoryWatcher` use identical patterns: `@ObservationIgnored private nonisolated(unsafe)`, `nonisolated static func installHandlers`, AsyncStream bridge to MainActor. Well-factored.

7. **Focused value keys**: `FocusedDocumentStateKey`, `FocusedDirectoryStateKey`, `FocusedFindStateKey` all follow identical boilerplate pattern.

8. **Theme color palettes**: `SolarizedDark`, `SolarizedLight`, and `PrintPalette` all follow the same structure: private color constants, static `colors: ThemeColors`, static `syntaxColors: SyntaxColors`.

### Pattern Violations

1. **Markdown extension checking** (HIGH-002): Four different implementations instead of one.
2. **MotionPreference bypassed** (LOW-002): One location manually checks `NSWorkspace` instead of using the established `MotionPreference` pattern.
3. **Error handling inconsistency** (MED-003): `try?` used broadly without distinguishing critical vs. non-critical paths.

---

## Test Coverage Gap Analysis

### Well-Tested Areas
- Core/Markdown: `MarkdownRenderer`, `MarkdownVisitor`, `MarkdownTextStorageBuilder`, `TableCellMap`, `TableColumnSizer`, `LinkNavigationHandler` -- all have thorough tests
- Core/CLI: `FileValidator`, `DirectoryValidator`, `CLIError`, `LaunchContext`, `LaunchItem` -- well covered
- Core/Highlighting: `SyntaxHighlightEngine`, `TreeSitterLanguageMap` -- covered
- Features: `DocumentState`, `AppSettings`, `FindState`, `DirectoryState` -- covered
- UI: `AnimationConstants`, `MotionPreference`, `OrbState` -- covered

### Coverage Gaps (No Tests)
1. **`OverlayCoordinator`** (469 + 89 + 216 + 349 = 1,123 lines) -- Complex overlay positioning logic with no unit tests. This is the component most likely to regress.
2. **`EntranceAnimator`** (316 lines) -- Stagger timing, cover layer lifecycle, block group detection untested.
3. **`CodeBlockBackgroundTextView`** (518 lines + 3 extensions) -- Custom NSTextView with table copy, print, and selection logic. No tests for copy/paste behavior.
4. **`SelectableTextView.Coordinator`** -- Find highlight application, theme crossfade, link navigation delegation untested at the unit level.
5. **`MermaidWebView`** -- No unit tests for HTML escaping, JS escaping, or coordinator message handling. The `htmlEscape` and `jsEscape` static methods are easily testable.
6. **`FileOpenCoordinator`** -- Only 1 test file with basic tests; the `isMarkdownURL` method deserves edge case coverage.

---

## Recommendations Summary

### Immediate (this week)
1. Delete dead code: `PreviewViewModel.swift`, `MarkdownBlockView.swift`, `ThemePickerView.swift`, legacy `appendTable` method (HIGH-003, HIGH-004, HIGH-005, MED-002)
2. Fix case-insensitive extension check in `ContentView.handleFileDrop` (MED-005)
3. Extract render method in `MarkdownPreviewView` (HIGH-001)

### Next Sprint
4. Consolidate Markdown extension checking (HIGH-002)
5. Add error surfacing for `saveFile()` and `saveAs()` failures (MED-003, MED-007)
6. Reorganize misplaced test files (MED-009)
7. Add unit tests for `MermaidWebView.htmlEscape`/`jsEscape` static methods
8. Extract `main.swift` helper functions (MED-001)

### Future Iterations
9. Add unit tests for `OverlayCoordinator` positioning logic
10. Add unit tests for `EntranceAnimator` stagger timing
11. Add `os.Logger` structured logging (LOW-004)
12. Create NSString bridging helper to reduce swiftlint:disable comments (LOW-001)
13. Update CLI version from "0.0.0" (LOW-005)

---

## Architecture Notes

The codebase demonstrates excellent architectural discipline overall:

- **Clean layer separation**: Core has zero imports of SwiftUI view types. Features import Core but not other Features. UI is cross-cutting as intended.
- **Single-module design**: The `mkdnLib` single-module approach with `@testable import` works well at this scale (~100 source files). Internal access level is used appropriately.
- **Extension decomposition**: Large types like `MarkdownTextStorageBuilder` and `CodeBlockBackgroundTextView` are well-decomposed into focused extension files.
- **Two-target split**: The `mkdnLib` + `mkdn` split effectively solves the `@main` test crash issue, which is a known Swift toolchain limitation.

The main structural risk is the growing complexity of the TextKit 2 integration layer (`SelectableTextView` + `OverlayCoordinator` + `CodeBlockBackgroundTextView` = ~2,000 lines) with zero unit test coverage. This is the area most likely to produce regressions.
