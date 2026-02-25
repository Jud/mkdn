# Project Charter: mkdn
**Version**: 1.0.0 | **Status**: Final | **Created**: 2026-02-06

## Vision
A beautiful, simple, Mac-native Markdown viewer and editor that integrates seamlessly into terminal-based developer workflows — open, render beautifully, edit, close.

## Problem & Context
Developers working with LLMs and coding agents regularly produce Markdown artifacts — documentation, reports, specs, and notes. There is no great Mac-native app to quickly open these files from the terminal, view them with terminal-consistent theming (e.g., Solarized), and optionally edit them. Existing tools are either too heavyweight (full editors like VS Code) or too limited (terminal-based renderers). The gap is a lightweight, beautiful viewer that fits naturally into a terminal-centric development workflow.

## Target Users
Developers who use LLMs and coding agents in their daily workflow and need to quickly view and edit Markdown artifacts. These users work primarily from the terminal, value aesthetics and simplicity, and want tooling that respects their terminal environment — consistent theming, CLI launchability, and minimal friction between generating and reading Markdown.

## Business Rationale
mkdn provides a beautiful, simple, Mac-native Markdown viewing and editing experience that integrates seamlessly into terminal-based developer workflows. Key differentiators include terminal-consistent theming, first-class Mermaid chart rendering with native gestures (pinch-to-zoom, two-finger scroll), a split-screen toggle between reading and editing modes, and CLI-launchability via Homebrew. The core value proposition is beauty and simplicity — open, render beautifully, edit, close.

## Design Philosophy
Every visual and interactive element must be crafted with obsessive attention to sensory detail. Animations are timed to human rhythms (e.g., breathing rate for pulsing indicators, ~12 cycles/min). Transitions feel physical and natural. The app should feel like it was designed by someone who cares about the difference between "good enough" and "perfect." No element is too small to get right — if it moves, glows, fades, or responds to input, it deserves the same care as the core rendering engine.

## Scope Guardrails
### Will Do
- Split-screen toggle: preview-only reading mode vs. side-by-side edit + preview
- First-class Mermaid chart rendering via WKWebView + bundled mermaid.js (one web view per diagram). Supports flowchart, sequence, state, class, ER diagrams. Click-to-focus interaction with pinch-to-zoom and pan
- Terminal-consistent theming (e.g., Solarized)
- Syntax highlighting for code blocks (paramount)
- CLI-launchable (`mkdn file.md`)
- Homebrew installable
- File-change detection: subtle "outdated" indicator when file changes on disk, with manual reload prompt (not auto-reload)

### Won't Do
- Cloud sync
- Collaboration features
- Export formats (PDF, HTML, etc.)
- Plugin system
- iOS/iPad support
- File management or file browser UI

## Success Criteria
Personal daily-driver use — the project succeeds when the creator uses it every day in their own development workflow as the default way to view and edit Markdown artifacts produced by coding agents and LLMs.
