import Foundation

/// Lightweight notification mechanism that lets the test harness await
/// render completion from the SwiftUI view layer.
///
/// The `SelectableTextView.Coordinator` calls `signalRenderComplete()`
/// after applying text content and overlays. The `TestHarnessServer`
/// calls `awaitRenderComplete(timeout:)` after dispatching commands
/// that trigger re-rendering (loadFile, switchMode, cycleTheme, etc.).
///
/// Usage from the view coordinator:
/// ```swift
/// RenderCompletionSignal.shared.signalRenderComplete()
/// ```
///
/// Usage from the harness server:
/// ```swift
/// try await RenderCompletionSignal.shared.awaitRenderComplete()
/// ```
@MainActor
public final class RenderCompletionSignal {
    public static let shared = RenderCompletionSignal()

    private var continuation: CheckedContinuation<Void, any Error>?

    private init() {}

    /// Suspend until the next render completion signal arrives, or throw
    /// `HarnessError.renderTimeout` if the timeout expires first.
    ///
    /// The caller resumes when either `signalRenderComplete()` is called
    /// (success) or the timeout duration elapses (throws `renderTimeout`).
    public func awaitRenderComplete(timeout: Duration = .seconds(10)) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            self.continuation = cont

            // Schedule a timeout that fires if no render signal arrives.
            // Both the timeout and the signal share the same continuation,
            // guarded by main-actor isolation to prevent double-resume.
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: timeout)
                guard let self else { return }
                guard let pending = continuation else { return }
                continuation = nil
                pending.resume(throwing: HarnessError.renderTimeout)
            }
        }
    }

    /// Signal that the current render pass is complete.
    ///
    /// Called by `SelectableTextView.Coordinator.updateNSView` after
    /// applying text content and overlay positions. Safe to call when
    /// no one is awaiting -- the signal is silently dropped.
    public func signalRenderComplete() {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume()
    }
}
