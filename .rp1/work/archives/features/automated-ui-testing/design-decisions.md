# Design Decisions: Automated UI Testing

**Feature ID**: automated-ui-testing
**Created**: 2026-02-08

## Decision Log

| ID | Decision | Choice | Rationale | Alternatives Considered |
|----|----------|--------|-----------|------------------------|
| D1 | App control mechanism | Unix domain socket + JSON protocol (app-side harness) | SPM project has no .xcodeproj; XCUITest requires Xcode UI test target. Socket-based control is deterministic, requires no accessibility permissions, and gives direct access to render completion signals. | XCUITest (requires Xcode project), Accessibility API (requires permissions, no render completion), AppleScript (fragile, slow), stdin/stdout pipes (conflicts with SwiftUI run loop) |
| D2 | Window capture mechanism | `CGWindowListCreateImage` with app's own window ID | Captures composited content including WKWebView Mermaid diagrams. App knows its own window ID, eliminating window-matching ambiguity. | `NSView.cacheDisplay` (may miss WKWebView content), `NSWindow.backingAlignedRect` + `NSBitmapImageRep` (may miss composited layers), AVFoundation screen recording (overkill for single-frame) |
| D3 | Frame capture for animation | `DispatchSourceTimer` + per-frame `CGWindowListCreateImage` | Simple, each frame is independent. Timer precision on macOS is sufficient for 60fps. No dependency on AVFoundation or Metal. | AVFoundation `AVCaptureSession` (complex setup, video encoding overhead), `CADisplayLink` (not available on macOS for window capture), Metal layer capture (requires GPU pipeline changes) |
| D4 | Test framework for UI tests | Swift Testing (`@Suite`, `@Test`, `#expect`) | Consistent with existing project pattern. All 21 existing test files use Swift Testing. No framework mixing required. | XCTest (different assertion style, would be the only XCTest in project), separate test executable (loses `swift test` integration) |
| D5 | Render completion detection | Notification-based signal from `SelectableTextView.Coordinator` | Deterministic; the coordinator already knows when text storage is applied and overlays are positioned. Single integration point. | Polling-based (wasteful, non-deterministic), fixed delays (explicitly prohibited by REQ-001 AC-001f), accessibility property observation (complex, fragile) |
| D6 | Image analysis approach | Direct pixel analysis via `CGDataProvider` | Zero external dependencies. Full control over measurement algorithms. Pixel-level precision for spatial and color verification. | Vision framework (overkill for color/distance measurement), OpenCV via SPM (large dependency), perceptual hash libraries (not needed for precise measurement) |
| D7 | SpacingConstants reference | Use PRD-specified values with comments indicating future constant names | SpacingConstants.swift does not yet exist. Hardcoded PRD values with clear migration path when constants are implemented. | Block on SpacingConstants implementation (delays testing infrastructure), use approximate values (loses precision) |
| D8 | Reduce Motion testing | App-side override via test harness command | The test harness can set a test-mode override for `accessibilityReduceMotion` without changing system preferences. Isolated to the test session. | System preference change (affects entire system, non-isolated), SwiftUI environment injection (not accessible from outside the view hierarchy) |
| D9 | JSON output mechanism | Dedicated `JSONResultReporter` writing to file alongside `swift test` output | Decouples structured agent output from Swift Testing's own console output. Agent reads the JSON file; human reads console. | Custom Swift Testing trait/reporter (not yet a stable API), parsing `swift test` stdout (fragile, format not guaranteed), XCTest XML output (wrong framework) |
| D10 | Test target structure | All UI tests in `mkdnTests` target (no new target) | SPM test target already exists. Adding test files to existing target avoids Package.swift changes and keeps `swift test` as the single entry point. | Separate `mkdnUITests` target (requires Package.swift changes, separate build), Xcode UI test target (requires .xcodeproj) |

## AFK Mode: Auto-Selected Technology Decisions

| Decision | Choice | Source | Rationale |
|----------|--------|--------|-----------|
| Test framework | Swift Testing | KB patterns.md | All 21 existing tests use Swift Testing with `@Suite`/`@Test`/`#expect`. Consistent with project pattern. |
| IPC mechanism | Unix domain socket | Codebase analysis | Project is pure SPM (no .xcodeproj). XCUITest requires Xcode project infrastructure. Socket-based IPC is the most deterministic SPM-compatible approach. |
| Capture API | CGWindowListCreateImage | Platform default | Standard macOS API for window capture. Captures composited content. No external dependencies. |
| Image analysis | Direct CGImage pixel access | Conservative default | Zero-dependency approach using CGDataProvider. Vision framework is overkill for color/distance measurement. |
| Serialization | JSONEncoder/JSONDecoder | Codebase pattern | Foundation-native. Consistent with existing Codable usage throughout the project. |
| SpacingConstants strategy | PRD-specified hardcoded values with migration comments | Requirements A-6 | SpacingConstants.swift is listed as "not yet implemented" in dependencies. Tests use PRD values annotated with future constant names. |
| Frame capture | DispatchSourceTimer per-frame | Conservative default | Simplest approach. Each frame is independent. No AVFoundation or Metal complexity. May need reassessment if 60fps capture proves insufficient (see HYP-002). |
| Test file organization | `mkdnTests/UITest/` and `mkdnTests/Support/` | Existing pattern | Existing tests are organized under `mkdnTests/Unit/` by layer (Core/, Features/, UI/). UI tests follow the same structural convention. |
| Reduce Motion override | Test harness command setting app-side flag | Design analysis | Cannot modify system accessibility preferences from tests. App-side override is isolated and deterministic. |
| CI priority | Should Have (Phase 4) | Requirements inference | Primary user is local AI agent. Charter success criterion is personal daily-driver, not CI deployment. CI is important but not blocking. |
