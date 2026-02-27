# mkdn — Implementation Roadmap

## Strategy: Thin Vertical Slice

Get a rough but working end-to-end review loop fast, then polish. Each milestone is independently valuable and testable.

## Dependency Graph

```
M1 (Any Text File)
 |
 v
M2 (Line Numbers) -----> M3 (Tappable Lines)
                            |
                            v
                          M4 (Annotations)
                            |
                            v
                          M5 (Filesystem Loop) -----> M6 (MCP Server)
                            |                            |
                            v                            v
                          M7 (Agent Messages,          M7 (Real-time
                              Conversation Rail)           Notifications)
```

## Milestones

### M1: Open Any Text File

Generalize the app to open source code files (not just markdown). When a code file is opened, render it as syntax-highlighted text. The sidebar shows all text files in the project.

**Changes**: FileValidator (FileKind enum), DirectoryScanner (show all text files), DocumentState (non-markdown content), CodeFileView (full-file code rendering), drag-drop + open dialog.

**Proof point**: Open `DocumentState.swift` in mkdn via CLI or sidebar. See beautifully rendered, syntax-highlighted Swift.

### M2: Line Numbers Gutter

NSRulerView-based line number gutter for code file rendering. Theme-aware colors. Scrolls in sync. Only for code files.

**Proof point**: Open a 500-line source file. Line numbers appear, scroll in sync, respect theme.

### M3: Tappable Lines + Selection Model

Click a line number to select that line. Shift-click for range. Visual highlight. LineSelection as @Observable data model.

**Proof point**: Click line 42, it highlights. Shift-click 50, range highlights. Selection accessible programmatically.

### M4: Inline Annotation + Local Storage

Annotation popover on selected lines. Type comment, press Enter. Stored as JSON in `.mkdn/annotations/`. Gutter badges on annotated lines.

**Proof point**: Annotate lines 42-50 with "This should use a Result type." Close, reopen. Annotation persists.

### M5: Filesystem Feedback Channel (MVP Loop)

"Send" action writes annotation to `.mkdn/feedback/`. DirectoryWatcher on `.mkdn/agent-messages/`. Inline agent message card rendering. Response handling. CLAUDE.md integration instructions.

**Proof point**: Full loop — annotate in mkdn, Claude Code reads feedback, responds, mkdn renders response inline.

### M6: MCP Server (Deferred)

In-process HTTP MCP server. `get_pending_feedback` tool. `list_changed` notifications. Real-time integration with Claude Code.

### M7: Conversation Rail + Polish (Deferred)

Diff rendering, session history, multiple concurrent agents, voice annotation.

## Build vs. Wait

| Build Now | Wait |
|-----------|------|
| Code file rendering (M1-M2) | Diff rendering |
| Line selection + annotations (M3-M4) | Voice input |
| Filesystem feedback channel (M5) | Agent dispatch / sub-agents |
| | Long-lived session management |

## Design Constraints

All new UI must follow the established design language:
- 8pt grid (SpacingConstants)
- Solarized theme colors (ThemeColors)
- Animation system (AnimationConstants + MotionPreference)
- Zen-like reading experience — whitespace is structure, not absence
- Every element deserves the same care as the core rendering engine
