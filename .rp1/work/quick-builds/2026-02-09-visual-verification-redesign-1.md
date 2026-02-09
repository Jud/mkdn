# Quick Build: Visual Verification Redesign

**Created**: 2026-02-09T22:00:00Z
**Request**: Implement the visual verification redesign from the plan at /Users/jud/.claude-b/plans/fluttering-plotting-hearth.md. Key changes: (1) Create verify-visual.sh replacing heal-loop.sh, (2) Update the LLM Visual Verification PRD to v2.0.0, (3) Delete deprecated scripts (heal-loop.sh, generate-tests.sh, verify.sh, test templates), (4) Clean up artifacts, (5) Update CLAUDE.md and architecture.md. Commit all changes.
**Scope**: Medium

## Plan

**Reasoning**: 10+ files affected across 2 systems (shell scripts + documentation/KB). Deleting production scripts and rewriting a PRD carries medium risk. Estimated 4-6h effort.
**Files Affected**: scripts/visual-verification/verify-visual.sh (new), scripts/visual-verification/heal-loop.sh (delete), scripts/visual-verification/generate-tests.sh (delete), scripts/visual-verification/verify.sh (delete), scripts/visual-verification/prompts/test-template-*.md (delete), .rp1/work/prds/llm-visual-verification.md (rewrite), CLAUDE.md (update), .rp1/context/architecture.md (update), docs/visual-verification.md (rewrite), .rp1/work/verification/registry.json (delete), .rp1/work/verification/current-loop.json (delete), .rp1/work/verification/staging/ (delete), .rp1/work/verification/current-prompt.md.template (delete)
**Approach**: Create the new verify-visual.sh script that chains capture.sh + evaluate.sh with human-readable output. Rewrite the PRD to v2.0.0 (on-demand verification, not autonomous loop). Delete deprecated scripts and artifacts. Update all documentation (CLAUDE.md, architecture.md, docs/visual-verification.md). Commit everything together.
**Estimated Effort**: 4-6 hours

## Tasks

- [ ] **T1**: Create verify-visual.sh and delete deprecated scripts + templates `[complexity:medium]`
- [ ] **T2**: Rewrite LLM Visual Verification PRD to v2.0.0 `[complexity:medium]`
- [ ] **T3**: Clean up verification artifacts (registry.json, current-loop.json, staging/, current-prompt.md.template) `[complexity:simple]`
- [ ] **T4**: Update CLAUDE.md, architecture.md, and docs/visual-verification.md `[complexity:medium]`
- [ ] **T5**: Commit all changes `[complexity:simple]`

## Implementation Summary

{To be added by task-builder}

## Verification

{To be added by task-reviewer if --review flag used}
