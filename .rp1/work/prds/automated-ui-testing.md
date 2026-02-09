# PRD: Automated UI Testing

**Charter**: [Project Charter](../../context/charter.md)
**Version**: 1.0.0
**Status**: Complete
**Created**: 2026-02-08

---

## Surface Overview

End-to-end automated UI testing infrastructure for mkdn that enables AI coding agents to programmatically control the application, capture rendered output, and verify visual correctness against the project's design system PRDs. The system creates a closed loop: an agent makes a rendering or design change, launches mkdn with test content, captures the rendered output, and verifies that the result matches the design specifications defined in the animation-design-language, spatial-design-language, and cross-element-selection PRDs.

This surface serves the charter's design philosophy -- "every visual and interactive element must be crafted with obsessive attention to sensory detail" -- by making that attention *verifiable*. Rather than relying on manual visual inspection, the testing infrastructure provides programmatic confidence that design intent is preserved across iterations.

The primary user is an AI coding agent (Claude Code or similar) operating in a tight iteration loop: modify code, build, test, verify rendering, adjust. The secondary user is the human developer reviewing test results and approving visual changes.

---

## Scope

### In Scope

| Capability | Description |
|------------|-------------|
| **Programmatic app control** | Launch mkdn with specific files, switch view modes, trigger theme changes, reload files, and exercise all user-facing interactions via a test harness (XCUIApplication or equivalent) |
| **Rendering capture** | Capture the rendered window content as images (PNG/TIFF) at deterministic points -- after file load, after theme change, after mode switch, after animation completes -- using CGWindowListCreateImage or similar screen capture APIs |
| **Design compliance verification** | Compare captured renders against design specifications from the spatial-design-language PRD (spacing, margins, layout) and cross-element-selection PRD (text rendering, selection highlight) |
| **Animation verification** | Capture frame sequences at a known framerate to verify animation timing curves match the animation-design-language PRD specifications -- breathe cycles, spring-settle timing, fade durations, stagger delays |
| **Agent-in-the-loop workflow** | CLI-driven test execution that produces structured output (JSON or similar) consumable by a coding agent, enabling automated pass/fail decisions and iterative refinement |
| **PRD-anchored test specs** | Each test case traces back to a specific functional requirement in an existing PRD, ensuring test coverage maps to design intent |
| **Swift Testing integration** | Test infrastructure built on Swift Testing (`@Test`, `#expect`, `@Suite`) for unit-level checks, with XCTest/XCUITest for UI automation where Swift Testing cannot drive UI |

### Out of Scope

| Exclusion | Rationale |
|-----------|----------|
| **Performance benchmarking** | GPU utilization and frame rate measurement are separate concerns (NFR-1/NFR-2 in animation-design-language PRD may inform future work) |
| **Interactive visual diff tools** | No GUI-based comparison tools; this is agent-driven, CLI-first |
| **Cross-platform testing** | macOS only, per charter scope guardrails |
| **User-facing test UI** | No in-app test runner or test results display |
| **Network-dependent tests** | mkdn has no network features; all tests run offline |

---

## Requirements

### Functional Requirements

**FR-1: Programmatic App Control**
A test harness that can:
- Launch mkdn with a specified Markdown file path
- Wait for the app to reach a stable rendered state (all blocks rendered, Mermaid diagrams loaded)
- Switch between Preview and Edit modes (Cmd+1, Cmd+2)
- Cycle themes (Cmd+T)
- Trigger file reload (Cmd+R)
- Open files via drag-and-drop simulation or Cmd+O
- Dismiss overlays and popovers
- Activate/deactivate Mermaid diagram focus

**FR-2: Rendering Capture**
Capture the mkdn window content as a bitmap image:
- Full window capture at the window's native resolution (Retina-aware)
- Region-of-interest capture for specific UI elements (code blocks, Mermaid diagrams, headings, orbs)
- Deterministic capture timing: capture only after the app signals render completion (not on a fixed delay)
- Output format: PNG with metadata (timestamp, file path, theme, view mode, window dimensions)

**FR-3: Design Compliance Verification -- Spatial**
Verify rendered output against spatial-design-language PRD specifications:
- Document margins match `SpacingConstants.documentMargin` (32pt)
- Block-to-block spacing matches `SpacingConstants.blockSpacing` (16pt)
- Heading spacing (above/below) matches FR-3 heading constants
- Component padding (code blocks, blockquotes) matches `SpacingConstants.componentPadding` (12pt)
- Window chrome insets match `windowTopInset` (32pt), `windowSideInset` (32pt), `windowBottomInset` (24pt)
- Content does not exceed `contentMaxWidth` (~680pt)
- All spacing values are 8pt-grid-aligned (or 4pt sub-grid for optical corrections)

