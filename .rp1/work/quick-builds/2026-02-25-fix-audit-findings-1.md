# Quick Build: Fix Audit Findings

**Created**: 2026-02-25T20:21:40Z
**Request**: Fix verified audit findings: delete dead code files (PreviewViewModel.swift, MarkdownBlockView.swift, ThemePickerView.swift + Theming dir), delete legacy dead code in MarkdownTextStorageBuilder+Complex.swift (appendTable, appendTableHeader, appendTableRows) and MarkdownTextStorageBuilder.swift (tableColumnWidth, estimatedTableAttachmentHeight), fix case-insensitive extension check in ContentView.swift, update CLI version to 0.1.1, fix MotionPreference bypass in MkdnCommands.swift, extract triplicated render logic in MarkdownPreviewView.swift, consolidate markdown extension checking to FileOpenCoordinator.isMarkdownURL, move 4 misplaced test files to correct subdirs.
**Scope**: Medium

## Plan

**Reasoning**: 8 independent audit fixes touching ~10 source files plus 4 test file moves. Each change is mechanical -- dead code deletion, method extraction, API consolidation, or file relocation. All changes are verifiable via the existing 548-test suite. Risk is medium only because of the breadth of changes, not individual complexity.

**Files Affected**:
- DELETE: `mkdn/Features/Viewer/ViewModels/PreviewViewModel.swift`
- DELETE: `mkdn/Features/Viewer/Views/MarkdownBlockView.swift`
- DELETE: `mkdn/Features/Theming/ThemePickerView.swift` (+ `mkdn/Features/Theming/` directory)
- MODIFY: `mkdn/Core/Markdown/MarkdownTextStorageBuilder+Complex.swift` -- delete appendTable (lines 110-156), appendTableHeader (lines 433-466), appendTableRows (lines 468-499)
- MODIFY: `mkdn/Core/Markdown/MarkdownTextStorageBuilder.swift` -- delete tableColumnWidth constant (line 82), delete estimatedTableAttachmentHeight method (lines 262-284)
- MODIFY: `mkdn/App/ContentView.swift` -- replace inline extension check with FileOpenCoordinator.isMarkdownURL
- MODIFY: `mkdn/Core/CLI/MkdnCLI.swift` -- update version from "0.0.0" to "0.1.1"
- MODIFY: `mkdn/App/MkdnCommands.swift` -- replace manual reduceMotion ternary with motionAnimation(.crossfade)
- MODIFY: `mkdn/Features/Viewer/Views/MarkdownPreviewView.swift` -- extract private renderAndBuild method from triplicated logic
- MODIFY: `mkdn/Core/Markdown/LinkNavigationHandler.swift` -- replace local markdownExtensions with FileOpenCoordinator.isMarkdownURL
- MODIFY: `mkdn/Core/DirectoryScanner/DirectoryScanner.swift` -- replace local markdownExtensions with FileOpenCoordinator.isMarkdownURL
- MOVE: `mkdnTests/Unit/FindStateTests.swift` -> `mkdnTests/Unit/Features/FindStateTests.swift`
- MOVE: `mkdnTests/Unit/SyntaxHighlightEngineTests.swift` -> `mkdnTests/Unit/Core/SyntaxHighlightEngineTests.swift`
- MOVE: `mkdnTests/Unit/ThemeModeTests.swift` -> `mkdnTests/Unit/UI/ThemeModeTests.swift`
- MOVE: `mkdnTests/Unit/TreeSitterLanguageMapTests.swift` -> `mkdnTests/Unit/Core/TreeSitterLanguageMapTests.swift`

**Approach**: Execute each finding independently. Start with dead file deletions (lowest risk, most impactful), then dead code within files, then the consolidation/refactor changes, then file moves. Run swiftformat + swift build + swift test after all changes to verify correctness.

**Estimated Effort**: 3-4 hours

## Tasks

- [x] **T1**: Delete dead code files -- remove PreviewViewModel.swift, MarkdownBlockView.swift, ThemePickerView.swift and the Features/Theming/ directory `[complexity:simple]`
- [x] **T2**: Delete legacy dead code in storage builder -- remove appendTable, appendTableHeader, appendTableRows methods from +Complex.swift, remove tableColumnWidth constant and estimatedTableAttachmentHeight method from MarkdownTextStorageBuilder.swift (keep defaultEstimationContainerWidth which is still used by +TableInline.swift) `[complexity:simple]`
- [x] **T3**: Apply small targeted fixes -- (a) replace inline extension check in ContentView.swift:73 with FileOpenCoordinator.isMarkdownURL, (b) update CLI version from "0.0.0" to "0.1.1" in MkdnCLI.swift:7, (c) replace manual reduceMotion ternary in MkdnCommands.swift:168-174 with the motionAnimation(.crossfade) helper already defined at line 200 `[complexity:simple]`
- [x] **T4**: Refactor duplicated logic -- (a) extract private renderAndBuild method in MarkdownPreviewView.swift from the triplicated render+build pattern in .task/.onChange(theme)/.onChange(scaleFactor), (b) consolidate markdown extension checking by making FileOpenCoordinator.isMarkdownURL the single source of truth, replacing local markdownExtensions sets in LinkNavigationHandler.swift and DirectoryScanner.swift `[complexity:medium]`
- [x] **T5**: Move 4 misplaced test files to correct subdirectories and run swiftformat + swift build + swift test to verify all 548 tests pass `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | DELETE `PreviewViewModel.swift`, `MarkdownBlockView.swift`, `ThemePickerView.swift`, `Features/Theming/` | Removed 3 dead code files and empty directory | Done |
| T2 | `MarkdownTextStorageBuilder+Complex.swift`, `MarkdownTextStorageBuilder.swift` | Deleted appendTable/appendTableHeader/appendTableRows methods, tableColumnWidth constant, estimatedTableAttachmentHeight method | Done |
| T3 | `ContentView.swift`, `MkdnCLI.swift`, `MkdnCommands.swift` | (a) Replaced inline extension check with FileOpenCoordinator.isMarkdownURL, (b) version 0.0.0->0.1.1, (c) replaced manual ternary with motionAnimation(.crossfade) | Done |
| T4 | `MarkdownPreviewView.swift`, `LinkNavigationHandler.swift`, `DirectoryScanner.swift` | (a) Extracted renderAndBuild method from triplicated pattern, (b) removed local markdownExtensions sets, delegated to FileOpenCoordinator.isMarkdownURL | Done |
| T5 | `FindStateTests.swift`, `SyntaxHighlightEngineTests.swift`, `ThemeModeTests.swift`, `TreeSitterLanguageMapTests.swift` | Moved to correct subdirs (Features/, Core/, UI/, Core/) | Done |

## Verification

{To be added by task-reviewer if --review flag used}
