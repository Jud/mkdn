# Code Review: T4 -- TableAttachmentViewProvider + pipeline switchover

**Date:** 2026-03-24
**Round:** 2
**Verdict:** pass

## Summary

All four round 1 findings are correctly resolved. The critical PassthroughHostingView fix, dead code deletion, allowsTextAttachmentView restoration, and onCopyCommand return value fix are all verified. The remaining changes are swiftformat-only reformatting with no behavioral impact.

## What This Code Does

Round 2 is a focused fix commit addressing the four round 1 findings:

1. `OverlayCoordinator+Factories.swift:99`: `NSHostingView` replaces `PassthroughHostingView` for the table overlay, enabling mouse events to reach TableAttachmentView gesture handlers.
2. `TableAttachmentViewProvider.swift`: Entire file deleted (104 lines). The NSTextAttachmentViewProvider approach is incompatible with Swift 6 strict concurrency -- TextKit 2 never calls `loadView()` on the provider under strict concurrency. The overlay approach (attachment placeholder + OverlayCoordinator) is architecturally consistent with Mermaid/image/math blocks.
3. `TableAttachmentData.swift:52`: `allowsTextAttachmentView = true` restored in the designated init.
4. `TableAttachmentView.swift:68-71`: `onCopyCommand` now returns `[NSItemProvider]` with proper UTType instead of writing to pasteboard as side effect.

Additional changes in the commit are all swiftformat reformatting: import ordering (TreeSitterLanguageMap.swift), guard/else line splitting (OverlayCoordinator+TableHeights.swift, SelectableTextView+Coordinator.swift), trailing whitespace (MermaidTemplateLoader.swift), long line wrapping (OutlineMorphApp.swift), and doc comment updates.

## Transitions Identified

No new transitions introduced in round 2. All transitions from round 1 (builder routing, theme changes, selection state, content reload, entrance animation) remain unchanged.

## Convention Check
**Files examined for context:** `OverlayCoordinator+Factories.swift` (other overlay factories all use `NSHostingView`), `MermaidBlockView.swift` (overlay creation pattern), `ImageBlockView.swift` (overlay creation pattern)
**Violations:** 0

## Findings

No findings. All round 1 issues are resolved.

## Acceptance Criteria

| Criterion | Met? | Evidence |
|-----------|------|----------|
| `swift build` succeeds | Yes | Build complete! (1.25s) |
| `swift test` passes | Yes | 708 tests in 65 suites passed (1.130s) |
| Tables render visually via attachment | Yes | Attachment placeholder + OverlayCoordinator pattern, consistent with Mermaid/image/math blocks |
| `swiftformat .` passes | Yes | 0/4 T4 files require formatting |
| `swiftlint lint` passes | Yes | 0 violations in T4 files (2 pre-existing violations in SelectableTextView+Coordinator.swift are not T4-introduced) |
| Selection gestures on cells | Yes | NSHostingView receives mouse events; onTapGesture with modifier detection at TableAttachmentView.swift:156-164 |
| Find highlighting in cells | Yes | cellHighlight at TableAttachmentView.swift:168-177 |
| Copy support via TableClipboardSerializer | Yes | onCopyCommand returns [NSItemProvider] at TableAttachmentView.swift:61-73 |
| MarkdownTextStorageBuilderTableTests rewritten | Yes | 11 tests covering attachment creation, data fidelity, print fallback |
| Dead TableAttachmentViewProvider removed | Yes | File deleted, zero references in codebase |
| PassthroughHostingView replaced with NSHostingView | Yes | OverlayCoordinator+Factories.swift:99 |
| allowsTextAttachmentView restored | Yes | TableAttachmentData.swift:52 |

## Verification Trail

### What I Verified
- **Build integrity**: `swift build` in worktree -- Build complete! (1.25s)
- **Test integrity**: `swift test` in worktree -- 708 tests in 65 suites passed after 1.130 seconds
- **Lint compliance**: `swiftlint lint` on 6 T4-touched files -- 0 new violations (2 pre-existing in SelectableTextView+Coordinator.swift: file_length and orphaned_doc_comment, both present before T4)
- **Format compliance**: `swiftformat --lint` on 4 T4 files -- 0/4 files require formatting
- **Dead code removal**: `grep -r TableAttachmentViewProvider` returns zero matches in codebase
- **PassthroughHostingView usage**: Still exists in `OverlayCoordinator+TableOverlays.swift` for the old text-range-based table overlay path (used by existing TableBlockView). The new attachment-based table path in `OverlayCoordinator+Factories.swift` correctly uses `NSHostingView`. T5 will delete the old path.
- **onCopyCommand contract**: Returns `[NSItemProvider(item:typeIdentifier:)]` with `UTType.utf8PlainText.identifier`. UniformTypeIdentifiers imported at TableAttachmentView.swift:4. NSString cast has inline swiftlint disable for legacy_objc_type rule.
- **allowsTextAttachmentView**: Set at TableAttachmentData.swift:52. Tested by TableAttachmentDataTests.swift:34-43 and MarkdownTextStorageBuilderTableTests.swift:125-129.
- **Commit scope**: `git diff 902ef48..9d2db81 --stat` confirmed 10 files changed (40 insertions, 126 deletions). Net deletion (dead code removed).
- **Non-T4 changes**: All are swiftformat reformatting only (import ordering, guard/else line splitting, long line wrapping, trailing whitespace). No behavioral changes.

### What I Dismissed
- **PassthroughHostingView still in codebase**: It remains in `OverlayCoordinator+TableOverlays.swift` for the old text-range-based table overlay path (TableBlockView). This path is still active and will be removed in T5. Not a T4 concern.
- **Build log claims "removed dead viewProvider(for:) override"**: The round 1 version of TableAttachmentData.swift never had this override; it was in the deleted TableAttachmentViewProvider.swift. The build log description is slightly misleading but the actual code change is correct.
- **Pre-existing lint errors**: SelectableTextView+Coordinator.swift has 2 pre-existing SwiftLint errors (file_length: 589 lines, orphaned_doc_comment at line 256). Verified these exist on the pre-T4 commit. The only T4 change to this file is a swiftformat guard/else line split.

### What I Could Not Verify
- **Runtime interaction**: Cannot verify cell selection (click, Cmd+click, Shift+click) and copy (Cmd+C) work at runtime without launching the app. The code path is now correct (NSHostingView receives mouse events, gesture handlers dispatch to TableSelectionState), and the builder claims visual verification was done.
- **NSTextAttachmentViewProvider Swift 6 incompatibility**: Cannot independently verify the builder's claim that TextKit 2 never calls loadView() under strict concurrency. However, the overlay approach works (verified by tests and builder's visual verification), and deleting dead code is the right call regardless.

### Build Integrity
- `swift build` -> Build complete! (1.25s)
- `swift test` -> 708 tests in 65 suites passed after 1.130 seconds
- `swiftlint lint` (T4 files) -> 0 new violations (2 pre-existing in SelectableTextView+Coordinator.swift)
- `swiftformat --lint` (T4 files) -> 0/4 files require formatting

## What Was Done Well

- Clean, minimal fix commit addressing all four round 1 findings with no extraneous changes.
- The NSTextAttachmentViewProvider investigation was thorough. Rather than papering over the concurrency issue, the builder deleted the dead code and documented the root cause clearly in the build log.
- The onCopyCommand fix properly returns NSItemProvider with UTType instead of the fragile pasteboard side-effect pattern.
- Doc comments updated throughout to reflect the overlay approach (not the view provider approach).
