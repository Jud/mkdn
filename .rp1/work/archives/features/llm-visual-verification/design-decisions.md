# Design Decisions: LLM Visual Verification

**Feature ID**: llm-visual-verification
**Created**: 2026-02-09
**Revised**: 2026-02-09 (v3: scope additions SA-1 through SA-5)

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
| D12 | SA-2: Build prompt structure | Structured multi-test prompt with per-test details and iteration instructions | The current single-shot prompt lists test paths without per-test context or iteration guidance. A structured prompt with per-test PRD reference, specification excerpt, and observation gives the build agent full context to address multiple failures. Explicit iteration instructions ("run tests, fix, repeat") enable internal iteration within a single invocation, reducing outer heal-loop iterations. | Multiple `claude -p` invocations, one per test (rejected: higher API cost, loses cross-test context); raw file path listing without context (rejected: current approach, insufficient for multi-test fixing) |
| D13 | SA-3: Regression detection scope | Additive to existing previous-evaluation comparison | The existing previous-eval comparison correctly handles the common case (issues from last run). Registry history scan adds coverage for the edge case of reintroduced regressions that were resolved in earlier cycles. Making it additive means the existing behavior is preserved and the registry check only catches issues the previous-eval comparison would miss. | Replace previous-eval comparison entirely with registry-based (rejected: registry may have stale data for recently-changed captures; previous-eval comparison is more current); registry-only for regressions, previous-eval for remaining (rejected: over-complicated classification logic) |
| D14 | SA-4: Pre-build HEAD recording | Record `git rev-parse HEAD` before build invocation, then `git diff --name-only` against that after build | This captures exactly the files changed by the build step, even if the build creates multiple commits. Using the pre-build HEAD as the baseline avoids ambiguity about which commit to diff against. | `git diff --name-only HEAD~1 HEAD` (rejected: assumes exactly one commit by build; build may create zero or multiple commits); post-hoc `git log` analysis (rejected: more complex, slower); no file tracking (rejected: requirements mandate filesModified in audit) |
| D15 | SA-5: Guidance input method | Multi-line stdin terminated by empty line, sanitized via `jq --arg` | The simplest terminal-based approach consistent with the existing attended mode (which already uses `read -r -p`). Empty-line termination is intuitive for multi-line input. `jq --arg` handles JSON escaping automatically, preventing corruption of the audit JSONL file. | Single-line input only (rejected: too restrictive for meaningful guidance); file-based input (rejected: over-engineering; developer is already at the terminal); heredoc-style delimiter (rejected: unfamiliar UX for interactive terminal use) |
| D16 | SA-5: Guidance scope | Single iteration only; cleared after use | Business rule BR-4 specifies guidance applies to the immediately-following iteration only. This prevents stale guidance from influencing subsequent iterations where the context may have changed. The developer can provide fresh guidance at each escalation point. | Persist across iterations (rejected: BR-4 explicitly prohibits this); accumulate guidance (rejected: would create increasingly large prompts with potentially contradictory instructions) |

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

### D12: SA-2 Build Prompt Structure

The current build prompt (heal-loop.sh lines 593-599) is a minimal text block:

```
/build {FEATURE_ID} AFK=true

Fix the following vision-detected failing tests...
Failing test files: {paths}
```

This is insufficient for multi-test fixing because:
1. No per-test PRD reference or specification context
2. No iteration instructions for the build agent
3. No test filter command for the build agent to validate its fixes

The restructured prompt (section 3.5.1) addresses all three gaps with a structured Markdown format that includes per-test details and explicit iteration instructions. The format is compatible with the `claude -p` CLI's multi-paragraph prompt support.

### D13: SA-3 Registry-Based Regression Detection

The existing `verify.sh` comparison (Phase 3, lines 130-209) compares new evaluation against the immediately-previous evaluation. This works for detecting regressions introduced in the current iteration but misses reintroduced regressions -- issues that were resolved in an earlier cycle but reappear after an unrelated fix.

