# Code Review: T1 — HeadingNode and HeadingTreeBuilder — Core Data Model

**Date:** 2026-03-22
**Round:** 1
**Verdict:** pass

## Summary

Clean, spec-compliant implementation. All three files match the task spec precisely. The MutableNode approach for tree construction is a smart solution to the struct-copy problem with stacks, and it's well-documented in the build log. All 15 tests pass, SwiftLint reports zero violations.

## Findings

### Finding 1: flattenTree returns nodes with children intact
**Severity:** minor
**File:** mkdn/Core/Markdown/HeadingTreeBuilder.swift
**Lines:** 96-101
**Code:**
```swift
private static func flattenNode(_ node: HeadingNode, into result: inout [HeadingNode]) {
    result.append(node)
    for child in node.children {
        flattenNode(child, into: &result)
    }
}
```
**Issue:** The flattened list contains full `HeadingNode` values with their `children` arrays populated. Downstream consumers (OutlineState's `filteredHeadings`, the HUD list) will iterate a flat array where each node redundantly carries its subtree. This is semantically fine and the spec does not require stripping children, but it means memory usage is O(n * average-depth) rather than O(n).
**Expected:** Not a required change -- just noting it. For typical documents with <50 headings this is negligible. If it ever matters, a `strippingChildren()` method could be added.

## What Was Done Well

- The `MutableNode` class-based approach inside `buildTree` elegantly solves the value-type stack mutation problem. The conversion to `HeadingNode` at the end keeps the public API clean and value-typed.
- Test coverage is thorough: all 8 specified `buildTree` cases, both `flattenTree` cases, and all 5 `breadcrumbPath` cases are present (15 total tests).
- The `mixedBlocks` helper in tests is well-designed for creating realistic block arrays with non-heading content interleaved.
- No `#if os(macOS)` guard, correctly following the spec's cross-platform directive.
- `HeadingTreeBuilder` is properly an uninhabitable enum with static methods, matching the project's established pattern.
- Documentation comments are clear and consistent with project style.

## Redo Instructions

N/A -- verdict is pass.