**FR-4: Design Compliance Verification -- Visual**
Verify rendered output against theme and rendering specs:
- Background color matches `ThemeColors.background` for the active theme
- Text colors match `ThemeColors` specifications (headings, body, code)
- Code block syntax highlighting produces correct token colors (via Splash)
- Selection highlight color (when cross-element-selection is implemented) matches theme accent
- Solarized Dark and Solarized Light both pass all visual checks

**FR-5: Animation Verification**
Capture frame sequences at a known framerate to verify animation timing curves:
- **Breathing orb**: Capture at ~30fps over one full cycle (~5s). Verify sinusoidal opacity/scale curve at ~12 cycles/min (2.5s half-cycle). Verify halo bloom offset at 3.0s half-cycle.
- **Spring-settle** (mode overlay, Mermaid focus border): Capture at ~60fps during transition. Verify spring response (0.35s) and damping fraction (0.7) produce expected settle curve.
- **Fade transitions** (theme crossfade, orb appear/dissolve): Capture at ~30fps. Verify duration matches AnimationConstants (crossfade: 0.35s, fadeIn: 0.5s, fadeOut: 0.4s).
- **Content load stagger**: Capture at ~60fps during file load. Verify per-block stagger delay (30ms) and fade+drift animation.
- **Reduce Motion compliance**: Verify that with Reduce Motion enabled, continuous animations are disabled and transitions use reduced durations.
- Frame sequence output: ordered PNGs with frame timestamps, or a video file with metadata.

**FR-6: Agent-in-the-Loop Workflow**
CLI interface for test execution:
- `swift test --filter UITests` or a dedicated test runner script
- Structured output (JSON) with pass/fail per test case, captured image paths, and failure descriptions
- Failure descriptions include: expected value, actual value, PRD reference (e.g., "spatial-design-language FR-3: headingSpaceAbove(H1) expected 48pt, measured 24pt")
- Exit codes: 0 for all pass, non-zero for any failure
- Agent can parse output, identify failures, make code changes, and re-run

**FR-7: PRD-Anchored Test Specs**
Every test case references a specific PRD and functional requirement:
- Test names follow pattern: `test_{prd}_{FR}_{aspect}` (e.g., `test_spatialDesignLanguage_FR3_h1SpaceAbove`)
- Test documentation includes the PRD name, FR number, and expected value with source
- Coverage report: which PRD FRs have tests, which do not

**FR-8: Test Fixture Management**
Standardized Markdown test files:
- A canonical test document exercising all Markdown elements (headings 1-6, paragraphs, code blocks with Swift, lists, blockquotes, tables, thematic breaks, Mermaid diagrams, images, inline formatting)
- Focused test documents for specific scenarios (long document for stagger animation, multiple Mermaid diagrams, theme-sensitive content)
- Test fixtures checked into the repository under `mkdnTests/Fixtures/`

### Non-Functional Requirements

**NFR-1: Deterministic Captures**
Rendering captures must be deterministic: the same file + theme + view mode + window size must produce pixel-identical captures across runs (excluding system-level differences like font rendering changes across macOS versions). Mermaid diagram rendering may have minor variation due to WKWebView; tolerance thresholds must be configurable.

**NFR-2: Capture Speed**
Full window capture must complete in under 50ms. Frame sequence capture at 60fps must not drop frames (the capture mechanism must not itself cause frame drops in the app).

**NFR-3: Test Isolation**
Each test must launch a fresh app instance or reset state completely. No test-order dependencies. Tests can run in parallel if they use separate window instances.

**NFR-4: Measurement Accuracy**
Spatial measurements (margins, spacing, padding) must be accurate to within 1pt at Retina resolution (2px at 2x scale). Animation timing measurements must be accurate to within one frame at the capture framerate.

**NFR-5: CI Compatibility**
Tests must be runnable in a headless CI environment (macOS runner with screen session). CGWindowListCreateImage requires a window server; tests must document the CI setup requirements.

---

## Dependencies & Constraints

### Dependencies