The registry already stores evaluation history per capture with issue statuses. Phase 3b reads this history to catch the reintroduction case. The key insight is that the registry data is already being written by verify.sh's Phase 6 (registry update) but never read back for comparison purposes.

Making the registry check additive (Phase 3b after Phase 3a) means:
- Existing behavior is preserved unchanged
- Registry check only processes issues not already classified
- No risk of reclassifying issues already handled by the previous-eval comparison

### D14: SA-4 Pre-Build HEAD Recording

The build step (`/build --afk`) may create zero, one, or multiple commits. Recording `git rev-parse HEAD` before the build and diffing against it after captures all changes regardless of commit count:

- Zero commits: `PRE_BUILD_HEAD == POST_BUILD_HEAD`, `filesModified = []`
- One commit: Standard `git diff --name-only PRE_BUILD_HEAD HEAD`
- Multiple commits: Same diff captures all changes across commits

This is more robust than `HEAD~1` which assumes exactly one commit.

### D15: SA-5 Guidance Input Method

The attended mode already uses `read -r -p` for the escalation choice (heal-loop.sh line 276). Extending this pattern to multi-line input with empty-line termination is a natural progression.

JSON safety is critical because the guidance text is stored in the audit trail (JSONL format). `jq --arg` automatically handles escaping of special characters (quotes, backslashes, newlines), preventing any guidance text from corrupting the audit file. This is safer than manual escaping with `sed` or `printf %q`.

Shell injection is not a risk because the guidance text is:
1. Never passed through `eval` or backtick expansion
2. Embedded into the Claude CLI prompt via variable expansion within a string
3. Stored in audit via `jq --arg` which treats it as a literal string

### D16: SA-5 Guidance Scope

Business rule BR-4 from the requirements specification is explicit: "Manual guidance applies only to the immediately-following iteration; it does not persist across iterations."

This is implemented by:
1. Setting `MANUAL_GUIDANCE` when the developer provides guidance
2. Incorporating it into the build prompt for the next iteration
3. Clearing `MANUAL_GUIDANCE=""` after the build prompt is constructed

The developer can provide fresh guidance at each escalation point if issues persist.

## AFK Mode: Auto-Selected Technology Decisions

| Decision | Choice | Source | Rationale |
|----------|--------|--------|-----------|
| SA-1 implementation approach | Validation procedure, no new code | Requirements (REQ-SA1-001 acceptance criteria) | The existing VisionCaptureTests.swift already validates all SA-1 criteria within validateCaptureResults(); adding new Swift code would duplicate existing logic |
| SA-2 prompt format | Structured Markdown with per-test sections | Existing heal-loop.sh pattern | The current prompt already uses Markdown-like formatting; extending it with structure follows the same approach |
| SA-3 registry query method | jq in-shell with `--arg` parameter binding | Existing verify.sh pattern | verify.sh already uses jq for all JSON operations; adding registry queries follows the same pattern |
| SA-4 diff mechanism | `git diff --name-only PRE_BUILD_HEAD HEAD` | Requirements (A-4: "Git diff output between pre-build and post-build commits") | Requirements explicitly suggest git diff; recording pre-build HEAD is more robust than HEAD~1 |
| SA-5 input termination | Empty line | Requirements (A-5: "no GUI or rich input") | Conservative terminal input approach; consistent with existing `read -r -p` usage in attended mode |
| SA-5 JSON escaping | `jq --arg` | Existing audit trail pattern | All existing audit entries use `jq -cn --arg` for string values; guidance text follows the same pattern |
| Registry comparison direction | New-eval issues looked up against registry history | Requirements (REQ-SA3-001: "For each issue in the new evaluation...") | Requirements specify the scan direction: check each new issue against history, not history against new issues |
| Reintroduced regression output | Separate section in re-verification report | Codebase pattern (verify.sh output structure) | The existing report has resolvedIssues, newRegressions, remainingIssues; adding reintroducedRegressions follows the same structure |
