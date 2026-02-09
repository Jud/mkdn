# Design Decisions: LLM Visual Verification

**Feature ID**: llm-visual-verification
**Created**: 2026-02-09
**Revised**: 2026-02-09 (v2: shell script orchestration replaces rp1 skill file)

## Decision Log

| ID | Decision | Choice | Rationale | Alternatives Considered |
|----|----------|--------|-----------|------------------------|
| D1 | Orchestration layer | Shell scripts in `scripts/visual-verification/` + CLAUDE.md documentation | rp1 skills require plugin-level registration via `~/.claude-b/plugins/cache/` with no project-level auto-discovery. Shell scripts are immediately executable via Bash, follow the existing `scripts/` pattern (release.sh, smoke-test.sh), and need no restart or registration. CLAUDE.md provides discoverability for Claude Code. | rp1 skill file at `.rp1/skills/` (rejected: rp1 skills are plugin-level artifacts requiring restart and plugin cache registration; no project-level auto-discovery); standalone Python/Ruby scripts (rejected: project is Swift/Bash only); Makefile targets (rejected: no existing Makefile pattern in project) |
| D2 | Capture mechanism | Swift Testing suite (`VisionCaptureTests`) reusing existing `AppLauncher` + `TestHarnessClient` | The existing two-process test architecture is the only supported way to get deterministic, render-complete screenshots from mkdn. A Swift test suite has native access to all test harness infrastructure. | Shell script with socket client (rejected: Unix socket protocol is complex, no existing CLI client); running existing compliance suites and parsing output (rejected: captures go to transient /tmp paths, not controllable); new standalone capture binary (rejected: duplicates existing infrastructure) |
| D3 | Vision evaluation engine | Claude Code's built-in vision capabilities, coordinated by shell scripts that prepare context and task files | Claude Code natively supports reading image files via the Read tool and evaluating them with vision. Shell scripts prepare the context (assemble prompts, manage cache, write task description files) and Claude Code performs the actual vision evaluation. The scripts handle the mechanical parts (caching, batching, file I/O) while Claude Code handles the intelligent part (vision analysis). | Separate Claude API integration via shell/curl (rejected: adds API credential management, duplicates Claude Code's capabilities); third-party vision API (rejected: introduces new dependency) |
| D4 | Generated test file location | `mkdnTests/UITest/VisionCompliance/` | Follows existing compliance suite naming (SpatialCompliance, VisualCompliance, AnimationCompliance). Creates a clear, auditable category for vision-detected tests. User selected this option over `Generated/` subdirectory or inline placement. | `mkdnTests/UITest/Generated/` (rejected: "Generated" suggests second-class tests); inline in `mkdnTests/UITest/` (rejected: harder to distinguish generated from hand-authored); separate test target (rejected: adds Package.swift complexity, splits test infrastructure) |
| D5 | Cache strategy | Content-hash-keyed JSON files in `.rp1/work/verification/cache/` | Hash-based cache keys ensure invalidation on any input change. JSON files are human-readable and version-controllable. File-per-entry avoids read-modify-write on a monolithic cache file. Shell scripts can compute SHA-256 via `shasum -a 256` and check cache existence via file test. | SQLite database (rejected: introduces dependency, harder to version-control); single monolithic cache JSON (rejected: concurrent access risk, all-or-nothing corruption); no caching (rejected: unnecessary API cost on unchanged inputs) |
| D6 | Registry format | Single JSON file at `.rp1/work/verification/registry.json` | The registry is small (one entry per capture-id), read-before-write is acceptable, and a single file is easy to review in git diffs. Shell scripts can read/write it via `jq`. Version-controlled alongside other `.rp1/` artifacts per settings.toml. | JSON Lines like audit trail (rejected: registry needs random-access lookup by captureId, not just append); SQLite (rejected: not human-readable in git, introduces dependency); per-capture JSON files (rejected: too many small files, harder to query across captures) |
| D7 | Audit trail format | JSON Lines (`.jsonl`) at `.rp1/work/verification/audit.jsonl` | Append-only format. Each line is a complete JSON object. Partial writes (crash/abort) corrupt at most one line, not the entire log. Shell scripts can append with simple `echo >>`. Trivially parseable line-by-line. | Single JSON array (rejected: requires read-modify-write, crash during write corrupts entire log); plain text log (rejected: not machine-parseable); structured log files per operation (rejected: too many files, harder to get chronological view) |
| D8 | Batch grouping strategy | Group by fixture (same fixture across themes = 1 batch) | Grouping by fixture allows cross-theme comparison in a single evaluation call, which catches theme-specific issues. Each fixture maps to specific PRDs, so the evaluation prompt context is focused. Default max 4 images per batch fits 2 themes comfortably. | Group by theme (rejected: loses cross-theme comparison opportunity); group by PRD (rejected: some fixtures span multiple PRDs, creating ambiguous grouping); one image per call (rejected: maximum API cost, loses comparative context) |
| D9 | Generated test harness | Separate `VisionComplianceHarness` (launches its own mkdn instance) | Follows existing pattern where each compliance suite (Spatial, Visual, Animation) has its own harness singleton and app instance. Prevents interference between vision-detected tests and hand-authored compliance tests. | Shared harness with existing suites (rejected: execution coupling, risk of state leakage between suites); no harness, launch per test (rejected: extremely slow, existing pattern uses shared instance) |
| D10 | Prompt determinism | Prompts constructed exclusively from version-controlled file contents (charter, PRDs, prompt templates) | Same git state produces same prompt produces same cache key. No timestamps, random values, or environment-dependent state in the prompt. Ensures reproducibility and reliable caching. | Include system context (rejected: non-deterministic, breaks caching); include previous evaluation results (rejected: creates feedback loops in prompt construction) |
| D11 | Script conventions | Follow existing `scripts/` patterns: `set -euo pipefail`, `SCRIPT_DIR`/`PROJECT_ROOT` resolution, `info()`/`error()` helpers | Consistency with existing scripts (release.sh, smoke-test.sh, bundle.sh). Developers already know the patterns. Shell scripts are immediately executable without compilation or registration. | Custom script framework (rejected: over-engineering for 5 scripts); Python scripts (rejected: no existing Python in project); Makefile (rejected: no existing Makefile pattern) |

