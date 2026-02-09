# PRD Context: Terminal-Consistent Theming and Syntax Highlighting

## Terminal-Consistent Theming

Source: terminal-consistent-theming PRD v1.0.0

### Theme System

mkdn uses Solarized Dark and Solarized Light themes that follow the macOS system appearance. The theme system has three modes:
- **Auto** (default): follows macOS dark/light setting
- **Solarized Dark**: pinned dark theme
- **Solarized Light**: pinned light theme

### FR-7: Theme Consistency

When the theme changes, the resolved theme updates immediately across all rendered content: markdown text, code blocks, and Mermaid diagrams. No element should display stale theme colors after a switch.

### NFR-1: Instantaneous Theme Switch

Theme switch must feel instantaneous (< 16ms for color swap). No flash of wrong theme at launch.

### Expected Theme Colors

#### Solarized Dark
- Background: dark blue-gray base (Solarized base03)
- Foreground text: light gray (Solarized base0)
- Heading text: accent color (varies by heading level)
- Code block background: slightly lighter than document background (Solarized base02)
- Code foreground: light gray matching body text

#### Solarized Light
- Background: warm off-white (Solarized base3)
- Foreground text: dark gray (Solarized base00)
- Heading text: accent color (varies by heading level)
- Code block background: slightly darker than document background (Solarized base2)
- Code foreground: dark gray matching body text

### Visual Evaluation Notes for Theming

When evaluating screenshots against this PRD:
- Verify background color matches the expected Solarized base for the active theme
- Verify text color provides strong contrast against the background
- Verify code block background is distinct from (but harmonious with) the document background
- Check that all colors belong to the Solarized palette (no stray non-Solarized colors)
- When comparing dark and light screenshots of the same content, verify layout and spacing are identical (only colors change)

---

## Syntax Highlighting

Source: syntax-highlighting PRD v1.0.0

### FR-3: Swift Syntax Highlighting

Swift code blocks are tokenized and rendered with colored text using the theme's syntax color palette. Each token type maps to a specific color from `SyntaxColors`.

### FR-4: Non-Swift Code Blocks

Non-Swift code blocks render as plain monospaced text in the theme's `codeForeground` color. They still have the code block background styling.

### FR-5: Language Label

A language label is displayed above the code block when a language tag is present in the Markdown fence.

### FR-8: Token-to-Color Mapping

Nine Splash `TokenType` cases map to `SyntaxColors` fields:

| Token Type | Semantic Role | Visual Expectation |
|------------|---------------|-------------------|
| keyword | Language keywords (func, let, var, if, else) | Distinct, prominent color |
| type | Type names (String, Int, Array) | Different from keywords |
| string | String literals ("hello") | Warm/distinct color |
| number | Numeric literals (42, 3.14) | Distinct from strings |
| comment | Comments (// ...) | Subdued/muted color |
| property | Properties and methods (.count, .isEmpty) | Different from types |
| dotAccess | Dot access syntax (.shared, .default) | Typically matches property color |
| preprocessing | Preprocessor directives (#if, #available) | Distinct color |
| call | Function calls (print(), map()) | Typically matches type or property color |

### NFR-5: Code Block Styling

Code blocks have rounded corners, a distinct background color, and consistent padding. The code text uses a monospaced font.

### Visual Evaluation Notes for Syntax Highlighting

When evaluating screenshots against this PRD:
- Check that Swift code blocks show multi-colored syntax tokens (not plain monospaced text)
- Verify different token types use visually distinct colors
- Verify code block has a distinct background from the document
- Check that code text is monospaced
- Verify language label presence above code blocks (when language tag exists)
- Check that non-Swift code blocks still have styling (background, padding) but no token coloring
- Verify syntax colors are readable against the code block background
