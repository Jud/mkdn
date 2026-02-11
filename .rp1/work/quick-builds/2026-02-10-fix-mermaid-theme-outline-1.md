# Quick Build: Fix Mermaid Theme Outline

**Created**: 2026-02-10T00:00:00Z
**Request**: The outline on mermaid charts is not themed. The diagram container has a bright blue outline/border that does not match the Solarized Dark theme - it appears to be a default system blue rather than a theme-appropriate color.
**Scope**: Small

## Plan

**Reasoning**: Single file change, single system (Viewer), low risk. The MermaidBlockView already draws a custom themed focus border using `colors.accent` with animated show/hide. However, the `.focusable()` modifier on line 42 causes macOS to also draw its default system blue focus ring, which is the untamed bright blue the user sees. Other views in the codebase (`MarkdownEditorView`, `SplitEditorView`) already suppress this with `.focusEffectDisabled()`.

**Files Affected**:
- `mkdn/Features/Viewer/Views/MermaidBlockView.swift`

**Approach**: Add `.focusEffectDisabled()` after `.focusable()` in `MermaidBlockView` to suppress the default macOS system focus ring. The existing custom `focusBorder` overlay (which already uses `colors.accent` from the Solarized palette with animated spring settle / fade out) will continue to render as the sole focus indicator. This matches the pattern used by other focusable views in the codebase.

**Estimated Effort**: 0.25 hours

## Tasks

- [x] **T1**: Add `.focusEffectDisabled()` modifier after `.focusable()` in `MermaidBlockView.body` to suppress the macOS default system focus ring `[complexity:simple]`
- [x] **T2**: Build and lint to verify no regressions (`swift build` and `swiftlint lint`) `[complexity:simple]`

## Implementation Summary

| Task | Files | Approach | Status |
|------|-------|----------|--------|
| T1 | `mkdn/Features/Viewer/Views/MermaidBlockView.swift` | Added `.focusEffectDisabled()` after `.focusable()` to suppress default macOS system focus ring | Done |
| T2 | N/A | `swift build` succeeded, `swiftlint lint` passed with 0 violations, `swiftformat` no changes | Done |

## Verification

{To be added by task-reviewer if --review flag used}
