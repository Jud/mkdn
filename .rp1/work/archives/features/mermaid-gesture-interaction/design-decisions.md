# Design Decisions: Mermaid Gesture Interaction

**Feature ID**: mermaid-gesture-interaction
**Created**: 2026-02-06

## Decision Log

| ID | Decision | Choice | Rationale | Alternatives Considered |
|----|----------|--------|-----------|------------------------|
| D1 | Event interception mechanism | NSViewRepresentable overlay per diagram | Encapsulated per-diagram; matches existing WindowAccessor pattern; no global state; each diagram manages its own events independently | Global NSEvent.addLocalMonitorForEvents (centralized but requires hit-testing, less encapsulated); SwiftUI onScrollGesture (does not exist; no phase info) |
| D2 | Classifier architecture | Pure struct with mutating methods | Zero allocations, synchronous, testable without mocking; meets single-frame latency budget trivially; value semantics prevent shared-state bugs | @Observable class (unnecessary overhead, observation not needed for event-loop-speed classification); Actor (async overhead inappropriate for per-event classification) |
| D3 | Panning mechanism | NSEvent.scrollingDeltaX/Y applied to manual offset | System-pre-scaled deltas respect user scroll speed preferences and natural scroll direction; no physics simulation needed; simpler than managing a nested ScrollView | SwiftUI DragGesture (does not respond to two-finger scroll, only click-drag); Nested ScrollView (the current activated mode; causes scroll isolation problems) |
| D4 | Classifier test boundary | Classifier accepts extracted fields (phase enum, momentumPhase enum, bool) not raw NSEvent | NSEvent cannot be constructed in tests without private API; extracting fields at the Coordinator layer keeps classifier pure and fully testable | Accept NSEvent directly (untestable without mocking framework); Protocol-wrap NSEvent (over-engineering for a few fields) |
| D5 | View architecture | Single code path, no activation state | Matches the requirement of invisible interaction; eliminates the dual-mode branching that caused the scroll trap bug; simpler view hierarchy | Keep dual-mode with automatic switching (still has a discrete state transition, harder to get seamless); Three modes (adds complexity without value) |
| D6 | Edge overflow forwarding | Forward raw NSEvent via nextResponder chain | Responder chain is the standard macOS mechanism for event forwarding; preserves all event metadata (velocity, phase) for smooth parent scroll pickup | Synthesize new NSEvent with overflow deltas (fragile, loses momentum metadata); Post notification (breaks responder chain semantics) |
| D7 | New file organization | Core/Gesture/ directory for classifier and pan state | Follows Feature-Based MVVM pattern where Core/ holds reusable logic; gesture classification is not Mermaid-specific and could be reused for other embedded interactive content | Place in Core/Mermaid/ (too specific; classifier logic is generic); Place in Features/Viewer/ (classifier is not a view concern) |
| D8 | Zoom handling | Keep existing MagnifyGesture unchanged | Zoom already works without activation; pinch intent is unambiguous (BR-04); no reason to move zoom to NSView layer | Handle magnify in NSView too (unnecessary complexity; SwiftUI handles it well); Remove and re-implement (no benefit) |