| Dependency | Type | Description |
|------------|------|-------------|
| **animation-design-language PRD** | Design spec | Defines all animation timing constants, motion primitives, and the reduce-motion contract. Animation verification tests (FR-5) validate against these specs. |
| **spatial-design-language PRD** | Design spec | Defines all spacing constants, window chrome values, and layout rules. Spatial compliance tests (FR-3) validate against these specs. |
| **cross-element-selection PRD** | Design spec | Defines the NSTextView-based rendering architecture and selection behavior. Visual parity tests (FR-4) validate the NSTextView rendering matches design intent. |
| **AnimationConstants.swift** | Source of truth | Test assertions reference these constants directly for animation timing expectations. |
| **SpacingConstants.swift** | Source of truth | Test assertions reference these constants directly for spatial expectations. Must be implemented (spatial-design-language Phase 1) before spatial compliance tests can be written. |
| **ThemeColors.swift** | Source of truth | Test assertions reference theme color values for visual compliance checks. |
| **XCUIApplication** | Platform API | Programmatic app control for UI tests. Part of XCTest framework. |
| **CGWindowListCreateImage** | Platform API | Window content capture. Requires window server access. |
| **Swift Testing** | Test framework | Unit-level test assertions. Cannot drive UI automation directly. |
| **XCTest/XCUITest** | Test framework | UI automation (launch app, send key events, capture). Used alongside Swift Testing. |

### Constraints

| Constraint | Impact |
|------------|--------|
| **XCUITest vs Swift Testing split** | Swift Testing cannot launch or control apps. UI automation requires XCUITest. The test suite will need both frameworks: XCUITest for app control and capture, Swift Testing for assertion logic and unit tests. This split must be clean and well-documented. |
| **Window server requirement** | CGWindowListCreateImage and XCUIApplication require a window server (GUI session). Headless CI environments need a virtual display (e.g., `xvfb` equivalent on macOS, or a logged-in CI runner). |
| **WKWebView capture timing** | Mermaid diagrams render asynchronously in WKWebView. Capture must wait for the WKWebView to signal render completion (via the existing JS callback). Race conditions between capture timing and WKWebView rendering are a primary risk. |
| **Retina resolution** | All spatial measurements must account for 2x (or 3x) scale factor. A 32pt margin is 64px in the captured image at 2x. |
| **Animation frame capture overhead** | Capturing at 60fps while the app animates may itself affect animation performance. The capture mechanism must be lightweight enough to not introduce frame drops that would invalidate timing measurements. May need to use screen recording (AVFoundation) rather than per-frame CGWindowListCreateImage calls. |
| **No external animation libraries** | Per animation-design-language PRD constraint, all animations are pure SwiftUI. This means animation internals are not directly inspectable from tests; verification must be visual (captured frames) rather than programmatic (reading animation state). |
| **Two-target architecture** | mkdn uses a library target (mkdnLib) + executable target (mkdn). UI tests need to launch the executable target. Unit tests import mkdnLib via `@testable import`. |

---

## Milestones & Timeline

### Phase 1: Foundation -- App Control & Capture

**Goal**: Establish the core testing infrastructure: launch the app, control it, capture its output.

| Deliverable | Description |
|-------------|-------------|
| XCUITest target setup | Create a UI test target that launches the mkdn executable with test fixtures |
| App control harness | Implement launch-with-file, wait-for-stable-render, switch-mode, cycle-theme, reload-file |
| Window capture utility | Implement CGWindowListCreateImage-based capture with Retina awareness and deterministic timing |
| Test fixture creation | Canonical Markdown test document exercising all element types |
| Structured output | JSON test report with pass/fail, captured image paths, failure descriptions |

### Phase 2: Design Compliance Verification

**Goal**: Verify spatial and visual compliance against design system PRDs.

| Deliverable | Description |
|-------------|-------------|
| Spatial measurement engine | Image analysis utilities to measure margins, spacing, and padding from captured renders |
| Spatial compliance tests | Tests for document margins, block spacing, heading spacing, component padding, window chrome insets (anchored to spatial-design-language PRD FRs) |
| Visual compliance tests | Tests for background color, text color, syntax highlighting colors, theme correctness (anchored to ThemeColors) |
| PRD coverage report | Mapping of which FRs in spatial-design-language and animation-design-language PRDs have test coverage |

### Phase 3: Animation Verification

**Goal**: Verify animation timing and curves against the animation design language.

