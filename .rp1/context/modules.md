# mkdn Module Inventory

## App Layer (`mkdn/App/`)

| File | Purpose |
|------|---------|
| mkdnApp.swift | @main entry, WindowGroup, commands |
| AppState.swift | Central @Observable state |
| ViewMode.swift | Preview-only vs side-by-side enum |
| ContentView.swift | Root view, mode switching, toolbar |
| MkdnCommands.swift | Menu bar commands |

## Core Layer (`mkdn/Core/`)

### Markdown (`Core/Markdown/`)
| File | Purpose |
|------|---------|
| MarkdownRenderer.swift | Parse + render coordinator |
| MarkdownBlock.swift | Block element enum |
| MarkdownVisitor.swift | swift-markdown walker -> MarkdownBlock |

### Mermaid (`Core/Mermaid/`)
| File | Purpose |
|------|---------|
| MermaidRenderer.swift | Actor: JSC + beautiful-mermaid -> SVG -> NSImage |

### FileWatcher (`Core/FileWatcher/`)
| File | Purpose |
|------|---------|
| FileWatcher.swift | DispatchSource file monitoring |

### CLI (`Core/CLI/`)
| File | Purpose |
|------|---------|
| CLIHandler.swift | Argument parsing for `mkdn file.md` |

## Features Layer (`mkdn/Features/`)

### Viewer (`Features/Viewer/`)
| File | Purpose |
|------|---------|
| Views/MarkdownPreviewView.swift | Full-width preview |
| Views/MarkdownBlockView.swift | Block element renderer |
| Views/CodeBlockView.swift | Syntax-highlighted code |
| Views/MermaidBlockView.swift | Mermaid diagram with zoom |
| Views/TableBlockView.swift | Native table rendering |
| ViewModels/PreviewViewModel.swift | Preview state management |

### Editor (`Features/Editor/`)
| File | Purpose |
|------|---------|
| Views/SplitEditorView.swift | HSplitView editor + preview |
| Views/MarkdownEditorView.swift | TextEditor wrapper |
| ViewModels/EditorViewModel.swift | Editor state management |

### Theming (`Features/Theming/`)
| File | Purpose |
|------|---------|
| ThemePickerView.swift | Theme selection UI |

## UI Layer (`mkdn/UI/`)

### Components (`UI/Components/`)
| File | Purpose |
|------|---------|
| OutdatedIndicator.swift | File-changed badge |
| ViewModePicker.swift | Mode toggle toolbar item |
| WelcomeView.swift | Empty state screen |
| OrbVisual.swift | Reusable 3-layer orb (outerHalo, midGlow, innerCore) with RadialGradient. Params: color, isPulsing, isHaloExpanded. Visual-only -- no animation state. |
| PulsingSpinner.swift | Orb-rhythm loading spinner using `AnimationConstants.breathe`. Static full-opacity when Reduce Motion is on. |
| HoverFeedbackModifier.swift | `HoverFeedbackModifier` (scale) and `BrightnessHoverModifier` (brightness overlay). View extensions `.hoverScale(_:)` and `.hoverBrightness()`. Uses quickSettle animation, nil for RM. |
| FileChangeOrbView.swift | File-changed pulsing orb. Delegates to `OrbVisual`, owns animation state, hover feedback via `.hoverScale()`, tap-to-reload popover. |
| ModeTransitionOverlay.swift | Ephemeral mode-name overlay. Spring-settle entrance, quick-fade exit, auto-dismiss after 1.5s. RM uses reducedCrossfade for both. |

### Theme (`UI/Theme/`)
| File | Purpose |
|------|---------|
| AppTheme.swift | Theme enum |
| ThemeColors.swift | Color palette struct |
| SolarizedDark.swift | Dark theme values |
| SolarizedLight.swift | Light theme values |
| AnimationConstants.swift | Named animation primitives (breathe, haloBloom, springSettle, gentleSpring, quickSettle, fadeIn, fadeOut, crossfade, quickFade, quickShift), stagger/hover/focus constants, orb colors, overlay timing, reduce-motion alternatives. MARK-delimited groups. |
| MotionPreference.swift | Reduce Motion resolver. `MotionPreference(reduceMotion:)` struct with `Primitive` enum. `resolved(_:)` returns `Animation?` (nil for continuous when RM on). `allowsContinuousAnimation` bool, `staggerDelay` accessor. |

## Dependencies

| Package | Purpose | Used In |
|---------|---------|---------|
| apple/swift-markdown | Markdown AST parsing | Core/Markdown |
| swhitty/SwiftDraw | SVG -> NSImage | Core/Mermaid |
| jectivex/JXKit | Swift JSC wrapper | Core/Mermaid |
| apple/swift-argument-parser | CLI args | Core/CLI |
| JohnSundell/Splash | Syntax highlighting | Features/Viewer |
