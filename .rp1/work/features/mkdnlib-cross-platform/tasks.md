# Development Tasks: mkdnLib Cross-Platform Rendering Engine (P1+P2)

**Feature ID**: mkdnlib-cross-platform
**Status**: Not Started
**Progress**: 29% (5 of 17 tasks)
**Estimated Effort**: 4 days
**Started**: 2026-02-27

## Overview

Make mkdnLib compile for both macOS 14+ and iOS 17+ by configuring Package.swift with a library product and exclude paths (P1), then migrating 12 core rendering files with conditional imports, platform typealiases, and an NSFontManager bridge (P2). Zero runtime behavior changes on macOS; all 579 existing tests must pass unchanged.

## Implementation DAG

**Parallel Groups** (tasks with no inter-dependencies):

1. [T1, T2] - Package.swift and PlatformTypeConverter are independent of each other. T1 changes the manifest; T2 changes the source. Neither depends on the other at compile time since macOS build works with either change alone.
2. [T3, T4, T5, T6, T7, T8] - All core file migrations depend on T2 (typealiases and bridge methods) but are independent of each other. They are separate files with no cross-file compile-time dependencies beyond the shared PlatformTypeConverter interface.
3. [T9] - Rename cascade is integrated into T2-T7 work but tracked as a logical checkpoint.
4. [T10] - Verification depends on all prior tasks completing.

**Dependencies**:

- T3 -> T2 (interface: uses PlatformColor typealias from PlatformTypeConverter)
- T4 -> T2 (interface: uses renamed color() method from PlatformTypeConverter)
- T5 -> T2 (interface: uses PlatformColor/PlatformImage typealiases from PlatformTypeConverter)
- T6 -> T2 (interface: uses PlatformFont typealias and convertFont bridge from PlatformTypeConverter)
- T7 -> T2 (interface: uses all typealiases, convertFont bridge, and color() rename from PlatformTypeConverter)
- T8 -> T1 (sequential: MermaidWebView guard is needed for iOS build, which T1 enables)
- T10 -> [T1, T2, T3, T4, T5, T6, T7, T8, T9] (verification: all changes must be complete)

**Critical Path**: T2 -> T7 -> T10

## Task Breakdown

### Foundation (Parallel Group 1)

