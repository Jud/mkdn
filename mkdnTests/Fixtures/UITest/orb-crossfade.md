<!--
  Fixture: orb-crossfade.md
  Purpose: Minimal Markdown content for orb animation capture tests.
           Provides a non-busy background so the orb indicator (bottom-right)
           is clearly visible during crossfade and breathing animations.
  Used by: OrbVisionCaptureTests -- triggers file-change on disk to activate
           the orb's violet-to-orange crossfade and breathing pulse.

  Expected rendering characteristics:
  - One heading and one paragraph: enough to activate the view but minimal
    visual noise around the orb's position (bottom-right corner)
  - No Mermaid or code blocks to avoid long render times
  - FileWatcher monitors this file; the test appends content to trigger
    the file-changed orb state
-->

# Orb Crossfade Test

This document is used to verify the orb indicator's color crossfade transition and breathing animation. The content is intentionally minimal so the orb is clearly visible against a quiet background.
