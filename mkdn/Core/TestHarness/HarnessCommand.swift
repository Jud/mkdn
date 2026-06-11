#if os(macOS)
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

        /// Toggle the right-docked comment sidebar's visibility.
        case toggleCommentSidebar

        /// Toggle the document minimap (swaps in for the marker track).
        case toggleMinimap

        /// Scroll to + flash the first resolved comment (exercises the sidebar's
        /// jump-to-comment path without simulating a card tap).
        case jumpFirstComment

        /// Scroll to + flash the resolved comment at `index` in document order.
        case jumpCommentAt(index: Int)

        /// Diagnose whether the comment at `index` is clickable in the main
        /// document: scroll it into view, then run the real hit-test path at the
        /// center of its span and report each step.
        case diagnoseCommentClick(index: Int)

        /// Simulate smooth scroll by animating contentView.scroll(to:) at 60Hz.
        case simulateScroll(deltaY: Double, duration: Double)

        /// Scroll the sidebar file tree to a specific vertical offset (in points).
        case scrollSidebar(yOffset: Double)

        /// Resize the main window to the given width and height (in points),
        /// preserving the current window origin.
        case resizeWindow(width: Double, height: Double)

        /// Start lightweight frame capture using CGWindowListCreateImage at the
        /// given FPS. Frames are written to outputDir. Call ``stopQuickCapture``
        /// to stop and get results. Does not require screen recording permission.
        case startQuickCapture(fps: Int, outputDir: String)

        /// Stop a quick capture started with ``startQuickCapture`` and return
        /// the captured frame paths.
        case stopQuickCapture

        /// Recreate the markdown preview's NSView from scratch (a fresh
        /// `makeNSView` / cold first paint) by changing its SwiftUI identity.
        /// Reproduces cold first-paint rendering bugs in-session without
        /// relaunching. Only has an effect when a markdown preview is visible.
        case recreateView

        /// Add a comment over the first occurrence of `substring` in the current
        /// markdown content (test harness only — exercises the comment-save
        /// rebuild path without simulating a text selection + menu).
        case addComment(substring: String, body: String)

        /// Select the first occurrence of `substring` in the rendered text, put
        /// `text` on the general pasteboard, and invoke the text view's paste
        /// action — exercises the paste-creates-comment path end to end.
        case pasteComment(substring: String, text: String)

        /// Synthesize a left click at content-local coordinates (top-left origin,
        /// in points) via `NSApplication.sendEvent` — exercises the real event path
        /// (hit-testing, SwiftUI gestures) without moving the global pointer.
        case clickAt(x: Double, y: Double)

        /// Press the `index`-th accessibility button whose title, label, or
        /// identifier exactly matches `title`. If omitted on the wire, `index`
        /// defaults to 0 in the handler.
        case pressButton(title: String, index: Int?)

        /// Dump the accessibility tree of every visible window (role, label,
        /// identifier, value, frame) so the runner can discover elements to
        /// drive — the same tree VoiceOver navigates. `maxDepth` defaults to
        /// 25 in the handler.
        case axTree(maxDepth: Int?)

        /// Trigger an accessibility action on the `index`-th element (any
        /// role, not just buttons) whose title, label, or identifier exactly
        /// matches `query`. With `action` nil, performs the default press;
        /// otherwise the named custom action (e.g. "Jump to Comment").
        case axPress(query: String, action: String?, index: Int?)

        /// List the text view's VoiceOver custom rotors and each rotor's
        /// items, by walking the same search delegate VoiceOver uses (VO+U).
        case axRotors

        /// Read the phase timings recorded for the most recent document open.
        case getOpenTimings

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
#endif
