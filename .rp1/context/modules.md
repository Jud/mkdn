# Module & Component Breakdown

**Project**: mkdn
**Analysis Date**: 2026-02-25
**Modules Analyzed**: 15

## App Layer (`mkdn/App/`)

Application shell: SwiftUI lifecycle, per-window document management, menu commands, file-open coordination.

| File | Purpose |
|------|---------|
| `DocumentState.swift` | Per-window `@Observable`: file I/O, unsaved detection, view mode, FileWatcher ownership |
| `DocumentWindow.swift` | WindowGroup scene definition, environment injection, launch context consumption |
| `AppSettings.swift` | App-wide `@Observable`: theme mode, scale factor, auto-reload, UserDefaults persistence |
| `ContentView.swift` | Root view: switches between WelcomeView, MarkdownPreviewView, SplitEditorView |
| `AppDelegate.swift` | NSApplicationDelegate: Finder file-open events, icon masking, Cmd-W monitor |
| `MkdnCommands.swift` | Menu commands: Save, Save As, Find, Zoom, View Mode, Theme, Reload, Open |
| `OpenRecentCommands.swift` | Open Recent submenu via NSDocumentController |
| `FileOpenCoordinator.swift` | Routes Finder-opened URLs to DocumentWindow via pendingURLs array |
| `LaunchItem.swift` | Discriminated union (.file/.directory) for WindowGroup routing |
| `ViewMode.swift` | Display mode enum: previewOnly, sideBySide |
| `FocusedDocumentStateKey.swift` | FocusedValueKey for cross-window DocumentState access |
| `FocusedDirectoryStateKey.swift` | FocusedValueKey for DirectoryState access |
| `FocusedFindStateKey.swift` | FocusedValueKey for FindState access |
| `DirectoryModeKey.swift` | EnvironmentKey for directory mode flag |

## Core/Markdown (`mkdn/Core/Markdown/`)

Markdown parsing pipeline: AST visitor, block model, NSAttributedString builder.

| File | Purpose |
|------|---------|
| `MarkdownBlock.swift` | Block element enum (12 cases) + IndexedBlock + ListItem + CheckboxState + stable DJB2 hashing |
| `MarkdownVisitor.swift` | Walks swift-markdown Document AST → [MarkdownBlock]. Inline styling, table conversion, math detection |
| `MarkdownRenderer.swift` | Stateless facade: parse text → Document → MarkdownVisitor → [IndexedBlock] |
| `MarkdownTextStorageBuilder.swift` | Main builder: [IndexedBlock] → NSAttributedString + AttachmentInfo + TableOverlayInfo |
| `MarkdownTextStorageBuilder+Blocks.swift` | Block-level rendering: headings, paragraphs, lists, blockquotes, thematic breaks |
| `MarkdownTextStorageBuilder+Complex.swift` | Complex block rendering: code blocks with syntax highlighting, images |
| `MarkdownTextStorageBuilder+MathInline.swift` | Inline math ($...$) → NSTextAttachment with baseline alignment |
| `MarkdownTextStorageBuilder+TableInline.swift` | Table → invisible inline text with TableCellMap for selection/copy |
| `TableCellMap.swift` | Character offset → cell position mapping. Binary search, range intersection, RTF/TSV export |
| `TableColumnSizer.swift` | Content-aware column width computation with proportional compression |
| `TableAttributes.swift` | Custom NSAttributedString keys for table rendering metadata |
| `CodeBlockAttributes.swift` | Custom NSAttributedString keys for code block rendering and copy |
| `LinkNavigationHandler.swift` | URL classification: local Markdown (in-app), external (system), other local file |
| `PlatformTypeConverter.swift` | SwiftUI → AppKit bridge: NSColor, fonts, paragraph styles with scale factor |

## Core/Highlighting (`mkdn/Core/Highlighting/`)

Tree-sitter based syntax highlighting for code blocks.

| File | Purpose |
|------|---------|
| `SyntaxHighlightEngine.swift` | Stateless engine: language tag → colored NSMutableAttributedString. 16 languages |
| `TreeSitterLanguageMap.swift` | Maps fence tags (with aliases) to tree-sitter LanguageConfig |
| `TokenType.swift` | Universal token enum (13 types). Capture name → color resolution |
| `HighlightQueries.swift` | Embedded highlight.scm query strings for each language |

## Core/Math (`mkdn/Core/Math/`)

LaTeX math rendering via SwiftMath.

| File | Purpose |
|------|---------|
| `MathRenderer.swift` | LaTeX → NSImage via SwiftMath MathImage. Display + inline modes, baseline offset |
| `MathAttributes.swift` | Custom NSAttributedString key marking inline math ranges with LaTeX source |

