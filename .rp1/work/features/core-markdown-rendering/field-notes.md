# Field Notes: Core Markdown Rendering

## 2026-02-06: T7 -- Uncommitted T1-T6 changes lost during formatting

**Context**: During T7 implementation, running `swiftformat .` (project-wide) modified many files beyond the T7 scope. The subsequent `git checkout --` to restore those files inadvertently reverted uncommitted T1-T6 changes back to the initial scaffold state.

**Root cause**: T1-T6 were implemented with `GIT_COMMIT=false`, leaving all their changes uncommitted in the working tree. Running `git checkout -- <file>` on files that had both T1-T6 changes AND swiftformat changes destroyed the T1-T6 work.

**Impact**: T1, T3, T4, T5, T6 changes to `MarkdownBlock.swift`, `MarkdownVisitor.swift`, `TableBlockView.swift`, `CodeBlockView.swift`, `MarkdownRendererTests.swift` were reverted. `ImageBlockView.swift` (untracked file from T4) survived since `git checkout` does not affect untracked files.

**Lesson**: When `GIT_COMMIT=false` and multiple tasks leave uncommitted changes in the working tree, formatters/linters should be run ONLY on the specific file(s) being modified, not project-wide. Alternatively, use `git stash` before running project-wide tools, or commit intermediate work.

**Recovery path**: T1, T3, T4, T5, T6 need to be re-implemented. T7 changes are intact and compatible with either the scaffold or enriched codebase state.

## 2026-02-06: T4 -- Verified intact after git checkout incident

**Context**: T4 was assigned for re-implementation based on the assumption that `ImageBlockView.swift` was deleted during the `git checkout` incident. However, verification confirmed the file survived because it was untracked (new file) -- `git checkout` only affects tracked files.

**State verified**: `ImageBlockView.swift` exists at `mkdn/Features/Viewer/Views/ImageBlockView.swift` with complete three-state async loading (loading/success/error), NSImage(contentsOf:) for local files, URLSession for remote URLs with 10s timeout, relative path resolution against currentFileURL, path traversal security validation, and theme-aware colors. `MarkdownBlockView.swift` already routes `.image` to `ImageBlockView`. Build succeeds, 29/29 tests pass, swiftformat produces no changes.

**Lesson**: Untracked files are safe from `git checkout` incidents. When triaging recovery, verify actual file state before re-assigning tasks.
