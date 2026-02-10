# Quick Build: Fix Syntax Anim Bugs

**Created**: 2026-02-09T00:00:00Z
**Request**: Fix two code block rendering bugs: (1) syntax highlighting not working due to SwiftUI attribute scope mismatch with NSTextView, (2) code block animation flash due to EntranceAnimator using document background for all cover layers instead of code block background.
**Scope**: Medium

## Plan

**Reasoning**: 3 source files affected (ThemeOutputFormat.swift, MarkdownTextStorageBuilder.swift, EntranceAnimator.swift), 1 system (rendering/animation pipeline), low-medium risk with clear root causes documented in investigation report. Estimated 2-3 hours.
**Files Affected**:
- `mkdn/Core/Markdown/ThemeOutputFormat.swift` (Bug 1: replace SwiftUI Color with NSColor)
- `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift` (Bug 1: update highlightSwiftCode)
- `mkdn/Features/Viewer/Views/EntranceAnimator.swift` (Bug 2: detect code blocks, use correct bg color)
- `mkdnTests/Unit/Core/CodeBlockStylingTests.swift` (update tests to verify NSColor attribute key)
**Approach**: For Bug 1, modify ThemeOutputFormat to use AppKit's attribute scope (Foundation/AppKit foregroundColor) with NSColor values instead of SwiftUI.Color, so NSMutableAttributedString conversion produces .foregroundColor with NSColor that NSTextView recognizes. For Bug 2, modify EntranceAnimator.makeCoverLayer to check if a fragment falls within a code block range (via CodeBlockAttributes.range on the text storage) and use the CodeBlockColorInfo.background color for cover layers over code block regions instead of the document background.
**Estimated Effort**: 2-3 hours

## Tasks

- [x] **T1**: Modify `ThemeOutputFormat` to produce `NSAttributedString`-compatible attributes -- change the `Builder` to use `NSColor` values and set foreground color via the AppKit attribute scope (`AttributeScopes.AppKitAttributes.ForegroundColorAttribute`) so that `NSMutableAttributedString(AttributedString)` conversion yields `.foregroundColor` keyed as `"NSColor"` with `NSColor` values. Update `ThemeOutputFormat` color types from `SwiftUI.Color` to `NSColor` and adjust `highlightSwiftCode` in `MarkdownTextStorageBuilder.swift` to pass `NSColor` values from `theme.syntaxColors` via `PlatformTypeConverter.nsColor()`. `[complexity:medium]`
- [x] **T2**: Modify `EntranceAnimator.makeCoverLayer` to detect code block fragments by checking `CodeBlockAttributes.range` on the text storage at the fragment's character range, and when found, retrieve `CodeBlockAttributes.colors` to use `CodeBlockColorInfo.background` for the cover layer instead of `textView.backgroundColor`. `[complexity:medium]`
- [x] **T3**: Update `CodeBlockStylingTests.swiftSyntaxHighlighting` to verify that the highlighted output contains `NSAttributedString.Key.foregroundColor` with `NSColor` values (not SwiftUI-scoped keys), catching the exact failure mode that allowed this bug to ship. `[complexity:simple]`
- [x] **T4**: Build, lint, format, and run tests to verify both fixes work correctly and no regressions are introduced. `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/Core/Markdown/ThemeOutputFormat.swift`, `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift`, `mkdn/Features/Viewer/Views/CodeBlockView.swift` | Changed ThemeOutputFormat to accept NSColor and set `appKit.foregroundColor` on AttributedString; updated all call sites to convert SwiftUI.Color via PlatformTypeConverter.nsColor() | Done |
| T2 | `mkdn/Features/Viewer/Views/EntranceAnimator.swift` | Added `coverColor(for:in:)` method that checks CodeBlockAttributes.colors on text storage at fragment offset; returns code block background CGColor or document background as fallback | Done |
| T3 | `mkdnTests/Unit/Core/CodeBlockStylingTests.swift`, `mkdnTests/Unit/Core/ThemeOutputFormatTests.swift` | Added assertion verifying .foregroundColor key with NSColor values; updated ThemeOutputFormatTests to use NSColor and check appKit.foregroundColor | Done |
| T4 | (none) | Build passes, SwiftFormat clean, SwiftLint clean (1 pre-existing violation in TableBlockView), 296/296 unit tests pass | Done |

## Verification

{To be added by task-reviewer if --review flag used}
