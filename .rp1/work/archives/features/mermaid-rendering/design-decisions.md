# Design Decisions: Mermaid Diagram Rendering

**Feature ID**: mermaid-rendering
**Created**: 2026-02-06

## Decision Log

| ID | Decision | Choice | Rationale | Alternatives Considered |
|----|----------|--------|-----------|------------------------|
| D1 | Cache eviction strategy | LRU (Least Recently Used) | Most predictable for diagram viewing: recently viewed diagrams stay cached; old ones evict naturally as user navigates | Count-limited FIFO (simpler but evicts frequently-used entries), time-based TTL (unnecessary for in-memory cache) |
| D2 | Cache capacity | 50 entries | Covers 5-10x typical document diagram count; SVG strings average 5-20KB each so ~1MB max cache | 20 (too small for multi-doc workflows), 100 (unnecessarily large), unlimited (original, rejected per FR-MER-005) |
| D3 | Cache key hashing | DJB2 stable hash (UInt64) | Deterministic across process launches; already used in MarkdownBlock.id for the same purpose | Swift hashValue (non-deterministic per-launch), SHA256 (overkill for in-memory cache keys) |
| D4 | JXContext lifecycle | Lazy singleton with error-triggered recreation | Avoids ~50-100ms cost of loading JS bundle per render; recreation on error prevents corruption accumulation | Fresh per call (current, too slow), permanent singleton (risk of accumulated memory) |
| D5 | Scroll isolation approach | Conditional ScrollView rendering | When not activated, no ScrollView exists in hierarchy so scroll events cannot be captured; simplest and most reliable approach | allowsHitTesting toggle (still captures in some cases), AppKit NSScrollView subclass (breaks SwiftUI-only constraint), gesture precedence manipulation (fragile) |
| D6 | Diagram activation mechanism | Click-to-activate, Escape/click-outside to deactivate | Most conservative approach per PRD; prevents accidental scroll capture; familiar macOS pattern | Hover-to-activate (too easy to trigger accidentally), modifier-key (non-discoverable) |
| D7 | Zoom gesture pattern | Base + delta cumulative | Fixes current bug where zoom resets; standard pattern for MagnifyGesture in SwiftUI | Direct magnification (current, buggy), state-only tracking (same issue) |
| D8 | Bundle resource access | Bundle.module (SPM) | Correct API for accessing resources in SPM library targets; Bundle.main only works for executable target | Bundle.main (current, incorrect for lib target context) |
| D9 | New file vs inline for MermaidCache | Separate file `MermaidCache.swift` | Follows project pattern of single-purpose files; testable independently | Inline in MermaidRenderer.swift (harder to test, violates SRP) |
| D10 | Diagram container max height | 400pt with clipping | Prevents oversized diagrams from dominating the document; user can zoom/pan for detail | No max height (diagrams can push content off-screen), 200pt (too small for readability) |

## AFK Mode: Auto-Selected Technology Decisions

| Decision | Choice | Source | Rationale |
|----------|--------|--------|-----------|
| Cache eviction strategy | LRU | PRD open question + conservative default | LRU is the standard eviction policy for content caches; most predictable behavior for diagram viewing where recently viewed items are most likely to be re-viewed |
| Cache capacity | 50 entries | Codebase analysis + conservative default | Documents typically have 1-10 diagrams; 50 provides generous headroom without excessive memory (estimated ~1MB max for SVG strings) |
| JXContext reuse | Lazy singleton, recreate on error | KB architecture.md (actor pattern) + performance analysis | Fresh-per-call is confirmed slow due to JS bundle loading; singleton with error recovery balances performance and safety |
| Scroll isolation mechanism | Conditional ScrollView rendering | KB patterns.md (SwiftUI patterns) + requirements FR-MER-008 | SwiftUI scroll capture occurs through ScrollView in hierarchy; removing it when not needed is the cleanest architectural approach |
| Activation UX | Click-to-focus | Requirements CL-002 (conservative default) | Requirements document explicitly selected click-to-focus as the conservative default |
| Diagram type validation | Parse first line for known keywords | Codebase analysis + BR-001 | Provides clear error messages for unsupported types (gantt, pie, etc.) rather than opaque JS errors |
| Hash algorithm | DJB2 (UInt64) | Codebase (MarkdownBlock.swift uses identical DJB2) | Maintains consistency with existing pattern; already proven stable in the codebase |
| Container max height | 400pt | Conservative default | Balances diagram readability with document flow; user can zoom for detail |
| Bundle access | Bundle.module | SPM documentation + codebase analysis | Current Bundle.main usage is incorrect for library targets in SPM; Bundle.module is the correct API |
| Test framework | Swift Testing (@Suite, @Test, #expect) | KB patterns.md + existing test files | Matches all existing test files in the codebase |
