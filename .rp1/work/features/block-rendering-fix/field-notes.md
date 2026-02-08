# Field Notes: Block Rendering Fix

## 2026-02-07: T2/T3 Inseparability

T2 (change MarkdownRenderer return type) and T3 (update MarkdownPreviewView consumer) cannot be implemented separately. Changing the return type from `[MarkdownBlock]` to `[IndexedBlock]` immediately breaks all call sites. The build fails until consumers are updated. T3 was implemented as part of T2.

## 2026-02-07: PreviewViewModel Not in Task Decomposition

`PreviewViewModel.swift` also consumes `MarkdownRenderer.render()` but was not included in any task. It appears to be unused (no references from any other file), but it needed its `blocks` property type updated from `[MarkdownBlock]` to `[IndexedBlock]` for compilation.

## 2026-02-07: Test Pattern Match Updates (T5 Partial)

The test pattern match updates described in T5 (changing `blocks.first` to `blocks.first?.block` in MarkdownRendererTests and MarkdownVisitorTests) were required for compilation after T2's API change. These were applied as part of T2, so T5's "update existing tests" AC items are already satisfied. T5 still needs the "add new tests" items (IndexedBlock uniqueness, determinism, multi-thematic-break pipeline test).
