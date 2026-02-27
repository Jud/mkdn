import AppKit

/// Unified file-open routing service that bridges system file-open events into
/// SwiftUI window management.
///
/// Consolidates the responsibilities previously split between ``FileOpenCoordinator``
/// and ``AppDelegate``'s routing logic into a single `@Observable` singleton.
///
/// Three routing paths based on app state:
/// - **Warm + visible windows**: appends to ``pendingURLs`` for ``DocumentWindow`` observers.
/// - **Warm + no visible windows**: calls ``openFileWindow`` to create windows directly.
/// - **Cold launch**: calls ``reexecHandler`` (or the default `execv` path) to restart clean.
@MainActor
@Observable
public final class FileOpenService {
    /// Shared singleton used by both the AppDelegate (producer) and DocumentWindow (consumer).
    public static let shared = FileOpenService()

    /// URLs waiting to be opened in new windows.
    public var pendingURLs: [URL] = []

    /// Stored window opener for warm-launch-no-windows scenario.
    /// Set by ``DocumentWindow`` on appear; used when no visible windows exist
    /// to observe ``pendingURLs``.
    public var openFileWindow: ((URL) -> Void)?

    /// Injectable re-exec handler for cold-launch path. When `nil`, the default
    /// `setenv` + `execv` strategy is used. Set this in tests to verify cold-launch
    /// routing without actually re-executing the process.
    public var reexecHandler: (([URL]) -> Void)?

    /// Returns all pending URLs and clears the queue.
    public func consumePendingURLs() -> [URL] {
        let urls = pendingURLs
        pendingURLs.removeAll()
        return urls
    }

    /// Routes file-open events based on current app state.
    ///
    /// - Parameters:
    ///   - urls: Raw URLs from the system event (unrecognized file types are filtered out).
    ///   - didFinishLaunching: Whether `applicationDidFinishLaunching` has fired.
    ///   - hasVisibleWindows: Whether the app has at least one visible non-panel window.
    public func handleOpenDocuments(
        urls: [URL],
        didFinishLaunching: Bool,
        hasVisibleWindows: Bool
    ) {
        let textFileURLs = urls.filter(\.isTextFile)
        guard !textFileURLs.isEmpty else { return }

        for url in textFileURLs {
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        }

        if hasVisibleWindows {
            for url in textFileURLs {
                pendingURLs.append(url)
            }
        } else if didFinishLaunching {
            for url in textFileURLs {
                openFileWindow?(url)
            }
        } else {
            if let reexecHandler {
                reexecHandler(textFileURLs)
            } else {
                performDefaultReexec(textFileURLs)
            }
        }
    }

    // MARK: - Private

    private func performDefaultReexec(_ textFileURLs: [URL]) {
        let pathString = textFileURLs.map(\.path).joined(separator: "\n")
        setenv("MKDN_LAUNCH_FILE", pathString, 1)

        let execPath = Bundle.main.executablePath ?? ProcessInfo.processInfo.arguments[0]
        let cArgs: [UnsafeMutablePointer<CChar>?] = [strdup(execPath), nil]
        cArgs.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            _ = execv(execPath, baseAddress)
        }

        // execv only returns on failure -- fall back to pendingURLs
        for url in textFileURLs {
            pendingURLs.append(url)
        }
    }
}