## Core/Mermaid (`mkdn/Core/Mermaid/`)

Mermaid diagram rendering via WKWebView.

| File | Purpose |
|------|---------|
| `MermaidWebView.swift` | NSViewRepresentable wrapping WKWebView. Template loading, JS bridge, size reporting |
| `MermaidThemeMapper.swift` | Maps AppTheme → Mermaid.js themeVariables JSON |
| `MermaidRenderState.swift` | Lifecycle enum: loading, rendered, error(String) |
| `MermaidError.swift` | LocalizedError types for rendering failures |

## Core/FileWatcher (`mkdn/Core/FileWatcher/`)

| File | Purpose |
|------|---------|
| `FileWatcher.swift` | `@Observable` per-document monitor: DispatchSource → AsyncStream → isOutdated flag. Pause/resume around saves |

## Core/DirectoryScanner (`mkdn/Core/DirectoryScanner/`)

| File | Purpose |
|------|---------|
| `DirectoryScanner.swift` | Recursive directory scanner: builds FileTreeNode tree (Markdown only, max depth 10) |
| `FileTreeNode.swift` | Value-type tree node: directory (with children) or file (leaf). Depth tracking |

## Core/DirectoryWatcher (`mkdn/Core/DirectoryWatcher/`)

| File | Purpose |
|------|---------|
| `DirectoryWatcher.swift` | `@Observable` filesystem monitor for sidebar. Watches root + first-level subdirectories |

## Core/CLI (`mkdn/Core/CLI/`)

CLI argument parsing and launch context.

| File | Purpose |
|------|---------|
| `MkdnCLI.swift` | ArgumentParser command: variadic file argument, --test-harness flag |
| `LaunchContext.swift` | Static URL container: set in main.swift, consumed once by DocumentWindow |
| `FileValidator.swift` | Validates file paths: existence, readability, .md/.markdown extension |
| `DirectoryValidator.swift` | Validates directory paths: existence, readability |
| `CLIError.swift` | Typed errors with exit codes for terminal feedback |

## Core/Services (`mkdn/Core/Services/`)

| File | Purpose |
|------|---------|
| `DefaultHandlerService.swift` | Launch Services integration: register/check as default Markdown handler |

## Core/TestHarness (`mkdn/Core/TestHarness/`)

In-process test automation via Unix domain socket.

| File | Purpose |
|------|---------|
| `TestHarnessServer.swift` | AF_UNIX socket server, JSON protocol, socketQueue dispatch |
| `TestHarnessHandler.swift` | Command dispatch: load, capture, scroll, theme, quit on @MainActor |
| `CaptureService.swift` | Window screenshot capture to PNG |
| `FrameCaptureSession.swift` | SCStream-based animation frame capture at configurable FPS |
| `RenderCompletionSignal.swift` | Async signal for awaiting render completion before capture |
| `HarnessCommand.swift` | Command enum: JSON-decodable test harness protocol |
| `HarnessResponse.swift` | Response struct: JSON-encodable results |
| `HarnessError.swift` | Test harness error types |

## Features/Viewer (`mkdn/Features/Viewer/`)

Markdown preview rendering and interaction.

| File | Purpose |
|------|---------|
| `Views/MarkdownPreviewView.swift` | Preview orchestrator: debounced rendering, block diffing, entrance animation |
| `Views/SelectableTextView.swift` | NSViewRepresentable wrapping CodeBlockBackgroundTextView (NSTextView). TextKit 2, cross-block selection |
| `Views/OverlayCoordinator.swift` | Positions NSHostingView overlays for Mermaid/math/image/table blocks |
| `Views/OverlayCoordinator+Observation.swift` | KVO observation for text container geometry changes |
| `Views/OverlayCoordinator+TableHeights.swift` | Table height measurement for overlay sizing |
| `Views/OverlayCoordinator+TableOverlays.swift` | Table overlay lifecycle management |
| `Views/CodeBlockBackgroundTextView.swift` | Custom NSTextView: code block backgrounds, table cell highlights, print interception |
| `Views/CodeBlockBackgroundTextView+TableCopy.swift` | Table-aware copy: TSV + RTF pasteboard |
| `Views/CodeBlockBackgroundTextView+TablePrint.swift` | Print-time table rendering with PrintPalette |
| `Views/CodeBlockBackgroundTextView+TableSelection.swift` | Table cell selection suppression and highlight |
| `Views/EntranceAnimator.swift` | Staggered block entrance animation with MotionPreference |
| `Views/CodeBlockView.swift` | Code block container with language label |
| `Views/CodeBlockCopyButton.swift` | Copy-to-clipboard button for code blocks |
| `Views/MermaidBlockView.swift` | Mermaid diagram container: click-to-focus, cursor management |
| `Views/MathBlockView.swift` | Display math block rendering via MathRenderer |
| `Views/ImageBlockView.swift` | Async image loading from URL |
| `Views/TableBlockView.swift` | Table overlay view with header/data rows |
| `Views/TableHeaderView.swift` | Table header row styling |
| `Views/TableHighlightOverlay.swift` | Selection highlight overlay for table cells |
| `Views/FindBarView.swift` | In-document search UI: query input, match navigation, count display |
| `Views/MarkdownBlockView.swift` | Block type router: dispatches to specific block views |
| `ViewModels/FindState.swift` | `@Observable`: query, match ranges, current index, wrap-around navigation |
| `ViewModels/PreviewViewModel.swift` | Re-renders IndexedBlocks when text or theme changes |