| Deliverable | Description |
|-------------|-------------|
| Frame sequence capture | AVFoundation or CGWindowListCreateImage-based frame sequence capture at configurable framerate |
| Animation timing analyzer | Analyze frame sequences to extract opacity/scale/position curves and compare against expected timing from AnimationConstants |
| Breathing orb tests | Verify sinusoidal rhythm, halo bloom offset, appear/dissolve timing |
| Spring-settle tests | Verify mode overlay and Mermaid focus border spring response |
| Stagger animation tests | Verify content load stagger delay and fade+drift animation |
| Reduce Motion tests | Verify all animations respect Reduce Motion preference |

### Phase 4: Agent Integration

**Goal**: Close the agent iteration loop with CLI-driven test execution and structured feedback.

| Deliverable | Description |
|-------------|-------------|
| CLI test runner | Script or SPM plugin that runs the full test suite and produces JSON output |
| Failure diagnostics | Enhanced failure messages with PRD references, expected vs actual values, and captured image diffs |
| Agent workflow documentation | Guide for how an AI coding agent should use the test infrastructure in its iteration loop |
| Cross-PRD regression suite | End-to-end test suite that exercises animation + spatial + visual compliance in a single run |

### Known Deadlines

None externally imposed. This infrastructure is driven by the need to iterate with confidence on the design system. It should be usable (at least Phase 1 + Phase 2) before major spatial-design-language or animation-design-language migrations.

---

## Open Questions

| ID | Question | Context | Impact |
|----|----------|---------|--------|
| OQ-1 | Should spatial measurement use pixel-level image analysis (edge detection, color boundary detection) or should the app expose layout metrics via an accessibility or debug API? | Pixel analysis is framework-independent but fragile; debug API is precise but requires app-side instrumentation. | Phase 2 architecture |
| OQ-2 | What capture mechanism is best for animation frame sequences -- per-frame CGWindowListCreateImage, AVFoundation screen recording, or CAMetalLayer readback? | CGWindowListCreateImage may be too slow for 60fps; AVFoundation produces video that needs frame extraction; CAMetalLayer is low-level but precise. | Phase 3 architecture |
| OQ-3 | How should tolerance thresholds work for visual comparison? Per-pixel, perceptual hash, or structural similarity (SSIM)? | Per-pixel is strict but brittle (font rendering changes); perceptual hash is forgiving but may miss subtle regressions; SSIM balances both. | Phase 2 implementation |
| OQ-4 | Should animation timing verification compare against the mathematical curve (e.g., expected opacity at frame N given a spring with response 0.35 and damping 0.7) or against a recorded golden reference? | Mathematical comparison is principled but requires curve-fitting from captured frames; golden reference is simpler but needs re-recording when constants change. | Phase 3 implementation |
| OQ-5 | How do animation verification tests interact with the cross-element-selection PRD's NSTextView migration? The entrance stagger animation changes from SwiftUI per-block to NSTextLayoutFragment-based CALayer animation. | Tests written against the current SwiftUI animation may need to be rewritten when the NSTextView migration lands. | Phase 3 timing relative to cross-element-selection |

---

## Assumptions & Risks

