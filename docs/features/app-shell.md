# App Shell

## Overview

The App Shell is mkdn's chrome-less window frame and global interaction layer. It removes the macOS title bar, hides traffic lights, and makes the entire window background-draggable -- giving rendered Markdown 100% of the viewport. All navigation happens through keyboard shortcuts exposed in the macOS menu bar. Visual feedback is delivered through two transient overlays: a breathing orb for file-change and default-handler prompts, and an ephemeral label for mode transitions and zoom confirmation.

## User Experience

On launch with no file, a centered welcome screen shows the app name and three ways to open a file (drag-and-drop, Cmd+O, CLI). Once a file is loaded, the window contains only the rendered content. There is no toolbar, no title bar text, and no visible window controls.

When the underlying file changes on disk, a small color-coded orb appears in the bottom-right corner, breathing at resting respiratory rate (~12 cycles/min). Tapping the orb opens a contextual popover; pressing Cmd+R reloads the file and dissolves the orb. If auto-reload is enabled, the orb completes one breath cycle then reloads automatically.

Switching between preview and edit modes (Cmd+1, Cmd+2) shows a brief label overlay ("Preview" / "Edit") that spring-animates in, holds for 1.5 seconds, then fades out. The same overlay confirms zoom changes ("125%") and theme switches. Rapid repeated shortcuts replace the current overlay without stacking.

## Architecture

The shell is split across three layers:

**Window configuration** -- `WindowAccessor` (an `NSViewRepresentable`) removes `.titled` from the style mask, adds `.resizable` + `.miniaturizable`, enables `isMovableByWindowBackground`, and applies a 10pt corner radius to the content view's backing layer.

**Global commands** -- `MkdnCommands` defines all menu bar items and keyboard shortcuts. It reads `AppSettings` for theme/zoom operations and `@FocusedValue(\.documentState)` for per-window document operations.

**Root composition** -- `ContentView` is a `ZStack` layering the active content view (welcome, preview, or split editor), the orb indicator (`TheOrbView`), the mode overlay (`ModeTransitionOverlay`), and the find bar.

State flows through two `@Observable` objects: `AppSettings` (app-wide: theme mode, zoom scale, auto-reload preference, all persisted to UserDefaults) and `DocumentState` (per-window: file URL, view mode, file watcher, overlay label).

## Implementation Decisions

**Title bar removal vs. full-screen transparency.** The shell removes `.titled` from the style mask rather than using `NSWindow.titlebarAppearsTransparent`. This fully eliminates the compositing layer that covers scrolled content, at the cost of losing native traffic lights. Background draggability via `isMovableByWindowBackground` replaces the title bar drag region.

**Unified orb indicator.** Rather than separate indicators for file-change and default-handler prompts, a single `TheOrbView` resolves the highest-priority `OrbState` (fileChanged > defaultHandler > idle) and renders one orb with a color crossfade between states. This keeps the visual surface minimal.

**Animation constants as a single enum.** All timing values live in `AnimationConstants` -- durations, spring parameters, orb colors, hover scales, stagger delays, and Reduce Motion alternatives. `MotionPreference` wraps `accessibilityReduceMotion` and resolves named primitives to their standard or reduced animation, keeping accessibility logic out of individual views.

**Zoom persistence.** `AppSettings.scaleFactor` is stored in UserDefaults (range 0.5x--3.0x, 10% steps). Zoom In/Out/Reset commands mutate it and push a formatted label ("125%") to the mode overlay for transient confirmation.

## Keyboard Shortcuts

| Shortcut | Action | Menu Location |
|----------|--------|---------------|
| Cmd+O | Open file (NSOpenPanel, .md/.markdown) | File > Open... |
| Cmd+W | Close window | File > Close |
| Cmd+S | Save | File > Save |
| Cmd+Shift+S | Save As | File > Save As... |
| Cmd+R | Reload from disk | File > Reload |
| Cmd+1 | Preview mode | View > Preview Mode |
| Cmd+2 | Edit mode (side-by-side) | View > Edit Mode |
| Cmd+T | Cycle theme (skips visually-identical modes) | View > Cycle Theme |
| Cmd++ | Zoom in (+10%) | View > Zoom In |
| Cmd+- | Zoom out (-10%) | View > Zoom Out |
| Cmd+0 | Actual size (reset to 100%) | View > Actual Size |
| Cmd+Shift+L | Toggle sidebar (directory mode only) | View > Toggle Sidebar |
| Cmd+F | Find | Edit > Find... |
| Cmd+G | Find next | Edit > Find Next |
| Cmd+Shift+G | Find previous | Edit > Find Previous |
| Cmd+E | Use selection for find | Edit > Use Selection for Find |
| Cmd+P | Print | File > Print... |
| Cmd+Shift+P | Page setup | File > Page Setup... |

## Files

| File | Role |
|------|------|
| `mkdn/App/MkdnCommands.swift` | All menu bar commands and keyboard shortcuts |
| `mkdn/App/ContentView.swift` | Root ZStack composing content, orb, overlay, find bar |
| `mkdn/App/AppSettings.swift` | App-wide persisted state (theme, zoom, auto-reload) |
| `mkdn/UI/Components/WindowAccessor.swift` | NSView bridge that strips title bar and configures window |
| `mkdn/UI/Components/WelcomeView.swift` | No-file-open welcome screen with open instructions |
| `mkdn/UI/Components/TheOrbView.swift` | Stateful orb: state resolution, tap-to-popover, auto-reload |
| `mkdn/UI/Components/OrbVisual.swift` | 3-layer radial gradient orb rendering (halo, glow, core) |
| `mkdn/UI/Components/OrbState.swift` | Priority-ordered enum: idle, defaultHandler, fileChanged |
| `mkdn/UI/Components/ModeTransitionOverlay.swift` | Ephemeral label with spring-in, 1.5s hold, fade-out |
| `mkdn/UI/Components/HoverFeedbackModifier.swift` | Scale and brightness hover effects for interactive elements |
| `mkdn/UI/Theme/AnimationConstants.swift` | Single source of truth for all animation timing and colors |
| `mkdn/UI/Theme/MotionPreference.swift` | Reduce Motion resolver mapping primitives to alternatives |

## Dependencies

- **AppKit** (`NSWindow`, `NSOpenPanel`, `NSCursor`, `NSWorkspace`) -- window configuration, file dialogs, cursor feedback, accessibility queries.
- **Carbon** (`IsSecureEventInputEnabled`) -- secure input check during window activation.
- **SwiftUI** -- all UI composition, animation, environment bridging.
- No external packages. No WKWebView usage in any shell component.

## Testing

Unit tests in `mkdnTests/Unit/Features/`:

- **`ControlsTests.swift`** -- verifies `DocumentState.switchMode(to:)` sets both `viewMode` and `modeOverlayLabel`, and that `isFileOutdated` delegates to the file watcher.
- **`AppSettingsTests.swift`** -- covers `cycleTheme()` skip logic on dark/light systems, zoom clamp boundaries (0.5x min, 3.0x max), `zoomLabel` formatting, UserDefaults round-trip for all persisted properties, and `systemColorScheme` init-time resolution from OS appearance.

Visual verification via the test harness (`swift run mkdn --test-harness` + `scripts/mkdn-ctl`) covers window chrome absence, orb breathing rhythm, overlay timing, theme crossfade smoothness, and Reduce Motion fallback behavior. These are not automated -- they require screenshot capture and manual inspection.
