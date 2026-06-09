# Marker Track Test

This document exercises the scroll-marker track: many headings at varied
levels, several comments, and enough height to scroll. The gutter to the right
of the preview should show heading ticks (longer and bolder for higher levels),
accent comment ticks, and a thumb that tracks the viewport.

## Introduction

The quick brown fox jumps over the lazy dog. This opening paragraph gives the
first section some body so the headings below are spaced apart on the track.

Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump.
The five boxing wizards jump quickly through the misty morning air downtown.

### Background

Sphinx of black quartz, judge my vow. A wizard's job is to vex chumps quickly
in fog. Waltz, bad nymph, for quick jigs vex across the open meadow at dawn.

The early morning light filtered through the tall windows of the study, casting
long shadows across the worn wooden floor and the stacks of unread manuscripts.

### Motivation

We hold these truths about layout to be self-evident: that all blocks have a
top, that the top is measurable without full layout, and that estimation beats
realization for off-screen content. This sentence is a unique comment anchor.

## Architecture

Glib jocks quiz nymph to vex dwarf. The job requires a vexingly quick mind and
a fox-like patience for the chumps who quibble over pixel-level alignment.

### Coordinate Spaces

Bright vixens jump; dozy fowl quack. The marks live in scroll space, the same
basis the heading navigation already uses, so a clicked tick lands true.

A document at rest has its viewport at the origin. As the reader scrolls, the
thumb on the track descends in proportion, a faithful miniature of the whole.

### The Block Model

Jackdaws love my big sphinx of quartz. Each top-level block contributes one span
to the height model, and each span resolves to exactly one tick on the gutter.

#### Spans and Offsets

Crazy Fredrick bought many very exquisite opal jewels. The offsets convert to y
positions, the y positions normalize against the real document height, and only
then do they reach the view, which knows nothing of TextKit.

## Rendering

The job of waxing linoleum frequently peeves chintzy kids. The track renders
heading ticks flush right and comment ticks flush left in the accent color.

### Themes

Both Solarized themes must read cleanly. The foreground-derived heading ticks
and the accent comment ticks should each have enough contrast on either ground.

### Interaction

Amazingly few discotheques provide jukeboxes. A tap on the track jumps the
preview to the nearest mark, animated, so navigation feels deliberate.

## Conclusion

We few, we happy few, we band of blocks. This closing section sits near the
bottom so the thumb has somewhere to travel and a low tick to anchor against.

The final paragraph of the marker track test confirms that the deepest scroll
position still resolves a sensible nearest mark for the click-to-jump gesture.

<!--mkdn-comments
{
  "comments" : [
    {
      "body" : "Define the scope here.",
      "id" : "c1",
      "prefix" : "",
      "quote" : "This sentence is a unique comment anchor.",
      "suffix" : ""
    },
    {
      "body" : "Spell out the basis.",
      "id" : "c2",
      "prefix" : "",
      "quote" : "the same\nbasis the heading navigation already uses",
      "suffix" : ""
    },
    {
      "body" : "One span, one tick — good invariant.",
      "id" : "c3",
      "prefix" : "",
      "quote" : "each span resolves to exactly one tick on the gutter",
      "suffix" : ""
    },
    {
      "body" : "Confirm animation feels right.",
      "id" : "c4",
      "prefix" : "",
      "quote" : "jumps the\npreview to the nearest mark, animated",
      "suffix" : ""
    }
  ],
  "v" : 1
}
-->
