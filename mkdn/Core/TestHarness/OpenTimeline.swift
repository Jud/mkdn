import Foundation
import OSLog

/// Phase timings recorded for the most recent document open.
///
/// The open path records each phase (parse → render → build → install →
/// first paint) as it runs; the test harness reads the record back via
/// `getOpenTimings` to check open-time performance against the
/// viewport-first plan's budgets (docs/features/height-estimation/
/// viewport-first-perf-plan.md).
public struct OpenTimingsResult: Codable, Sendable, Equatable {
    public struct Phase: Codable, Sendable, Equatable {
        public let name: String
        /// Offset from the start of the open, in milliseconds.
        public let startMs: Double
        public let durationMs: Double

        public init(name: String, startMs: Double, durationMs: Double) {
            self.name = name
            self.startMs = startMs
            self.durationMs = durationMs
        }
    }

    public let phases: [Phase]
    /// Whole-document `DocumentBlockOffsets` passes since the open began.
    /// The plan's budget is exactly one per content/width generation.
    public let blockOffsetsMeasureCount: Int

    public init(phases: [Phase], blockOffsetsMeasureCount: Int) {
        self.phases = phases
        self.blockOffsetsMeasureCount = blockOffsetsMeasureCount
    }
}

/// Recorder for ``OpenTimingsResult``. Each phase also emits an os_signpost
/// interval (subsystem `com.mkdn`, category `DocumentOpen`) so the same runs
/// can be profiled in Instruments.
@MainActor
public final class OpenTimeline {
    public static let shared = OpenTimeline()

    private static let signposter = OSSignposter(
        subsystem: "com.mkdn", category: "DocumentOpen"
    )
    /// Phases keep appending after the open settles (attachment re-measures,
    /// resize) for attribution; the cap keeps a long session from growing the
    /// record unbounded.
    private static let maxPhases = 64

    private var phases: [OpenTimingsResult.Phase] = []
    private var blockOffsetsMeasureCount = 0
    private var openStart: ContinuousClock.Instant?

    private init() {}

    /// Start a fresh record. Called when a content change begins rendering;
    /// phases recorded before the first `begin()` are dropped.
    public func begin() {
        openStart = .now
        phases = []
        blockOffsetsMeasureCount = 0
    }

    /// Run `body` as one named phase: a signpost interval plus a record entry.
    public func time<T>(_ name: StaticString, _ body: () throws -> T) rethrows -> T {
        let state = Self.signposter.beginInterval(name)
        let start = ContinuousClock.now
        defer {
            Self.signposter.endInterval(name, state)
            record(name: "\(name)", start: start, end: .now)
        }
        return try body()
    }

    /// Record an instantaneous marker (e.g. first paint).
    public func mark(_ name: StaticString) {
        Self.signposter.emitEvent(name)
        let now = ContinuousClock.now
        record(name: "\(name)", start: now, end: now)
    }

    /// Count one whole-document `DocumentBlockOffsets` pass.
    public func noteBlockOffsetsMeasure() {
        blockOffsetsMeasureCount += 1
    }

    public func result() -> OpenTimingsResult {
        OpenTimingsResult(
            phases: phases, blockOffsetsMeasureCount: blockOffsetsMeasureCount
        )
    }

    private func record(
        name: String, start: ContinuousClock.Instant, end: ContinuousClock.Instant
    ) {
        guard let openStart, phases.count < Self.maxPhases else { return }
        phases.append(OpenTimingsResult.Phase(
            name: name,
            startMs: (start - openStart) / .milliseconds(1),
            durationMs: (end - start) / .milliseconds(1)
        ))
    }
}
