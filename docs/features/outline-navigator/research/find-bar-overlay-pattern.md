# Find Bar Overlay Pattern

**Date:** 2026-03-21
**Source:** `mkdn/Features/Viewer/Views/FindBarView.swift`, `mkdn/Features/Viewer/ViewModels/FindState.swift`, `mkdn/App/ContentView.swift`

## Finding

The FindBarView provides a proven reference implementation for overlay UI in mkdn: an `.ultraThinMaterial` frosted-glass surface positioned via `.frame(maxWidth:maxHeight:alignment:)`, controlled by an `@Observable` state class (`FindState`), with keyboard handling via `.onKeyPress()` modifiers. The pattern for integrating overlays is established in `ContentView` where `FindBarView()` is placed inside the root `ZStack` alongside the main content.

## Evidence

From `ContentView.swift:55-57`:
```swift
FindBarView()
    .allowsHitTesting(findState.isVisible)
    .accessibilityHidden(!findState.isVisible)
```

Key pattern elements:
- State class is `@MainActor @Observable`, lives as `@State` in `DocumentWindow`
- State is injected via `.environment()` and read via `@Environment` in the view
- State is published as `focusedSceneValue` for menu command access
- `.allowsHitTesting(false)` when hidden prevents invisible overlay from stealing clicks
- `.accessibilityHidden(!visible)` keeps VoiceOver clean
- Keyboard shortcuts registered in `MkdnCommands` via `@FocusedValue`
- FindBarView uses `@FocusState` for text field focus management
- Animations use `MotionPreference` pattern for Reduce Motion support

The outline navigator should follow this exact same integration pattern.
