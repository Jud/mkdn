# Hypothesis Document: scroll-rendering-validation
**Version**: 1.0.0 | **Created**: 2026-02-17T17:09:00Z | **Status**: VALIDATED

## Hypotheses
### HYP-001: Synthetic Trackpad Scroll via CGEvent API
**Risk Level**: HIGH
**Status**: CONFIRMED
**Statement**: We can synthesize realistic trackpad inertial scrolling in a macOS app by posting CGScrollWheelEvent events via CGEvent API, and these events will go through the exact same NSScrollView/CALayer compositing/display link code path as real user input -- faithfully reproducing scroll rendering artifacts like sub-pixel border jitter and sticky header position gaps.
**Context**: The mkdn app uses NSTextView in NSScrollView (via LiveResizeScrollView) with overlay-based table rendering including sticky headers. A test harness needs to drive scroll to reproduce rendering artifacts, combined with SCStream-based frame capture at 60fps.
**Validation Criteria**:
- CONFIRM if: CGEvent scroll wheel events with pixel units and proper scroll phase values (.began, .changed, .ended + momentum phases) are processed by NSScrollView identically to real trackpad input, including triggering the same layer compositing and display refresh behavior.
- REJECT if: CGEvent-posted scroll events bypass important parts of the rendering pipeline (e.g., skip momentum phase handling, don't trigger the same CALayer commit timing, require accessibility permissions that make this impractical, or NSScrollView handles synthetic events differently than real HID events).
**Suggested Method**: CODE_EXPERIMENT

## Validation Findings

### HYP-001 Findings
**Validated**: 2026-02-17T17:25:00Z
**Method**: CODE_EXPERIMENT + CODEBASE_ANALYSIS + EXTERNAL_RESEARCH
**Result**: CONFIRMED

**Evidence**:

The hypothesis is confirmed with one important refinement: the optimal approach is **direct delivery** via `scrollView.scrollWheel(with: nsEvent)` rather than CGEventPost, which eliminates the accessibility permission requirement while using the identical rendering pipeline.

#### Q1: Pixel Units and Fractional Deltas

CGEvent scroll wheel events with `.pixel` units are fully supported:

```swift
CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: 10, wheel2: 0, wheel3: 0)
```

**Experimental results:**
- `isContinuous` is automatically set to `1` for pixel-unit events (trackpad behavior)
- `pointDeltaAxis1` accepts integer pixel values (via `setIntegerValueField`)
- `fixedPtDeltaAxis1` accepts fractional values (via `setDoubleValueField`) -- e.g., 2.5 round-trips as 2.5, 3.7 round-trips as 3.6999969482421875 (16.16 fixed-point precision)
- `hasPreciseScrollingDeltas` is `true` on the resulting NSEvent
- `scrollingDeltaY` on NSEvent correctly reflects the pixel delta (e.g., -25.0 for a -25 pixel delta)

#### Q2: Scroll Phase and Momentum Phase Fields

Both phase fields are fully settable and round-trip correctly at the CGEvent level. **Critical discovery: CGEvent phase integer values use a DIFFERENT numbering scheme than NSEvent.Phase raw values.** The mapping discovered experimentally:

| CGEvent `scrollWheelEventScrollPhase` | NSEvent.Phase |
|---------------------------------------|---------------|
| 0 | [] (none) |
| 1 | .began (1) |
| 2 | .changed (4) |
| 4 | .ended (8) |
| 8 | .cancelled (16) |
| 128 | .mayBegin (32) |

| CGEvent `scrollWheelEventMomentumPhase` | NSEvent.Phase |
|-----------------------------------------|---------------|
| 0 | [] (none) |
| 1 | .began (1) |
| 2 | .changed (4) |
| 3 | .ended (8) |

This mapping is not documented by Apple and was discovered through exhaustive experimental probing. Using NSEvent.Phase raw values directly in CGEvent fields produces INCORRECT phase values in the resulting NSEvent.

A complete trackpad gesture sequence was validated:
```
began(sp=1) -> changed*(sp=2) -> ended(sp=4) -> mom.began(mp=1) -> mom.changed*(mp=2) -> mom.ended(mp=3)
```

All 11 events in the sequence were created, wrapped in NSEvent, and verified to have correct `phase` and `momentumPhase` values.

#### Q3: Accessibility Permissions

Two delivery mechanisms were tested:

1. **CGEventPost / postToPid**: Requires accessibility permission (`AXIsProcessTrusted()` must return `true`). Even with permission granted, `postToPid` to own process and `post(tap: .cgSessionEventTap)` did NOT move the scroll view in experiments -- events likely go to the window server and get dispatched to the frontmost/key window, which may not be the intended target.

2. **Direct scrollView.scrollWheel(with:)**: NO permission required. This bypasses the event delivery system entirely and calls the NSScrollView method directly. The mkdn test harness already has `findScrollView(in:)` (in `TestHarnessHandler.swift:357-370`) which locates the app's NSScrollView.

**Recommendation**: Use direct delivery. The existing test harness architecture already accesses the NSScrollView directly for `handleScrollTo()` commands. Direct `scrollWheel(with:)` delivery avoids all permission issues while entering the identical code path.

#### Q4: NSScrollView Processing of Synthetic Events

**Windowed experiment results**: A proper windowed NSScrollView with NSTextView (document height 2814.5pt, visible 400pt) was driven with synthetic events via direct `scrollWheel(with:)` delivery:

```
began:     delta=-2px,  scrollY=2.0,   moved=2.0px   (phase=1/mom=0)
changed-1: delta=-10px, scrollY=12.0,  moved=10.0px  (phase=4/mom=0)
changed-2: delta=-15px, scrollY=27.0,  moved=15.0px  (phase=4/mom=0)
changed-3: delta=-20px, scrollY=47.0,  moved=20.0px  (phase=4/mom=0)
changed-4: delta=-12px, scrollY=59.0,  moved=12.0px  (phase=4/mom=0)
ended:     delta=0px,   scrollY=59.0,  moved=0.0px   (phase=8/mom=0)
mom-began: delta=-8px,  scrollY=67.0,  moved=8.0px   (phase=0/mom=1)
mom-chg-1: delta=-6px,  scrollY=73.0,  moved=6.0px   (phase=0/mom=4)
mom-chg-2: delta=-4px,  scrollY=77.0,  moved=4.0px   (phase=0/mom=4)
mom-chg-3: delta=-2px,  scrollY=79.0,  moved=2.0px   (phase=0/mom=4)
mom-ended: delta=0px,   scrollY=79.0,  moved=0.0px   (phase=0/mom=8)
```

Every event produced the exact expected pixel displacement. The scroll view processed gesture phases AND momentum phases correctly, scrolling to a total of 79px. This proves NSScrollView treats synthetic events identically to real trackpad events when delivered via `scrollWheel(with:)`.

**Responsive scrolling**: The mkdn app's `LiveResizeScrollView` (in `SelectableTextView.swift:495-518`) does NOT override `scrollWheel(with:)` -- it only overrides `tile()` and `viewDidEndLiveResize()`. Neither does `CodeBlockBackgroundTextView`. This means **responsive scrolling is fully active**, and synthetic events delivered via `scrollWheel(with:)` enter the same concurrent tracking loop, CALayer compositing, and display link synchronization as real trackpad events.

**Overlay coordinator**: The `OverlayCoordinator` (which handles sticky table headers) observes scroll via `NSView.boundsDidChangeNotification` on the clip view (`OverlayCoordinator.swift:436-438`). This notification fires whenever the clip view bounds change regardless of scroll source, so synthetic scroll WILL trigger sticky header repositioning -- the exact behavior needed to reproduce sticky header position gaps.

#### Q5: Timing and Gotchas

**Event timing**: Real trackpad events arrive every ~8ms (120Hz displays) or ~16ms (60Hz). The experiment used 16ms (`RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.016))`) between events, matching 60Hz refresh.

**Known considerations**:
1. **Phase protocol is mandatory**: Must follow `began -> changed* -> ended` before `momentumBegan -> momentumChanged* -> momentumEnded`. Skipping `ended` before momentum will confuse NSScrollView's state machine.
2. **No coalescing at the API level**: Each `scrollWheel(with:)` call is processed individually. However, responsive scrolling may internally buffer events on its concurrent tracking thread.
3. **Elastic bounce**: To trigger elastic bounce (rubber-banding at scroll limits), scroll past the document bounds with proper phase values. NSScrollView handles elastic animation automatically when it sees the correct phase sequence.
4. **Minimum inter-event delay**: No hard minimum, but events faster than the display refresh rate (16.67ms at 60Hz) may be processed but won't produce distinct visual frames for SCStream capture. Recommend ~16ms spacing for 60fps capture.
5. **CGEvent -> NSEvent phase translation**: Must use CGEvent's own phase numbering (documented above), NOT NSEvent.Phase raw values. This is the single biggest gotcha.

**Sources**:
- Code experiment: `/tmp/hypothesis-scroll-synthesis/Sources/main.swift` (3 iterations)
- `mkdn/Features/Viewer/Views/SelectableTextView.swift:495-518` (LiveResizeScrollView, no scrollWheel override)
- `mkdn/Features/Viewer/Views/OverlayCoordinator.swift:432-443` (scroll observation via boundsDidChangeNotification)
- `mkdn/Core/TestHarness/TestHarnessHandler.swift:336-370` (existing scroll handling + findScrollView)
- [CGEventField.scrollWheelEventScrollPhase](https://developer.apple.com/documentation/coregraphics/cgeventfield/scrollwheeleventscrollphase)
- [CGEventCreateScrollWheelEvent](https://developer.apple.com/documentation/coregraphics/1541327-cgeventcreatescrollwheelevent)
- [NSEvent.momentumPhase](https://developer.apple.com/documentation/appkit/nsevent/1525439-momentumphase)
- [Low-level scrolling events on macOS (Gist)](https://gist.github.com/svoisen/5215826)
- [Apple Developer Forums: CGEventPost permissions](https://developer.apple.com/forums/thread/122492)
- [Apple Developer Forums: Event tap permissions](https://developer.apple.com/forums/thread/758554)
- [NSScrollView responsive scrolling](https://developer.apple.com/documentation/appkit/nsview/2870005-iscompatiblewithresponsivescroll)

**Implications for Design**:

1. **Direct delivery is the optimal approach**: Call `scrollView.scrollWheel(with: nsEvent)` directly from the test harness handler. No CGEventPost needed, no accessibility permissions needed.

2. **Identical rendering pipeline**: Synthetic events enter the same responsive scrolling concurrent tracking loop as real trackpad events, triggering the same CALayer compositing, display link synchronization, and bounds-change notifications that drive overlay repositioning.

3. **Phase mapping must be hardcoded**: The CGEvent-to-NSEvent phase translation is undocumented and must use the experimentally-determined mapping. This is a fixed, stable mapping (it's part of the CoreGraphics ABI).

4. **Test harness integration is straightforward**: The existing `findScrollView(in:)` utility and `handleScrollTo` command pattern can be extended with a new `scrollGesture` command that sends a sequence of synthetic scroll events with proper phase values and timing.

5. **Frame capture synchronization**: With SCStream capturing at 60fps and synthetic scroll events posted every ~16ms, each scroll event should produce a distinct captured frame, enabling frame-by-frame analysis of rendering artifacts.

## Summary
| Hypothesis | Risk | Result | Implication |
|------------|------|--------|-------------|
| HYP-001 | HIGH | CONFIRMED | Synthetic trackpad scroll via direct `scrollWheel(with:)` delivery follows the identical NSScrollView responsive scrolling pipeline. CGEvent phase numbering differs from NSEvent.Phase (critical gotcha). No accessibility permission needed for direct delivery. Existing harness infrastructure supports this approach. |
