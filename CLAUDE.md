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

- **NO WKWebView** -- the entire app is native SwiftUI, no exceptions.
- Mermaid rendering: JavaScriptCore + beautiful-mermaid -> SVG -> SwiftDraw -> native Image.
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
