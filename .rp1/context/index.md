# mkdn Knowledge Base Index

**Project**: mkdn -- Mac-native Markdown viewer/editor
**Stack**: Swift 6, SwiftUI, macOS 14.0+, SPM
**Pattern**: Feature-Based MVVM

## Context Files

| File | Purpose | Load When |
|------|---------|-----------|
| architecture.md | System architecture, rendering pipeline, data flow | Bug investigation, system analysis |
| modules.md | Module inventory, dependencies, APIs | Feature work, bug investigation |
| patterns.md | Code patterns, conventions, anti-patterns | Code review, feature work |
| concept_map.md | Domain concepts, relationships | Strategic analysis |

## Quick Reference

- Entry point: `mkdn/App/mkdnApp.swift`
- Central state: `mkdn/App/AppState.swift`
- Markdown pipeline: `mkdn/Core/Markdown/`
- Mermaid pipeline: `mkdn/Core/Mermaid/`
- Theme definitions: `mkdn/UI/Theme/`
- Animation constants: `mkdn/UI/Theme/AnimationConstants.swift`
- Motion preference: `mkdn/UI/Theme/MotionPreference.swift`
- Tests: `mkdnTests/Unit/`

## Critical Constraints

1. NO WKWebView anywhere
2. SwiftLint strict mode (all opt-in rules)
3. Swift Testing for unit tests (not XCTest)
4. `@Observable` macro (not ObservableObject)
