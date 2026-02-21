# Architecture Decision Records

## ADR-001: Actor-Based Pipeline Execution

**Status:** Accepted

**Context:** Pipelines need to handle concurrent event streams without data races. Swift 6 strict concurrency checking requires explicit isolation.

**Decision:** Each pipeline stage runs as an isolated actor. Inter-stage communication uses `AsyncStream`.

```swift
actor PipelineStage<Input: Sendable, Output: Sendable> {
    private let transform: @Sendable (Input) async throws -> Output

    func process(_ input: Input) async throws -> Output {
        try await transform(input)
    }
}
```

**Consequences:**
- Thread-safe by construction
- Slight overhead from actor hops
- Natural backpressure via stream buffering

---

## ADR-002: Result Builder DSL

**Status:** Accepted

**Context:** Pipeline construction should feel native to Swift.

**Decision:** Use `@resultBuilder` for declarative pipeline definitions.

> This gives us compile-time type checking across the entire pipeline chain. A `Transform<A, B>` followed by a `Filter<C>` won't compile unless `B == C`.
