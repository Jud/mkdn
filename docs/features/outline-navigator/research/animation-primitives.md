# Available Animation Primitives

**Date:** 2026-03-21
**Source:** `mkdn/UI/Theme/AnimationConstants.swift`, `mkdn/UI/Theme/MotionPreference.swift`

## Finding

The animation system provides named primitives resolved through `MotionPreference` for Reduce Motion support. The outline navigator should use existing primitives: `springSettle` for the breadcrumb-to-HUD expand/collapse, `fadeIn`/`fadeOut` for breadcrumb visibility, and `quickFade` for item highlights. `MotionPreference.Primitive` enum would need a new case if the breadcrumb/HUD animation is distinct from existing primitives, or it can reuse `springSettle` (the same primitive used for the find bar).

## Evidence

Relevant existing primitives:
- `springSettle` (response: 0.35, damping: 0.7) -- used by FindBarView for entrance
- `gentleSpring` (response: 0.4, damping: 0.85) -- layout transitions
- `quickFade` (easeOut 0.2s) -- fast exit
- `crossfade` (easeInOut 0.35s) -- state transitions
- `reducedCrossfade` (easeInOut 0.15s) -- Reduce Motion alternative
- `reducedInstant` (linear 0.01s) -- near-instant Reduce Motion alternative

The breadcrumb-to-HUD expansion is conceptually closest to `springSettle` (a surface bouncing into existence). The breadcrumb fade-in/out on scroll is closest to `fadeIn`/`fadeOut`.
