# Pulse

A real-time event processing framework for Swift.

## Overview

Pulse provides a declarative pipeline API for filtering, transforming, and routing events with backpressure support. Built for Swift concurrency from day one.

```swift
let pipeline = Pipeline<RawEvent, ProcessedEvent> {
    Deduplicate(by: \.eventID, window: .seconds(30))
    Transform { event in
        ProcessedEvent(
            id: event.eventID,
            severity: event.classify(),
            timestamp: event.occurredAt,
            payload: try await event.enriched()
        )
    }
    Filter { $0.severity >= .warning }
    Route { event in
        switch event.severity {
        case .critical: PagerDutyHandler()
        case .warning:  SlackChannel("#ops-alerts")
        default:        MetricsCollector()
        }
    }
}

await pipeline.process(eventStream)
```

## Architecture

```mermaid
sequenceDiagram
    participant Source as Event Source
    participant Ingest as Ingestion Layer
    participant Pipeline as Pipeline Engine
    participant Transform as Transform Stage
    participant Route as Router
    participant Sink as Output Sinks

    Source->>Ingest: Raw events (WebSocket)
    Ingest->>Pipeline: Validated batch
    Pipeline->>Transform: Apply operators
    Transform->>Transform: Deduplicate
    Transform->>Transform: Enrich metadata
    Transform->>Route: Classified events
    Route->>Sink: Critical → PagerDuty
    Route->>Sink: Warning → Slack
    Route->>Sink: Info → Metrics
    Sink-->>Pipeline: Backpressure signal
    Pipeline-->>Ingest: Flow control
```

## Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `batchSize` | 100 | Events per processing batch |
| `flushInterval` | 5s | Maximum time before batch flush |
| `maxRetries` | 3 | Retry count for failed deliveries |
| `backpressureStrategy` | `.drop(.oldest)` | Behavior when sinks are slow |
| `deduplicationWindow` | 30s | Time window for duplicate detection |
| `concurrencyLimit` | 8 | Maximum parallel sink operations |

## Pipeline Stages

> **Design principle:** Each stage is a pure function over an async sequence. Stages compose through operator chaining — no inheritance, no delegates, no callbacks.

### Operators

- **Deduplicate** — Suppress duplicate events within a sliding window
- **Transform** — Map events to a new shape with async enrichment
- **Filter** — Drop events that don't match a predicate
- **Route** — Fan out events to different sinks based on content
- **Buffer** — Absorb bursts with configurable overflow strategies
- **Throttle** — Rate-limit output to protect downstream services

## Metrics

```mermaid
graph LR
    A[Ingested] -->|validate| B[Accepted]
    A -->|reject| C[Dropped]
    B -->|process| D[Transformed]
    D -->|route| E[Delivered]
    D -->|overflow| F[Backpressured]
    E -->|ack| G[Committed]
    E -->|nack| H[Retried]
    H -->|exhaust| C
```

## Getting Started

```swift
import Pulse

@main
struct EventProcessor {
    static func main() async throws {
        let config = PipelineConfig(
            batchSize: 200,
            flushInterval: .seconds(2),
            backpressure: .drop(.oldest)
        )

        let pipeline = Pipeline<IncomingEvent, Alert>(config: config) {
            Deduplicate(by: \.id)
            Transform(enrich)
            Filter { $0.priority >= .high }
            Route(byPriority)
        }

        try await pipeline.connect(to: WebSocketSource(url: endpoint))
    }
}
```
