import Foundation

/// Lightweight notification mechanism that lets the test harness await
/// render completion from the SwiftUI view layer.
///
/// The `SelectableTextView.Coordinator` calls `signalRenderComplete()`
/// after applying text content and overlays. The `TestHarnessHandler`
/// calls `prepareForRender()` before state mutation, then
/// `awaitPreparedRender(timeout:)` after, to reliably capture the signal.
///
/// Two-phase usage (preferred -- eliminates signal race):
/// ```swift
/// let signal = RenderCompletionSignal.shared
/// signal.prepareForRender()          // install latch before state change
/// try docState.loadFile(at: url)     // trigger render
/// try await signal.awaitPreparedRender()  // wait for signal (or latch)
/// ```
///
/// Signal from the view coordinator:
/// ```swift
/// RenderCompletionSignal.shared.signalRenderComplete()
/// ```
@MainActor
public final class RenderCompletionSignal {
    public static let shared = RenderCompletionSignal()

    private var continuation: CheckedContinuation<Void, any Error>?
    private var latchActive = false
    private var latchCompleted = false

    private init() {}

    // MARK: - Two-Phase API

    /// Phase 1: Synchronously prepare to receive a render completion signal.
    ///
    /// Must be called **before** the state mutation that triggers rendering.
    /// Installs a latch so that any `signalRenderComplete()` call is captured
    /// even if it fires before `awaitPreparedRender()` installs its continuation.
    /// Clears any stale continuation from a prior render wait.
    public func prepareForRender() {
        if let stale = continuation {
            continuation = nil
            stale.resume(throwing: CancellationError())
        }
        latchActive = true
        latchCompleted = false
    }

    /// Phase 2: Await the render signal that was prepared for.
    ///
    /// Returns immediately if `signalRenderComplete()` already fired after
    /// `prepareForRender()` was called (the latch captures the signal).
    /// Otherwise yields to the MainActor run loop in short intervals,
    /// giving SwiftUI the opportunity to process view updates and fire the
    /// signal. Falls back to a continuation-based wait after the initial
    /// polling window.
    public func awaitPreparedRender(
        timeout: Duration = .seconds(10)
    ) async throws {
        // Fast path: signal already captured by latch
        if latchCompleted {
            latchActive = false
            latchCompleted = false
            return
        }

        // Polling phase: yield to the run loop in short intervals so
        // SwiftUI can process state changes and trigger makeNSView /
        // updateNSView. This covers the window between prepareForRender()
        // and continuation installation where signals would otherwise be
        // captured by the latch.
        let pollInterval: Duration = .milliseconds(16)
        let pollIterations = 32 // ~512ms polling window
        for _ in 0 ..< pollIterations {
            try await Task.sleep(for: pollInterval)
            if latchCompleted {
                latchActive = false
                latchCompleted = false
                return
            }
        }

        // Continuation phase: the signal hasn't arrived yet; install a
        // continuation for the remaining timeout duration.
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            // Check once more before installing (signal may have just arrived)
            if latchCompleted {
                latchActive = false
                latchCompleted = false
                cont.resume()
                return
            }
            self.continuation = cont

            Task { @MainActor [weak self] in
                try? await Task.sleep(for: timeout)
                guard let self else { return }
                guard let pending = continuation else { return }
                continuation = nil
                latchActive = false
                latchCompleted = false
                pending.resume(throwing: HarnessError.renderTimeout)
            }
        }

        latchActive = false
        latchCompleted = false
    }

    /// Cancel a previously prepared render wait without awaiting.
    ///
    /// Call when the state mutation did not actually change any `@Observable`
    /// properties (e.g. loading the same file again), so no SwiftUI render
    /// cycle will fire `signalRenderComplete()`.
    public func cancelPrepare() {
        if let stale = continuation {
            continuation = nil
            stale.resume(throwing: CancellationError())
        }
        latchActive = false
        latchCompleted = false
    }

    // MARK: - Legacy API

    /// Suspend until the next render completion signal arrives, or throw
    /// `HarnessError.renderTimeout` if the timeout expires first.
    ///
    /// - Note: Prefer the two-phase API (`prepareForRender()` +
    ///   `awaitPreparedRender()`) to eliminate the race window where the
    ///   signal fires before the continuation is installed.
    @available(*, deprecated, message: "Use prepareForRender() + awaitPreparedRender(timeout:) instead")
    public func awaitRenderComplete(timeout: Duration = .seconds(10)) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            self.continuation = cont

            Task { @MainActor [weak self] in
                try? await Task.sleep(for: timeout)
                guard let self else { return }
                guard let pending = continuation else { return }
                continuation = nil
                pending.resume(throwing: HarnessError.renderTimeout)
            }
        }
    }

    // MARK: - Signal

    /// Signal that the current render pass is complete.
    ///
    /// Called by `SelectableTextView.Coordinator.updateNSView` after
    /// applying text content and overlay positions.
    ///
    /// If a continuation is waiting, resumes it immediately.
    /// If a latch is active but no continuation is installed yet,
    /// marks the latch as completed so `awaitPreparedRender()` returns
    /// immediately when called. If neither, the signal is silently dropped.
    public func signalRenderComplete() {
        if let cont = continuation {
            continuation = nil
            latchActive = false
            latchCompleted = false
            cont.resume()
            return
        }
        if latchActive {
            latchCompleted = true
        }
    }
}
