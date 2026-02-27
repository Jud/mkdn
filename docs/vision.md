# mkdn — Product Vision

## From Markdown Viewer to Review-First Development Surface

mkdn started as a native macOS markdown viewer. But what we've built — beautiful native rendering for rich media (tables, mermaid diagrams, math, images, syntax-highlighted code), a responsive sidebar for navigating file trees, and a design language that feels good to sit in — is actually the foundation for something much bigger.

### The Core Insight

The traditional IDE is built around *writing* code. But the emerging workflow with AI coding agents (Claude Code, etc.) is fundamentally about *reviewing and directing*. You're not typing every character — you're reading generated work, spotting issues, giving feedback, and steering. The tool you need for that isn't a text editor with an AI bolted on. It's a **beautiful renderer with a feedback channel**.

mkdn is already most of that.

### The Interaction Model

Imagine opening a repository in mkdn:

1. **Browse**: The sidebar populates with the project tree. As an AI agent works (e.g., Claude Code running in a terminal), new and modified files appear in real time.

2. **Render**: Click any file and it renders beautifully — markdown with full rich media, Swift/Python/JS with syntax highlighting and line numbers, diffs with inline annotations. Not a code editor. A code *viewer* optimized for comprehension.

3. **React**: Tap a line or select a range. Give quick feedback — voice, text, or structured annotations. "This variable name is confusing." "This function is too long." "Why did you change this?" The feedback is lightweight and contextual, not a full code review workflow.

4. **Flow back**: That feedback flows as structured input back to the running AI agent. The agent receives it, adjusts, and the updated file re-renders in mkdn. The loop is tight: render → react → regenerate → render.

5. **Artifacts**: Beyond code, the AI agent produces markdown artifacts (plans, reports, design docs). These render natively in mkdn with full fidelity — tables, diagrams, math. You're reviewing everything in one surface.

### What Makes This Different

- **Not an editor**: mkdn doesn't need to be VSCode. It doesn't need a language server, autocomplete, or a terminal. It needs to render beautifully and capture feedback efficiently.
- **Native feel**: SwiftUI + AppKit means it can feel like a first-class Mac app, not an Electron wrapper. The "good feel" matters when you're spending hours in review flow.
- **Rich media first**: Mermaid diagrams, LaTeX math, tables, images — these aren't afterthoughts. They're core to how AI agents communicate their work.
- **Bidirectional**: The missing piece is the feedback channel. A way to send structured annotations back to the agent that generated the content.

### Technical Building Blocks

#### Already Have
- Native markdown rendering with rich media (tables, mermaid, math, images)
- Syntax-highlighted code blocks
- Directory sidebar with file tree navigation
- Theme system (light/dark with instant switching)
- File watching for live updates
- Overlay positioning system for inline rich content

#### Need to Build
- **Line-addressable code rendering**: Tap/click on specific lines or ranges in code blocks. Line numbers as interaction targets.
- **Annotation layer**: Lightweight feedback UI — tap a line, speak or type a quick note, attach it to a specific location. Structured output (file, line range, comment text).
- **Agent communication protocol**: A way to send structured feedback to a running Claude Code session (or similar). Could be:
  - Claude Code MCP server integration (bidirectional tool use)
  - Local socket/HTTP API that Claude Code plugins can connect to
  - File-based protocol (write feedback to a watched file that the agent picks up)
  - Clipboard-based for simplest MVP (copy structured feedback)
- **Diff rendering**: Inline diff view showing what changed, with the same annotation capability.
- **Live file watching in sidebar**: Auto-refresh when the AI agent modifies files in the project tree.

### Open Questions

- What's the simplest viable feedback loop? (File-based? MCP? Clipboard?)
- Should code files render as enhanced markdown (fenced code blocks) or have their own dedicated renderer?
- How does voice input fit? (macOS dictation? Whisper? Something else?)
- Is there a Claude Code hook/plugin API that could receive structured feedback?
- How do we handle large repositories in the sidebar without performance issues?

### Phased Approach

**Phase 1 — Code Viewer**: Render source files with syntax highlighting and line numbers. Make lines tappable. No feedback channel yet, just beautiful code viewing integrated with the existing markdown experience.

**Phase 2 — Annotation Layer**: Add the ability to tap lines/ranges and attach text comments. Store annotations locally. Export as structured data (JSON, markdown).

**Phase 3 — Agent Integration**: Connect annotations to a running AI agent. Explore Claude Code MCP integration, local API, or file-based protocols. Close the feedback loop.

**Phase 4 — Live Collaboration**: Real-time file watching, auto-refresh on changes, diff views, artifact streaming. The full review-first development surface.
