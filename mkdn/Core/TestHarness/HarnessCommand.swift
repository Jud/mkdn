import Foundation

// MARK: - Socket Path Convention

/// Deterministic socket path for the test harness IPC channel.
public enum HarnessSocket {
    /// Returns the Unix domain socket path for a given process ID.
    ///
    /// The path follows the convention `/tmp/mkdn-test-harness-{pid}.sock`
    /// so the test runner can predict the socket location from the launched
    /// process's PID.
    public static func path(forPID pid: Int32) -> String {
        "/tmp/mkdn-test-harness-\(pid).sock"
    }

    /// Socket path for the current process.
    public static var currentPath: String {
        path(forPID: ProcessInfo.processInfo.processIdentifier)
    }
}

// MARK: - Commands

/// Commands sent from the test runner to the app under test.
///
/// Each case maps to a user-facing interaction or capture action.
/// The app dispatches to `@MainActor` and responds with a `HarnessResponse`.
public enum HarnessCommand: Codable, Sendable {
    /// Load a Markdown file at the given path.
    case loadFile(path: String)

    /// Switch the view mode.
    /// Values: `"previewOnly"`, `"sideBySide"`.
    case switchMode(mode: String)

    /// Cycle to the next theme mode (Auto -> Dark -> Light -> Auto).
    case cycleTheme

    /// Set a specific theme.
    /// Values: `"solarizedDark"`, `"solarizedLight"`.
    case setTheme(theme: String)

    /// Reload the current file from disk.
    case reloadFile

    /// Capture the full window as a PNG image.
    /// If `outputPath` is nil, a default path is generated.
    case captureWindow(outputPath: String?)

    /// Capture a region of the window as a PNG image.
    case captureRegion(region: CaptureRegion, outputPath: String?)

    /// Start a frame sequence capture at the given FPS and duration.
    case startFrameCapture(fps: Int, duration: Double, outputDir: String?)

    /// Stop an in-progress frame capture.
    case stopFrameCapture

    /// Begin a frame capture that returns immediately while SCStream runs.
    /// Call ``endFrameCapture`` to stop and get results.
    case beginFrameCapture(fps: Int, outputDir: String?)

    /// End a frame capture started with ``beginFrameCapture`` and return results.
    case endFrameCapture

    /// Get current window information (dimensions, position, scale factor).
    case getWindowInfo

    /// Get the current theme's color values as RGB tuples.
    case getThemeColors

    /// Override the Reduce Motion preference for testing.
    case setReduceMotion(enabled: Bool)

    /// Scroll the content view to a specific vertical offset (in points).
    case scrollTo(yOffset: Double)

    /// Set the sidebar width in points (directory mode only).
    case setSidebarWidth(width: Double)

    /// Toggle sidebar visibility (directory mode only).
    case toggleSidebar

    /// Simulate smooth scroll by animating contentView.scroll(to:) at 60Hz.
    case simulateScroll(deltaY: Double, duration: Double)

    /// Start lightweight frame capture using CGWindowListCreateImage at the
    /// given FPS. Frames are written to outputDir. Call ``stopQuickCapture``
    /// to stop and get results. Does not require screen recording permission.
    case startQuickCapture(fps: Int, outputDir: String)

    /// Stop a quick capture started with ``startQuickCapture`` and return
    /// the captured frame paths.
    case stopQuickCapture

    /// Connectivity check. The server responds with `pong`.
    case ping

    /// Terminate the application.
    case quit
}

// MARK: - Capture Region

/// A rectangular region for targeted window capture.
public struct CaptureRegion: Codable, Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}