## Features/Editor (`mkdn/Features/Editor/`)

Side-by-side Markdown editing.

| File | Purpose |
|------|---------|
| `Views/SplitEditorView.swift` | Split pane: editor left, preview right |
| `Views/MarkdownEditorView.swift` | Raw TextEditor bound to DocumentState.markdownContent |
| `Views/ResizableSplitView.swift` | Draggable split pane with snap-to-half logic |

## Features/Sidebar (`mkdn/Features/Sidebar/`)

Directory browser sidebar.

| File | Purpose |
|------|---------|
| `ViewModels/DirectoryState.swift` | `@Observable`: file tree, expansion state, selection, DirectoryWatcher |
| `Views/DirectoryContentView.swift` | Layout: sidebar + content with toggle animation |
| `Views/SidebarView.swift` | File tree list with recursive disclosure |
| `Views/SidebarRowView.swift` | Individual file/folder row with icon and name |
| `Views/SidebarHeaderView.swift` | Directory name header |
| `Views/SidebarDivider.swift` | Styled divider between sidebar and content |
| `Views/SidebarEmptyView.swift` | Empty state when no Markdown files found |

## UI/Theme (`mkdn/UI/Theme/`)

| File | Purpose |
|------|---------|
| `AppTheme.swift` | Theme enum: solarizedDark, solarizedLight. Provides ThemeColors + SyntaxColors |
| `ThemeColors.swift` | 13 semantic color slots + SyntaxColors (13 highlight slots) |
| `SolarizedDark.swift` | Solarized Dark palette values |
| `SolarizedLight.swift` | Solarized Light palette values |
| `ThemeMode.swift` | User preference: auto, solarizedDark, solarizedLight. Resolves via ColorScheme |
| `PrintPalette.swift` | Ink-efficient print colors (white bg, black text). Auto-applied during Cmd+P |
| `AnimationConstants.swift` | Named animation primitives: breathe, spring, fade, stagger, reduce-motion |
| `MotionPreference.swift` | Accessibility-aware animation resolution |

## UI/Components (`mkdn/UI/Components/`)

| File | Purpose |
|------|---------|
| `TheOrbView.swift` | Unified orb indicator: file-changed + default-handler prompts |
| `OrbState.swift` | Orb state enum with priority ordering |
| `OrbVisual.swift` | Orb rendering: gradient layers, breathing animation |
| `WelcomeView.swift` | Welcome screen with keyboard shortcut hints |
| `WindowAccessor.swift` | NSViewRepresentable: removes title bar, configures window chrome |
| `ModeTransitionOverlay.swift` | "Preview" / "Editor" label overlay on mode switch |
| `PulsingSpinner.swift` | Mermaid loading indicator at orb breathing rhythm |
| `UnsavedIndicator.swift` | Dot indicator for unsaved changes |
| `HoverFeedbackModifier.swift` | Reusable hover scale + cursor modifier |

## External Dependencies

| Package | Purpose |
|---------|---------|
| apple/swift-markdown | Markdown AST parsing |
| ChimeHQ/SwiftTreeSitter + 16 grammar packages | Syntax highlighting |
| mgriebling/SwiftMath | LaTeX math rendering |
| apple/swift-argument-parser | CLI argument parsing |
| Mermaid.js (bundled) | Diagram rendering in WKWebView |

## Test Layer (`mkdnTests/`)

55 test files organized as `Unit/Core/`, `Unit/Features/`, `Unit/UI/`, `Unit/Support/`. Uses Swift Testing (`@Test`, `#expect`, `@Suite`). Support utilities: `ImageAnalyzer`, `SpatialMeasurement`, `FrameAnalyzer`, `TestHarnessClient`, `SyntheticImage`, `JSONResultReporter`, `PRDCoverageTracker`.
