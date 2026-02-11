# PRD Context: Orb Indicator Animations

## The Orb

Source: animation-design-language PRD, AnimationConstants.swift, OrbState.swift, TheOrbView.swift

mkdn uses a unified orb indicator positioned in the bottom-right corner of the window. The orb communicates application state through color and animation. It is rendered as a 3-layer radial gradient (outer halo, mid glow, inner core) creating a depth effect.

### Orb States and Colors

The orb has distinct color states, each tied to a specific meaning:

| State | Color | Hex | RGB (0-1) | Meaning |
|-------|-------|-----|-----------|---------|
| Default Handler | Solarized Violet | #6c71c4 | (0.424, 0.443, 0.769) | First-launch hint to set mkdn as default Markdown reader |
| File Changed | Solarized Orange | #cb4b16 | (0.796, 0.294, 0.086) | File on disk has changed since last load |
| Update Available | Solarized Green | #859900 | (0.522, 0.600, 0.000) | Application update available (placeholder) |

Priority order (highest wins): File Changed > Default Handler > Update Available > Idle (hidden).

### Color Crossfade Transition

When the orb transitions between states (e.g., from Default Handler violet to File Changed orange), it uses a **crossfade** animation:

- **Duration**: 0.35 seconds
- **Curve**: easeInOut (symmetric acceleration/deceleration)
- **Visual behavior**: The orb's color blends smoothly from the old state's color to the new state's color. There should be no abrupt color jump -- the transition should appear as a continuous gradient blend.

#### Expected Crossfade Sequence in Frames (at 30fps)

For a violet-to-orange crossfade:
1. **Pre-trigger frames**: Orb is solid violet (#6c71c4), pulsing with the breathing animation.
2. **Transition frames** (~10-11 frames at 30fps for 0.35s): Color gradually shifts from violet through intermediate blended hues toward orange. The easeInOut curve means the transition starts slowly, accelerates in the middle, and decelerates at the end.
3. **Post-transition frames**: Orb is solid orange (#cb4b16), continuing to pulse.

### Breathing Animation (Pulse)

The orb continuously pulses with a breathing rhythm derived from human resting respiratory rate:

- **Rhythm**: ~12 cycles per minute (~5 second full cycle)
- **Half-cycle duration**: 2.5 seconds (easeInOut sinusoidal)
- **Core behavior**: The inner core modulates opacity and scale between resting and peak states.
- **Halo behavior**: The outer halo expands and contracts on a slightly slower cycle (3.0s half-cycle) creating a phase offset for organic depth.

#### Expected Breathing in Frames (at 30fps over 8s)

The breathing animation should show:
1. **Continuous pulse**: The orb's brightness/glow oscillates smoothly. Look for a sinusoidal modulation in the orb's apparent brightness and size.
2. **No freezing**: The orb should never stop pulsing -- the animation repeats forever while visible.
3. **Organic rhythm**: The outer halo and inner core should NOT be perfectly synchronized. The slight phase offset (2.5s vs 3.0s) creates a living, organic feel rather than a mechanical pulse.
4. **Approximately 1.5-2 full breathing cycles** should be visible in an 8-second capture.

### Auto-Reload Behavior

When auto-reload is enabled and the file has no unsaved changes:
1. File changes on disk (FileWatcher triggers)
2. Orb appears/crossfades to orange (File Changed state)
3. Orb breathes for approximately 5 seconds
4. App automatically reloads the file from disk
5. Orb dismisses (fileChanged state clears, orb transitions to next priority state or hides)

The dismiss uses an asymmetric transition: scale(0.5) combined with opacity fade-out.

### Solarized Theme Context

The orb renders against the document background:

#### Solarized Dark
- Document background: base03 (#002b36) -- dark blue-gray
- The violet orb (#6c71c4) and orange orb (#cb4b16) should both be clearly visible against this dark background

#### Solarized Light
- Document background: base3 (#fdf6e3) -- warm off-white
- The violet orb (#6c71c4) and orange orb (#cb4b16) should both be clearly visible against this light background

### Evaluation Criteria for Orb Captures

When evaluating captured frame sequences:

#### (a) Color Accuracy
Does the orb display the correct color for its state? Violet (#6c71c4) for default handler, orange (#cb4b16) for file changed. The colors should be recognizably Solarized palette colors, not washed out or incorrect hues.

#### (b) Crossfade Smoothness
Does the color transition from violet to orange appear as a smooth blend? There should be no flickering, no intermediate frames where the orb disappears, and no abrupt color jump. The transition should take approximately 0.35 seconds.

#### (c) Breathing Rhythm
Does the orb show a visible breathing pulse? The brightness/glow modulation should be smooth and continuous. The rhythm should feel calm and natural (~12 CPM), not rapid or jerky.

#### (d) Halo Phase Offset
Is the outer halo animation slightly out of phase with the inner core? This creates the organic, living quality. If both layers pulse in perfect sync, the animation may feel mechanical.

#### (e) Orb Position
Is the orb positioned in the bottom-right corner of the window? It should have consistent padding from the edges (16pt).

#### (f) Visibility
Is the orb clearly visible against both Solarized Dark and Solarized Light backgrounds? The orb should not blend into or be obscured by the background color.
