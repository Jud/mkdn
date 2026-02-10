# Design Evaluation Prompt

You are evaluating screenshots of mkdn, a Mac-native Markdown viewer, against its design specifications. Your task is to identify any visual deviations from the documented design intent.

## Design Philosophy (from Project Charter)

{charter_design_philosophy}

## Design Specifications

{prd_excerpts}

## Evaluation Criteria

Evaluate each screenshot against the following five dimensions:

### 1. Concrete PRD Compliance

Does the rendering match the specific functional requirements listed in the PRD excerpts above? Check:

- Spacing values (margins, padding, inter-element gaps) against documented constants
- Color values (background, foreground, accent, code block, syntax tokens) against theme specifications
- Layout structure (content width, alignment, indentation) against documented constraints
- Component rendering (code blocks, blockquotes, lists, tables, headings) against documented styling
- Typography (font sizes, line heights, heading hierarchy) against documented specifications

### 2. Spatial Rhythm and Balance

Is the vertical spacing between elements consistent and rhythmic? Evaluate:

- Vertical rhythm: are the gaps between consecutive blocks of the same type consistent?
- Heading hierarchy: do larger headings have proportionally more space above them?
- Gestalt proximity: do headings bind visually to their following content (less space below than above)?
- Content grouping: do related elements (list items, nested content) feel like cohesive units?
- Document margins: does the whitespace framing the content feel balanced and generous?

### 3. Theme Coherence

Are all colors consistent with the active theme? Evaluate:

- Background uniformity: is the document background a single, consistent color?
- Text contrast: is there sufficient contrast between text and background for comfortable reading?
- Code block distinction: do code blocks have a visually distinct background from the document?
- Syntax highlighting: do code tokens use distinct, readable colors from the theme palette?
- Heading colors: do headings use the correct accent or foreground color per the theme?
- Overall palette: do all visible colors belong to the same Solarized family (no stray colors)?

### 4. Visual Consistency

Are similar elements rendered consistently? Evaluate:

- Same-level headings: do all H2s look identical? All H3s?
- Paragraph text: is body text rendered with consistent font, size, and color throughout?
- Code blocks: do all code blocks use the same background color, padding, and font?
- List items: are bullet/number styles and indentation consistent across all lists?
- Spacing uniformity: are the gaps between similar element pairs (e.g., paragraph-to-paragraph) the same throughout?

### 5. Overall Rendering Quality

Does the rendering meet the charter's standard of "obsessive attention to sensory detail"? Evaluate:

- Would this be acceptable for daily-driver use by a developer who cares about aesthetics?
- Does the overall composition feel polished and intentional, or rough and ad-hoc?
- Are there any rendering artifacts, alignment issues, or visual glitches?
- Does the reading experience feel like a well-designed printed page or a hastily assembled web page?

## Capture Context

{capture_context}

## Output Format

Respond with a JSON object matching the following schema. Include ONLY the JSON in your response, with no additional text before or after it.

{output_schema}

## Important Guidelines

1. Be specific: reference exact PRD functional requirements (e.g., "spatial-design-language FR-3") when identifying concrete compliance issues.
2. Be calibrated: use "high" confidence only when you can clearly see a deviation from a specific documented value. Use "medium" when the deviation is likely but you cannot measure precisely from the screenshot. Use "low" for subtle qualitative impressions.
3. Distinguish severity: "critical" means the issue blocks daily-driver use (broken rendering, unreadable text). "major" means a noticeable design regression (wrong colors, clearly wrong spacing). "minor" means a subtle polish issue (slightly uneven rhythm, marginal contrast).
4. For qualitative findings, reference the charter's design philosophy rather than specific PRD functional requirements.
5. If a screenshot looks correct and well-designed, say so. Do not manufacture issues. An evaluation with zero issues is a valid and valuable result.
6. When comparing screenshots across themes (dark and light), note any inconsistencies in spacing, layout, or element rendering that differ between themes (spacing should be theme-independent).
