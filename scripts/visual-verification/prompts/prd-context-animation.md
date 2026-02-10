# PRD Context: Animation Entrance Behavior

## Animation Design Language

Source: animation-design-language PRD, AnimationConstants.swift

### Entrance Animation System

mkdn uses a staggered fade-in entrance animation when content loads. Each rendered block (heading, paragraph, code block, blockquote, etc.) fades in from fully invisible to fully visible with a per-block stagger delay creating a cascading reveal effect.

### FR-3: Fade Transitions (fadeIn)

Each block uses a 0.5-second ease-out fade-in animation (`AnimationConstants.fadeIn`). The element transitions from opacity 0 to opacity 1, decelerating into rest. The visual intent is a smooth emergence -- the element "arrives" gently.

### FR-4: Orchestration (Stagger)

Successive blocks have a 30ms stagger delay between them (`AnimationConstants.staggerDelay = 0.03`). The total stagger is capped at 0.5 seconds (`AnimationConstants.staggerCap = 0.5`) to prevent excessively long entrance sequences on large documents.

For a document with N blocks:
- Block 0 starts at t=0
- Block 1 starts at t=0.03s
- Block 2 starts at t=0.06s
- ...
- Block 16+ starts at t=0.5s (capped)

Each block's fade-in overlaps with the next, creating a smooth wave.

### Cover Layer Mechanism

The entrance animation uses a cover layer approach: each block has an opaque overlay (the "cover") that matches the appropriate background color and fades out to reveal the content beneath. This means:

- **Normal text blocks** (headings, paragraphs, blockquotes, lists): the cover color matches the **document background** color
- **Code blocks**: the cover color matches the **code block background** color (which is distinct from the document background)

**Known bug pattern to watch for**: If code blocks use the document background color for their cover instead of the code background color, the code block will appear to "flash" a wrong color before settling. The cover should be invisible against the code block's own background.

### Expected Visual Behavior in Frame Sequences

When evaluating a sequence of captured frames (at 30fps over ~3 seconds):

1. **First frames** (0-200ms): Elements should be mostly or fully invisible (covered). Due to SCStream startup latency (200-400ms), the very first frames may show the app in its pre-load state or early animation state.

2. **Early animation** (200ms-700ms): Elements should begin appearing in top-to-bottom order. Earlier elements should be more visible than later ones due to stagger.

3. **Mid animation** (700ms-1500ms): Most elements should be transitioning from partially visible to fully visible. The stagger cascade should be evident -- top elements fully visible while bottom elements are still fading in.

4. **Final frames** (1500ms+): All elements should be fully visible and settled. No residual cover layers should be visible.

### Evaluation Criteria for Animation Frames

When evaluating captured frame sequences:

#### (a) Opacity Transition
Do elements fade in from invisible to visible? Look for gradual opacity change, not instant appearance. Elements should not simply "pop" into view.

#### (b) Stagger Visibility
Is there a visible top-to-bottom cascade? Earlier elements (headings at the top) should become visible before later elements (paragraphs, code blocks further down). The stagger should be smooth, not jerky.

#### (c) Code Block Fade Behavior
Do code blocks fade in properly with opacity transition? Or do they appear to just slide in or appear without an opacity change? The code block cover layer should match the code background color so the fade is smooth against the code block's own background.

#### (d) Cover Layer Color Correctness
Are cover layers the correct color? During the fade animation:
- Normal block covers should match the document background (dark blue-gray for Solarized Dark, warm off-white for Solarized Light)
- Code block covers should match the code block background (slightly lighter/darker variant)
- If a code block's cover uses the wrong background color, you will see a visible color flash or mismatch during the transition.

#### (e) Animation Completion
Does the animation complete and settle within approximately 1.5 seconds? After that point, all content should be fully visible with no ongoing animation artifacts. The stagger cap (0.5s) plus the fade duration (0.5s) means the last element should finish by ~1.0s, with a margin to ~1.5s.

### Solarized Theme Background Colors

#### Solarized Dark
- Document background: base03 (#002b36) -- dark blue-gray
- Code block background: base02 (#073642) -- slightly lighter blue-gray

#### Solarized Light
- Document background: base3 (#fdf6e3) -- warm off-white
- Code block background: base2 (#eee8d5) -- slightly darker cream
