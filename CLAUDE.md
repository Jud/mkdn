<!-- rp1:start -->
## rp1 Knowledge Base

**Use Progressive Disclosure Pattern**

Location: `.rp1/context/`

Files:
- index.md (always load first)
- architecture.md
- modules.md
- patterns.md
- concept_map.md

Loading rules:
1. Always read index.md first.
2. Then load based on task type:
   - Code review: patterns.md
   - Bug investigation: architecture.md, modules.md
   - Feature work: modules.md, patterns.md
   - Strategic or system-wide analysis: all files
<!-- rp1:end -->

## Project: mkdn

Mac-native Markdown viewer/editor. Swift 6 + SwiftUI. macOS 14.0+.

### Critical Rules

- Native SwiftUI for all UI. WKWebView is allowed **only** for Mermaid diagram rendering (one WKWebView per diagram).
- Mermaid rendering: WKWebView + standard Mermaid.js per diagram. Click-to-focus interaction model.
- Use `@Observable` (not `ObservableObject`) for all state.
- Use Swift Testing (`@Test`, `#expect`, `@Suite`) for unit tests.
- SwiftLint strict mode is enforced (Homebrew install, needs Xcode toolchain). Run lint command below before committing.
- SwiftFormat is enforced. Run `swiftformat .` before committing.

### Build/Test Commands

```bash
swift build          # Build
swift test           # Run tests
swift run mkdn       # Run app
DEVELOPER_DIR=/Applications/Xcode-16.3.0.app/Contents/Developer swiftlint lint  # Lint
swiftformat .        # Format
```

### Architecture

Feature-Based MVVM. Two-target layout:
- `mkdnLib` (library target): All source in `mkdn/`, tests in `mkdnTests/`.
- `mkdn` (executable target): Entry point in `mkdnEntry/main.swift`.
- Tests use `@testable import mkdnLib`. Central state: `AppState`.

### rp1 Workflow

- All `.rp1/` artifacts (work/, context/, settings.toml) are tracked in git. Always commit them.
- `GIT_COMMIT=true` is the default (see `.rp1/settings.toml`).

### Visual Verification Workflow

Scripts in `scripts/visual-verification/` implement an LLM vision-based design compliance workflow. The workflow captures deterministic screenshots via the test harness, evaluates them against PRD specifications using Claude Code's vision capabilities, generates failing tests for detected issues, invokes `/build --afk` to fix them, and re-verifies the result.

#### Quick Reference

```bash
# Full autonomous loop (capture, evaluate, generate tests, fix, verify)
scripts/visual-verification/heal-loop.sh --feature-id my-feature

# Dry run (capture + show what would be evaluated, no API calls)
scripts/visual-verification/heal-loop.sh --dry-run

# Individual phases
scripts/visual-verification/capture.sh          # Capture screenshots
scripts/visual-verification/evaluate.sh         # Vision evaluation
scripts/visual-verification/generate-tests.sh   # Generate failing tests
scripts/visual-verification/verify.sh           # Re-verify after fix
```

#### Flags

| Script | Flag | Description |
|--------|------|-------------|
| `heal-loop.sh` | `--feature-id ID` | Feature ID for `/build --afk` invocation (required unless `--dry-run`) |
| `heal-loop.sh` | `--max-iterations N` | Maximum heal iterations (default: 3) |
| `heal-loop.sh` | `--dry-run` | Capture + evaluate only, no test generation or fixes |
| `heal-loop.sh` | `--attended` | Interactive escalation (prompt instead of report file) |
| `heal-loop.sh` | `--skip-build` | Skip initial `swift build` in capture phase |
| `capture.sh` | `--skip-build` | Skip `swift build --product mkdn` step |
| `evaluate.sh` | `--dry-run` | Assemble prompts and report what would be evaluated without API calls |
| `evaluate.sh` | `--batch-size N` | Maximum images per evaluation batch (default: 4) |
| `evaluate.sh` | `--force-fresh` | Bypass cache, force fresh evaluation |
| `generate-tests.sh` | `[path]` | Evaluation report path (default: most recent in reports/) |
| `verify.sh` | `[path]` | Previous evaluation path for comparison (default: most recent) |

#### Artifacts

| Location | Purpose |
|----------|---------|
| `.rp1/work/verification/captures/` | Captured screenshots and `manifest.json` |
| `.rp1/work/verification/reports/` | Evaluation, re-verification, escalation, and dry-run reports |
| `.rp1/work/verification/cache/` | Cached evaluation results keyed by content hash |
| `.rp1/work/verification/registry.json` | Persistent regression registry |
| `.rp1/work/verification/audit.jsonl` | Audit trail of all operations (JSON Lines) |
| `.rp1/work/verification/staging/` | Atomic staging for test generation |
| `mkdnTests/UITest/VisionCompliance/` | Generated test files and capture orchestrator |
| `scripts/visual-verification/prompts/` | Prompt templates and output schema |