| ID | Assumption | Risk if Wrong | Charter Ref |
|----|------------|---------------|-------------|
| A-1 | CGWindowListCreateImage can capture the mkdn window reliably in a CI environment with a window server session | May need to explore alternative capture mechanisms (Quartz Window Services, IOSurface). Mitigation: validate capture in CI early in Phase 1. | Success Criteria: daily-driver use requires confidence in rendering correctness |
| A-2 | XCUIApplication can reliably launch, control, and terminate the mkdn executable target without flaky timeouts | XCUITest can be fragile with custom window styles (hiddenTitleBar, chromeless). Mitigation: extensive stability testing in Phase 1. | Architecture: chromeless window may confuse XCUITest accessibility queries |
| A-3 | Spatial measurements from captured images can achieve 1pt accuracy at Retina resolution | Sub-pixel anti-aliasing and font rendering may blur boundaries. Mitigation: use high-contrast test fixtures and configurable tolerance. | Design Philosophy: obsessive attention to sensory detail requires precise measurement |
| A-4 | Animation frame sequences captured at 30-60fps provide sufficient temporal resolution to verify timing curves | Spring animations with fast attack may need higher framerate to capture the initial overshoot. Mitigation: configurable capture framerate, start with 60fps. | Animation Design Language: timing curves are precisely specified |
| A-5 | The two-framework split (XCUITest for UI control + Swift Testing for assertions) can coexist cleanly in a single test target or coordinated test targets | Framework interop may introduce build complexity or test runner conflicts. Mitigation: separate targets with shared utilities if needed. | Architecture: two-target layout already exists |
| A-6 | SpacingConstants.swift and the spatial-design-language migration will be implemented before Phase 2 spatial compliance tests are written | If spatial constants are not yet defined, tests cannot reference them. Mitigation: Phase 2 can initially use hardcoded expected values, then migrate to SpacingConstants references. | Spatial Design Language PRD: Phase 1 deliverable |
| R-1 | WKWebView capture timing is the highest-risk element. Mermaid diagrams render asynchronously, and there is no guaranteed synchronization between WKWebView render completion and CGWindowListCreateImage capture. | May produce flaky tests that capture partially-rendered Mermaid diagrams. Mitigation: implement a render-completion signal (via WKWebView JS callback -> Swift notification) and wait for it before capture. | Architecture: WKWebView is the only non-native rendering component |
| R-2 | Animation verification by frame capture is inherently approximate. The captured frames represent what was displayed, but the capture itself introduces timing jitter. | Timing measurements may have +/- 1 frame accuracy. For a 60fps capture, this is +/- 16.7ms, which may be insufficient to distinguish a 0.35s spring from a 0.4s spring. Mitigation: use curve-fitting across many frames rather than single-frame timing assertions. | Animation Design Language: precise timing specifications |
| R-3 | The NSTextView migration (cross-element-selection PRD) will change the rendering architecture significantly. Animation tests written against the current SwiftUI rendering may need rewriting. | Wasted effort if tests are written before the migration. Mitigation: time Phase 3 (animation verification) after the cross-element-selection Core phase is complete, or write tests that are architecture-agnostic (verify visual output, not implementation). | Cross-Element Selection PRD: architectural change |

---

## Discoveries

- **Workaround**: SwiftFormat corrupts nested `try await` expressions (e.g., `try f(from: try await g())` becomes `try await try f(from: g())`); always split into separate lines. -- *Ref: [field-notes.md](archives/features/automated-ui-testing/field-notes.md)*
- **Codebase Discovery**: Swift `private` members are file-scoped; when splitting a struct across extension files, helpers must be `internal` (not `private`) to be accessible from other files. -- *Ref: [field-notes.md](archives/features/automated-ui-testing/field-notes.md)*
- **Codebase Discovery**: SwiftLint enforces `type_body_length: 350` warning threshold; use extracted helpers, extension files, and file-scope free functions to stay under the limit. -- *Ref: [field-notes.md](archives/features/automated-ui-testing/field-notes.md)*
- **Workaround**: Unix domain sockets deliver SIGPIPE (killing the process) when writing to a dead peer; set `SO_NOSIGPIPE` via `setsockopt` to convert it to an EPIPE error return. -- *Ref: [field-notes.md](archives/features/automated-ui-testing_20260209_000430/field-notes.md)*
- **Codebase Discovery**: `CGWindowListCreateImage` captures in the display's native "Color LCD" ICC profile, not sRGB; saturated accent colors shift 55-104 Chebyshev units while desaturated colors shift only ~14 units -- use color-space-agnostic detection for saturated colors. -- *Ref: [field-notes.md](archives/features/automated-ui-testing_20260209_000430/field-notes.md)*
- **Codebase Discovery**: SCStream startup latency is ~200-400ms, exceeding most animation durations; use before/after static capture comparison with `CGWindowListCreateImage` instead of frame sequences for short transitions. -- *Ref: [field-notes.md](archives/features/automated-ui-testing_20260209_000430/field-notes.md)*
- **Codebase Discovery**: In Swift 6, closures created inside `@MainActor`-isolated methods inherit MainActor isolation; use `nonisolated static` functions to create closures that run on arbitrary queues (e.g., dispatch source handlers). -- *Ref: [field-notes.md](archives/features/automated-ui-testing_20260209_000430/field-notes.md)*
- **Codebase Discovery**: Swift Testing `@Suite(.serialized)` runs extension methods before main struct methods; use lazy auto-initialization (idempotent calibration) instead of relying on test execution order. -- *Ref: [field-notes.md](archives/features/automated-ui-testing_20260209_000430/field-notes.md)*
- **Codebase Discovery**: Threshold comparisons at exact boundary values (strict `>` vs `>=`) create knife-edge flakiness; set thresholds with empirical margin based on observed measurement variance across multiple runs. -- *Ref: [field-notes.md](archives/features/automated-ui-testing_20260209_000430/field-notes.md)*