- [x] **T1**: Configure Package.swift for cross-platform library product `[complexity:simple]`

    **Reference**: [design.md#31-package-swift-modifications](design.md#31-package-swift-modifications)

    **Effort**: 2 hours

    **Acceptance Criteria**:

    - [x] `.library(name: "mkdnLib", targets: ["mkdnLib"])` added to products array
    - [x] `.iOS(.v17)` added to platforms array alongside `.macOS(.v14)`
    - [x] ~~`exclude` array added to mkdnLib target~~ **Deferred to per-file guards**: SPM exclude paths are unconditional and break the macOS build. Mac-only files in the 9 directories will receive file-level `#if os(macOS)` guards in later tasks (same pattern as T8). See design.md section 3.1 (REVISED) and field-notes.md.
    - [x] ArgumentParser made conditional on mkdnLib target via `.product(name: "ArgumentParser", ..., condition: .when(platforms: [.macOS]))` and added as direct dependency on mkdn executable target
    - [x] `swift build` succeeds on macOS with zero errors
    - [x] Existing executable target (`swift run mkdn`) still launches correctly

    **Implementation Summary**:

    - **Files**: `Package.swift`
    - **Approach**: Added library product declaration and iOS platform (commit fb25c3b). On retry: made ArgumentParser a conditional dependency on mkdnLib via `.when(platforms: [.macOS])`, keeping it as a direct dependency on the executable target. Deferred exclude paths to per-file `#if os(macOS)` guards (design revised). Updated design.md section 3.1 with revised approach.
    - **Deviations**: AC3 (exclude paths) deferred to per-file guards in later tasks. SPM exclude paths are unconditional and break the macOS build. The revised strategy uses file-level `#if os(macOS)` guards on Mac-only source files (same pattern as T8). Design.md section 3.1 updated to reflect this.
    - **Tests**: Build verified (`swift build`), executable verified (`swift run mkdn --help`)

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | PASS |
    | Comments | N/A |

- [x] **T2**: Migrate PlatformTypeConverter with typealiases, FontTrait bridge, and color rename `[complexity:medium]`

    **Reference**: [design.md#32-platformtypeconverter-migration](design.md#32-platformtypeconverter-migration)

    **Effort**: 4 hours

    **Acceptance Criteria**:

    - [x] `import AppKit` replaced with `#if os(macOS) import AppKit #else import UIKit #endif`
    - [x] `PlatformFont`, `PlatformColor`, `PlatformImage` typealiases added inside the enum, resolving to NSFont/NSColor/NSImage on macOS and UIFont/UIColor/UIImage on iOS
    - [x] `FontTrait` OptionSet added with `.bold` and `.italic` members, conforming to Sendable
    - [x] `convertFont(_:toHaveTrait:)` static method added with NSFontManager implementation on macOS and UIFontDescriptor implementation on iOS
    - [x] iOS path handles `withSymbolicTraits()` returning nil with graceful fallback to original font
    - [x] `nsColor(from:)` renamed to `color(from:)` returning `PlatformColor`
    - [x] All font factory methods return `PlatformFont` instead of `NSFont`
    - [x] `swift build` succeeds on macOS (typealiases are transparent)

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Markdown/PlatformTypeConverter.swift`
    - **Approach**: Replaced bare `import AppKit` with conditional import guard. Added PlatformFont/PlatformColor/PlatformImage typealiases (NSFont/NSColor/NSImage on macOS, UIFont/UIColor/UIImage on iOS). Added FontTrait OptionSet with .bold/.italic. Added convertFont bridge (NSFontManager on macOS, UIFontDescriptor with nil-guard fallback on iOS). Added `color(from:)` as the new canonical method; kept `nsColor(from:)` as a forwarding wrapper for backward compatibility with unmigrated call sites. All font factories return PlatformFont. All NSFont.Weight/systemFontSize/smallSystemFontSize references updated to PlatformFont equivalents.
    - **Deviations**: `nsColor(from:)` retained as a forwarding wrapper to `color(from:)` rather than removed outright, because ~50 call sites in Features/, tests, and other core files depend on the old name. These will be updated in T3-T7 (core files) and T9 (verification/cleanup).
    - **Tests**: 587/587 passing

    **Validation Summary**:

    | Dimension | Status |
    |-----------|--------|
    | Discipline | PASS |
    | Accuracy | PASS |
    | Completeness | PASS |
    | Quality | PASS |
    | Testing | N/A |
    | Commit | PASS |
    | Comments | PASS |

### Core File Migration (Parallel Group 2)

- [x] **T3**: Migrate attribute files (CodeBlockAttributes, TableAttributes, MathAttributes) `[complexity:simple]`

    **Reference**: [design.md#35-core-file-migration-summary](design.md#35-core-file-migration-summary)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] CodeBlockAttributes.swift: `import AppKit` replaced with conditional import guard
    - [x] CodeBlockAttributes.swift: `NSColor` references in CodeBlockColorInfo replaced with `PlatformColor`
    - [x] TableAttributes.swift: `import AppKit` replaced with conditional import guard
    - [x] TableAttributes.swift: `NSColor` references in all 6 TableColorInfo properties replaced with `PlatformColor`
    - [x] MathAttributes.swift: verified as pure Foundation with no changes needed (or conditional import added if AppKit is imported)
    - [x] All three files compile on macOS with zero errors

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Markdown/CodeBlockAttributes.swift`, `mkdn/Core/Markdown/TableAttributes.swift`
    - **Approach**: Replaced bare `import AppKit` with `#if os(macOS) import AppKit #else import UIKit #endif` guards. Replaced all `NSColor` type references with `PlatformTypeConverter.PlatformColor` in CodeBlockColorInfo (2 properties + init) and TableColorInfo (6 properties + init). MathAttributes.swift imports only Foundation; no changes needed.
    - **Deviations**: None
    - **Tests**: 587/587 passing

- [x] **T4**: Migrate SyntaxHighlightEngine with conditional imports and color rename `[complexity:simple]`

    **Reference**: [design.md#35-core-file-migration-summary](design.md#35-core-file-migration-summary)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] `import AppKit` replaced with `#if os(macOS) import AppKit #else import UIKit #endif`
    - [x] All `PlatformTypeConverter.nsColor(from:)` calls replaced with `.color(from:)`
    - [x] No bare `NSFont`, `NSColor`, or `NSImage` references outside `#if os(macOS)` blocks
    - [x] `swift build` succeeds on macOS with zero errors

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Highlighting/SyntaxHighlightEngine.swift`
    - **Approach**: Replaced bare `import AppKit` with conditional import guard. Renamed 2 `PlatformTypeConverter.nsColor(from:)` calls to `.color(from:)` for platform-neutral API. No other changes needed; NSMutableAttributedString and .foregroundColor are Foundation types.
    - **Deviations**: None
    - **Tests**: 587/587 passing

- [x] **T5**: Migrate MathRenderer with conditional imports and platform types `[complexity:simple]`

    **Reference**: [design.md#35-core-file-migration-summary](design.md#35-core-file-migration-summary)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [x] `import AppKit` replaced with `#if os(macOS) import AppKit #else import UIKit #endif`
    - [x] `textColor: NSColor` parameter changed to `PlatformColor`
    - [x] Return type changed from `NSImage` to `PlatformImage`
    - [x] SwiftMath `MathImage.asImage()` return type verified compatible with `PlatformImage`
    - [x] `swift build` succeeds on macOS with zero errors

    **Implementation Summary**:

    - **Files**: `mkdn/Core/Math/MathRenderer.swift`
    - **Approach**: Replaced bare `import AppKit` with conditional import guard. Changed `textColor` parameter from `NSColor` to `PlatformTypeConverter.PlatformColor` and return type from `NSImage` to `PlatformTypeConverter.PlatformImage`. Verified SwiftMath's `MTColor`/`MTImage` typealiases (NSColor/NSImage on macOS, UIColor/UIImage on iOS) align with our PlatformColor/PlatformImage.
    - **Deviations**: None
    - **Tests**: 587/587 passing

- [ ] **T6**: Migrate TableColumnSizer with conditional imports and font bridge `[complexity:simple]`

    **Reference**: [design.md#35-core-file-migration-summary](design.md#35-core-file-migration-summary)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [ ] `import AppKit` replaced with `#if os(macOS) import AppKit #else import UIKit #endif`
    - [ ] `font: NSFont` parameters changed to `PlatformFont`
    - [ ] 2 `NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)` calls replaced with `PlatformTypeConverter.convertFont(font, toHaveTrait: .bold)`
    - [ ] NSAttributedString measurement APIs confirmed as Foundation (no changes)
    - [ ] `swift build` succeeds on macOS with zero errors

- [ ] **T7**: Migrate MarkdownTextStorageBuilder (main + 4 extensions) `[complexity:medium]`

    **Reference**: [design.md#35-core-file-migration-summary](design.md#35-core-file-migration-summary)

    **Effort**: 6 hours

    **Acceptance Criteria**:

    - [ ] **Main file**: conditional import guard added; `NSFont`/`NSColor` replaced with `PlatformFont`/`PlatformColor` in ResolvedColors struct and method signatures; NSFontManager call in `convertInlineContent` replaced with `PlatformTypeConverter.convertFont`
    - [ ] **+Blocks.swift**: conditional import guard added; `PlatformColor` in method params; `checkboxPrefix` method has full `#if os(macOS) ... #else ... #endif` branch for NSImage vs UIImage SF Symbol rendering (per design.md section 3.3)
    - [ ] **+Complex.swift**: conditional import guard added; `PlatformColor` in `appendIndented*` helper params
    - [ ] **+MathInline.swift**: conditional import guard added; `PlatformFont`/`PlatformColor`/`PlatformImage` in method params and attachment creation
    - [ ] **+TableInline.swift**: conditional import guard added; `PlatformFont`/`PlatformColor` in TableRowContext struct; NSFontManager call replaced with `PlatformTypeConverter.convertFont`
    - [ ] All 5 files compile on macOS with zero errors
    - [ ] No bare `NSFont`, `NSColor`, `NSImage`, or `NSFontManager` references outside `#if os(macOS)` blocks

- [ ] **T8**: Add file-level #if os(macOS) guard to MermaidWebView.swift `[complexity:simple]`

    **Reference**: [design.md#36-mermaidwebview-file-level-guard](design.md#36-mermaidwebview-file-level-guard)

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Entire MermaidWebView.swift file body wrapped in `#if os(macOS) ... #endif`
    - [ ] `import WebKit` wrapped in conditional guard
    - [ ] File compiles on macOS with zero errors
    - [ ] On iOS, file compiles as an empty compilation unit (no symbols exported)

### Rename Cascade (Parallel Group 3)

- [ ] **T9**: Verify nsColor-to-color rename cascade across all migrated files `[complexity:simple]`

    **Reference**: [design.md#35-core-file-migration-summary](design.md#35-core-file-migration-summary)

    **Effort**: 1 hour

    **Acceptance Criteria**:

    - [ ] Global search confirms zero remaining references to `PlatformTypeConverter.nsColor(from:` across the entire codebase
    - [ ] All call sites use `PlatformTypeConverter.color(from:` instead
    - [ ] `swift build` succeeds on macOS with zero errors after rename
    - [ ] Note: This is performed as part of T2-T7 but tracked as a separate verification checkpoint

### Verification (Parallel Group 4)

- [ ] **T10**: Full cross-platform build and test verification `[complexity:medium]`

    **Reference**: [design.md#7-testing-strategy](design.md#7-testing-strategy)

    **Effort**: 3 hours

    **Acceptance Criteria**:

    - [ ] `swift build` on macOS: zero errors, zero new warnings
    - [ ] `swift test` on macOS: 579/579 tests pass
    - [ ] iOS simulator build (`xcodebuild -scheme mkdnLib -destination 'platform=iOS Simulator,name=iPhone 16' build`): zero errors
    - [ ] Swift 6 strict concurrency: zero new warnings on both platforms
    - [ ] `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swiftlint lint`: zero new violations in modified files
    - [ ] `swiftformat .`: no changes needed in modified files
    - [ ] No `#if os()` guard is missing (no AppKit types leak into iOS compilation)
    - [ ] No `@unchecked Sendable` annotations added in any migrated file
    - [ ] Visual verification via mkdn-ctl confirms identical rendering in both Solarized themes

### User Docs

- [ ] **TD1**: Update index.md - Stack line `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/index.md`

    **Section**: Stack line (line 6)

    **KB Source**: index.md:6

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Platform list updated to include iOS 17+ alongside macOS 14.0+

- [ ] **TD2**: Update architecture.md - Two-Target Split section `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: Two-Target Split section

    **KB Source**: architecture.md:90-91

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Library product declaration documented
    - [ ] Exclude paths for Mac-only directories documented
    - [ ] ArgumentParser separation documented

- [ ] **TD3**: Update architecture.md - External Dependencies table `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/architecture.md`

    **Section**: External Dependencies table

    **KB Source**: architecture.md:182-189

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] ArgumentParser noted as executable-only dependency

- [ ] **TD4**: Update modules.md - PlatformTypeConverter entry `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/modules.md`

    **Section**: PlatformTypeConverter entry

    **KB Source**: modules.md:47

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] Description updated to include cross-platform typealiases (PlatformFont, PlatformColor, PlatformImage) and font trait bridge

- [ ] **TD5**: Update patterns.md - Naming section `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/patterns.md`

    **Section**: Naming & Organization

    **KB Source**: patterns.md:10

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] `#if os()` conditional import pattern documented for core rendering files

- [ ] **TD6**: Update patterns.md - Type & Data Modeling `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#9-documentation-impact)

    **Type**: edit

    **Target**: `.rp1/context/patterns.md`

    **Section**: Type & Data Modeling

    **KB Source**: patterns.md:17-19

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] PlatformFont/PlatformColor/PlatformImage typealias convention documented

- [ ] **TD7**: Create cross-platform rendering feature blueprint `[complexity:simple]`

    **Reference**: [design.md#documentation-impact](design.md#9-documentation-impact)

    **Type**: add

    **Target**: `docs/features/cross-platform-rendering.md`

    **Section**: (new file)

    **KB Source**: -

    **Effort**: 30 minutes

    **Acceptance Criteria**:

    - [ ] New feature blueprint file created documenting the cross-platform architecture, typealias strategy, font bridge, and exclude path configuration

## Acceptance Criteria Checklist

From requirements.md:

- [ ] REQ-001: Package.swift declares library product "mkdnLib" with `.iOS(.v17)` platform (T1)
- [ ] REQ-002: Mac-only files in 9 directories receive file-level `#if os(macOS)` guards (deferred from T1 to later tasks)
- [ ] REQ-003: PlatformTypeConverter provides PlatformFont/PlatformColor/PlatformImage typealiases on both platforms (T2)
- [ ] REQ-004: 12 core files have conditional import guards with no bare AppKit type references (T2-T7)
- [ ] REQ-005: All 6 NSFontManager call sites routed through cross-platform bridge with iOS UIFontDescriptor fallback (T2, T6, T7)
- [ ] REQ-006: Zero macOS regression -- 579/579 tests pass, identical rendering (T10)
- [ ] REQ-007: iOS simulator build succeeds with zero errors (T10)
- [ ] REQ-008: Swift 6 strict concurrency compliance on both platforms, no @unchecked Sendable (T10)
- [ ] REQ-009: SwiftLint + SwiftFormat compliance in all modified files (T10)
- [ ] REQ-010: No new SPM dependencies; ArgumentParser conditional on mkdnLib (macOS-only), direct on executable (T1)

## Definition of Done

- [ ] All tasks completed (T1-T10, TD1-TD7)
- [ ] All acceptance criteria verified
- [ ] Code reviewed
- [ ] Docs updated