## Decision Details

### D1: Orchestration Layer (REVISED)

The v1 design placed orchestration in `.rp1/skills/visual-verification.md` -- a Markdown file intended to be discovered and executed as an rp1 skill. This was incorrect for two reasons:

1. **rp1 skills are plugin-level artifacts**. They are discovered by scanning `~/.claude-b/plugins/cache/`, not by scanning project directories. There is no built-in auto-discovery for project-level custom skills. Adding a file to `.rp1/skills/` does not make it available to Claude Code without restart and plugin cache registration.

2. **Shell scripts are immediately executable**. The user wants this implemented as shell scripts + Swift tools invoked via Bash, with instructions in CLAUDE.md. No rp1 plugin infrastructure needed. This matches the existing `scripts/` pattern in the project.

The revised architecture:
- **Shell scripts** (`scripts/visual-verification/`): Five scripts, each handling one phase of the workflow. They can be run individually for debugging or chained by `heal-loop.sh`. They follow the same conventions as `release.sh` and `smoke-test.sh`.
- **CLAUDE.md section**: Tells Claude Code about the scripts, their invocations, and their artifacts. This is how Claude Code discovers the workflow -- by reading the project's CLAUDE.md, which it does at the start of every session.
- **Prompt templates** (`scripts/visual-verification/prompts/`): Live alongside the scripts rather than in `.rp1/skills/prompts/`. This keeps all script-related artifacts together.

### D3: Vision Evaluation Engine (REVISED)

The evaluation step is a hybrid between shell scripts and Claude Code:

**Shell scripts handle the mechanical parts**:
- Cache key computation (SHA-256 hashing via `shasum`)
- Cache lookup (file existence check)
- Prompt assembly (concatenating template + charter + PRD excerpts)
- Batch grouping (reading manifest, grouping by fixture)
- Report merging (combining batch results into a single evaluation)
- Audit trail logging (appending JSON Lines)

**Claude Code handles the intelligent parts**:
- Reading screenshot images (vision capability)
- Evaluating screenshots against design specifications
- Producing structured JSON evaluation output
- Generating Swift test code from evaluation results

The scripts prepare everything Claude Code needs (prompt, images, output path) and write a task description file. Claude Code reads the task, performs the evaluation, and writes the result. The script then picks up the result and proceeds.

### D7: Audit Trail Format

JSON Lines was chosen over a single JSON array specifically for crash resilience AND shell script simplicity. The self-healing loop makes multiple API calls, test generations, and build invocations. With JSON Lines:
- Appending is a simple `echo '{"type":"..."}' >> audit.jsonl`
- No `jq` read-modify-write cycle needed for logging
- If the process is interrupted, at most one line is corrupted
- Each line is independently parseable

### D9: Generated Test Harness

Each existing compliance suite has its own harness singleton:
- `SpatialHarness` for SpatialComplianceTests
- `VisualHarness` for VisualComplianceTests
- `AnimationHarness` for AnimationComplianceTests

This pattern exists because `.serialized` only orders tests within a suite. Suites can run in parallel, and each needs its own app instance to avoid state interference. `VisionComplianceHarness` follows the same pattern.

The capture orchestrator (`VisionCaptureHarness`) is separate from the generated test harness (`VisionComplianceHarness`) because they serve different purposes:
- `VisionCaptureHarness`: Used by the capture orchestrator to produce screenshots for vision evaluation
- `VisionComplianceHarness`: Used by generated tests to run assertions

In practice, these may not run simultaneously (capture happens before test generation). But following the established pattern of one harness per suite ensures consistency and avoids subtle coupling.

### D11: Script Conventions

The existing `scripts/` directory contains four scripts that follow consistent conventions:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
```

The visual verification scripts follow the same pattern but adjust `PROJECT_ROOT` resolution since they are one level deeper (`scripts/visual-verification/` vs `scripts/`):

```bash
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
```

Each script is self-contained: it can be run independently with `--help` output, has clear exit codes, and writes structured output to files rather than relying on stdout parsing between scripts. `heal-loop.sh` chains the other scripts by calling them as subprocesses and checking their exit codes.
