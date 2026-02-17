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

### Visual Testing with mkdn-ctl

The app includes a test harness for visual verification. Launch with `--test-harness`, then drive it with `scripts/mkdn-ctl`. See `docs/visual-testing-with-mkdn-ctl.md` for the full workflow.

```bash
swift run mkdn --test-harness                     # launch with harness
scripts/mkdn-ctl load fixtures/table-test.md      # load a fixture
scripts/mkdn-ctl capture /tmp/shot.png            # screenshot
scripts/mkdn-ctl scroll 500                       # scroll to y=500pt
scripts/mkdn-ctl theme solarizedDark              # set theme
scripts/mkdn-ctl info                             # window state
```

When verifying UI changes: create a fixture, load it, capture screenshots at various scroll positions and themes, then `Read` the PNGs to evaluate rendering.
