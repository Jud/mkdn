# Code Review: T3 — TableAttachmentView (SwiftUI visual rendering only)

**Date:** 2026-03-24
**Round:** 1
**Verdict:** pass

## Summary

Clean extraction of `TableBlockView`'s visual rendering into `TableAttachmentView`. The layout code is pixel-identical where it should be, with only the expected structural differences (no overlay coordinator dependency, no size change callback, added `blockIndex`). No issues found.

## What This Code Does

`TableAttachmentView` is a macOS-only SwiftUI view that renders a Markdown table grid: header row (bold, secondary background), divider, data rows (zebra-striped). It reads `AppSettings` from the environment for theme colors and scale factor. Column widths are computed via `TableColumnSizer.computeWidths()` and cached in a reference-type `SizingCache` (keyed on container width + scale factor). The view takes `columns`, `rows`, `blockIndex`, and `containerWidth` as inputs. It does not handle selection, find, or copy -- those are deferred to T4 per the task graph.

## Transitions Identified

- **Theme/scale changes**: `appSettings.theme` and `appSettings.scaleFactor` are read as computed properties. SwiftUI's observation tracking automatically invalidates the body when these change, which triggers `cachedSizingResult()` to recompute (cache miss due to changed `scaleFactor`). Handled correctly.
- **Container width changes**: `containerWidth` is a `var` with default 600. When the provider passes a new width, SwiftUI re-evaluates the body. The sizing cache invalidates on width mismatch. Handled correctly.

## Convention Check
**Files examined for context:** `TableBlockView.swift`, `CodeBlockView.swift`, `MathBlockView.swift`, `ImageBlockView.swift`
**Violations:** 0

The view follows established patterns: `#if os(macOS)` guard, `import AppKit` + `import SwiftUI`, `@Environment(AppSettings.self)`, private computed properties for `colors`/`scaleFactor`/`scaledBodyFont`, file-private helper class for caching.

## Findings

No findings. The code is a clean, minimal extraction that matches the spec and existing conventions.

## Acceptance Criteria

| Criterion | Met? | Evidence |
|-----------|------|----------|
| `swift build` succeeds | Yes | Build verified: "Build complete! (0.14s)" |
| Layout matches `TableBlockView` visually | Yes | Diff shows only expected structural removals (onSizeChange, OverlayContainerState, effectiveWidth) and addition of `blockIndex`. Header, divider, data rows, padding, colors, border, clip shape are identical. |
| No selection, find, or copy behavior | Yes | No gesture recognizers, no selection state, no clipboard code in the file |
| `swiftformat .` passes | Yes | `swiftformat --lint` on the file: "0/1 files require formatting" |
| Lint passes | Yes | `swiftlint lint` on the file: "Found 0 violations" |

## Verification Trail

### What I Verified
- **Build**: Ran `swift build` in worktree -- passed.
- **Tests**: Ran `swift test` in worktree -- 686 tests passed in 63 suites.
- **Lint**: Ran `swiftlint lint` on `TableAttachmentView.swift` -- 0 violations.
- **Format**: Ran `swiftformat --lint` on `TableAttachmentView.swift` -- 0 files need formatting.
- **Layout parity**: Ran `diff` between `TableBlockView` body and `TableAttachmentView` body. Only expected structural differences (removal of `onSizeChange`, `OverlayContainerState`, `effectiveWidth`; addition of `blockIndex`).
- **SizingCache parity**: Ran `diff` on `SizingCache` class -- identical between both files.
- **swiftUIAlignment extension**: `TableAttachmentView` references `column.alignment.swiftUIAlignment` which is defined as an extension in `TableBlockView.swift` (same module, same `#if os(macOS)` guard). Will work until T5 deletes `TableBlockView.swift`, at which point T6 or the relevant task must preserve the extension. This is the correct approach per the spec's alternative guidance.
- **No extra files**: Commit `f85efdc` touches exactly 1 file (new): `TableAttachmentView.swift`. No unrelated changes.

### What I Dismissed
- **`@State` on reference type SizingCache**: This is the same pattern used in `TableBlockView.swift`. The `@State` wrapper keeps the class instance alive across SwiftUI view re-creations; mutations to the class's properties don't require `@State` mutation semantics. Correct usage.
- **Duplicate `SizingCache` definition**: Both `TableBlockView` and `TableAttachmentView` define `private class SizingCache`. Since both are file-scoped `private`, no conflict. T5 deletes `TableBlockView.swift`, so the duplication is temporary.
- **Missing `import` for `TableColumn`/`TableColumnSizer`/etc.**: All are in the same `mkdnLib` module. No import needed.

### What I Could Not Verify
- **Visual rendering parity with TableBlockView**: The layout code is structurally identical, but actual visual rendering requires running the app with an `NSTextAttachmentViewProvider` (T4). Since T3 is purely the view definition without integration, visual verification is deferred to T7 per the task graph.

### Build Integrity
- `swift build` -> Build complete! (0.14s)
- `swift test` -> 686 tests passed in 63 suites (1.018s)
- `swiftlint lint TableAttachmentView.swift` -> 0 violations
- `swiftformat --lint TableAttachmentView.swift` -> 0 files require formatting

## What Was Done Well

The extraction is surgically precise -- the view is a faithful copy of `TableBlockView`'s rendering logic with only the necessary structural changes for the attachment context. The doc comment accurately describes the relationship to `TableBlockView` and the deferred T4 work. The caching pattern is preserved exactly.
