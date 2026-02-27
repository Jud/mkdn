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

### The Agentic Review Session

The critical architectural insight: the review session is a **long-lived main thread** that stays lightweight, while all implementation work happens in disposable agent contexts.

```
mkdn                          Main Thread                    Agents
  │                          (long-lived)
  │  "rename this var"  ──▶  receives feedback
  │                          spawns agent      ──▶  Agent: renames var,
  │                                                 updates 3 callers,
  │                                                 writes files, exits
  │  ◀── file watcher picks up changes
  │  re-renders
  │
  │                          ◀── agent returns summary
  │  ◀── "renamed in 4 places,
  │       but UserService.swift
  │       has a related method
  │       — should I update that too?"
  │
  │  user taps "show me"  ──▶  navigates mkdn to that file
  │
  │  "yeah, update it"   ──▶  spawns another agent  ──▶  ...
```

The main thread's context is almost entirely **natural language** — short user comments, short agent summaries, short questions. No code dumps, no file contents, no tool output bloat. All of that lives in agents that come and go. You could review an entire codebase in one session.

### Protocol Design — Minimal MCP Surface

Context bloat kills long-lived agent sessions. The MCP API surface must be **surgical** — one tool, three fields:

**mkdn → Claude Code** (single MCP tool):
```
review_feedback { file, lines, comment }
```

**Claude Code → mkdn** (filesystem, not MCP):
```json
// .mkdn/agent-messages/001.json
{
  "type": "question",
  "text": "Update UserService too?",
  "file": "src/UserService.swift",
  "lines": [42, 45],
  "options": ["Yes", "Show me first", "Skip"]
}
```

mkdn watches the message directory, renders questions inline as cards near the relevant lines, and user responses flow back through the same `review_feedback` tool. Claude Code never needs a second tool. The return channel is just the filesystem.

This keeps the MCP context cost to one tool definition with three fields — minimal injection per message.

### Why This Architecture Works

- **The filesystem is shared state**: Both mkdn and Claude Code already read/write files. No new transport needed for most data flow.
- **MCP is the narrow feedback channel**: Only human reactions need a dedicated protocol. Everything else rides on file watching.
- **Agents keep the main thread lean**: Implementation details never enter the review conversation. The main thread holds intent ("user cares about naming consistency in this module") while agents hold execution.
- **Sessions can run for hours**: Because the main thread is natural language, not code, the context window lasts. One review session can cover an entire codebase.

### Open Questions

- Should code files render as enhanced markdown (fenced code blocks) or have their own dedicated renderer?
- How does voice input fit? (macOS dictation? Whisper? Something else?)
- What's the right UX for inline agent questions — floating cards? A conversation rail? Toast notifications?
- How should mkdn handle multiple concurrent agent responses?

### Phased Approach

**Phase 1 — Code Viewer**: Render source files with syntax highlighting and line numbers. Make lines tappable. No feedback channel yet, just beautiful code viewing integrated with the existing markdown experience.

**Phase 2 — Annotation Layer**: Add the ability to tap lines/ranges and attach text comments. Store annotations locally. Export as structured data (JSON, markdown).

**Phase 3 — Agent Integration**: Single MCP tool (`review_feedback`). File-based return channel (`.mkdn/agent-messages/`). Close the feedback loop with Claude Code.

**Phase 4 — Agentic Review Sessions**: Long-lived main thread with agent dispatch. Inline question rendering. Diff views. The full review-first development surface.
