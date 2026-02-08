import Foundation

@testable import mkdnLib

/// Client for the mkdn test harness server.
///
/// Connects to the Unix domain socket created by ``TestHarnessServer``
/// and provides typed async methods for every ``HarnessCommand``.
/// All blocking socket I/O runs on a dedicated serial queue.
///
/// Usage:
/// ```swift
/// let client = TestHarnessClient(
///     socketPath: HarnessSocket.path(forPID: pid)
/// )
/// try await client.connect()
/// let response = try await client.loadFile(path: "/path/to/test.md")
/// try await client.quit()
/// ```
final class TestHarnessClient: @unchecked Sendable {
    private let socketPath: String
    private var socketFD: Int32 = -1
    private let ioQueue = DispatchQueue(label: "mkdn.test-harness.client")
    private var readBuffer = Data()

    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return enc
    }()

    private let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()

    init(socketPath: String) {
        self.socketPath = socketPath
    }

    deinit {
        disconnect()
    }

    // MARK: - Connection

    /// Connect to the test harness server with retry logic.
    ///
    /// Retries handle the race condition where the test runner
    /// starts before the server socket is ready.
    ///
    /// - Parameters:
    ///   - retryCount: Maximum connection attempts before failing.
    ///   - retryDelay: Delay between consecutive attempts.
    func connect(
        retryCount: Int = 20,
        retryDelay: Duration = .milliseconds(250)
    ) async throws {
        for attempt in 0 ..< retryCount {
            if trySocketConnect() {
                return
            }
            if attempt < retryCount - 1 {
                try await Task.sleep(for: retryDelay)
            }
        }
        throw HarnessError.connectionFailed(
            "Could not connect to \(socketPath) after \(retryCount) attempts"
        )
    }

    /// Close the socket connection.
    func disconnect() {
        guard socketFD >= 0 else { return }

        Darwin.close(socketFD)
        socketFD = -1
        readBuffer.removeAll()
    }

    // MARK: - File Commands

    /// Load a Markdown file at the given path.
    func loadFile(
        path: String,
        timeout: Duration = .seconds(30)
    ) async throws -> HarnessResponse {
        try await send(.loadFile(path: path), timeout: timeout)
    }

    /// Reload the currently loaded file from disk.
    func reloadFile(
        timeout: Duration = .seconds(30)
    ) async throws -> HarnessResponse {
        try await send(.reloadFile, timeout: timeout)
    }

    // MARK: - Mode Commands

    /// Switch the view mode (`"previewOnly"` or `"sideBySide"`).
    func switchMode(
        _ mode: String,
        timeout: Duration = .seconds(15)
    ) async throws -> HarnessResponse {
        try await send(.switchMode(mode: mode), timeout: timeout)
    }

    // MARK: - Theme Commands

    /// Cycle to the next theme mode.
    func cycleTheme(
        timeout: Duration = .seconds(15)
    ) async throws -> HarnessResponse {
        try await send(.cycleTheme, timeout: timeout)
    }

    /// Set a specific theme (`"solarizedDark"` or `"solarizedLight"`).
    func setTheme(
        _ theme: String,
        timeout: Duration = .seconds(15)
    ) async throws -> HarnessResponse {
        try await send(.setTheme(theme: theme), timeout: timeout)
    }

    // MARK: - Capture Commands

    /// Capture the full window as a PNG image.
    func captureWindow(
        outputPath: String? = nil,
        timeout: Duration = .seconds(10)
    ) async throws -> HarnessResponse {
        try await send(
            .captureWindow(outputPath: outputPath),
            timeout: timeout
        )
    }

    /// Capture a rectangular region of the window as a PNG image.
    func captureRegion(
        _ region: CaptureRegion,
        outputPath: String? = nil,
        timeout: Duration = .seconds(10)
    ) async throws -> HarnessResponse {
        try await send(
            .captureRegion(region: region, outputPath: outputPath),
            timeout: timeout
        )
    }

    /// Start a frame sequence capture at the given FPS and duration.
    func startFrameCapture(
        fps: Int,
        duration: Double,
        outputDir: String? = nil,
        timeout: Duration = .seconds(30)
    ) async throws -> HarnessResponse {
        try await send(
            .startFrameCapture(
                fps: fps,
                duration: duration,
                outputDir: outputDir
            ),
            timeout: timeout
        )
    }

    /// Stop an in-progress frame capture.
    func stopFrameCapture(
        timeout: Duration = .seconds(10)
    ) async throws -> HarnessResponse {
        try await send(.stopFrameCapture, timeout: timeout)
    }

    // MARK: - Info Commands

    /// Get current window geometry and display information.
    func getWindowInfo(
        timeout: Duration = .seconds(10)
    ) async throws -> HarnessResponse {
        try await send(.getWindowInfo, timeout: timeout)
    }

    /// Get the current theme's RGB color values.
    func getThemeColors(
        timeout: Duration = .seconds(10)
    ) async throws -> HarnessResponse {
        try await send(.getThemeColors, timeout: timeout)
    }

    // MARK: - Preference Commands

    /// Override the Reduce Motion preference for testing.
    func setReduceMotion(
        enabled: Bool,
        timeout: Duration = .seconds(10)
    ) async throws -> HarnessResponse {
        try await send(
            .setReduceMotion(enabled: enabled),
            timeout: timeout
        )
    }

    // MARK: - Lifecycle Commands

    /// Connectivity check. Expects a pong response.
    func ping(
        timeout: Duration = .seconds(5)
    ) async throws -> HarnessResponse {
        try await send(.ping, timeout: timeout)
    }

    /// Terminate the application.
    func quit(
        timeout: Duration = .seconds(10)
    ) async throws -> HarnessResponse {
        try await send(.quit, timeout: timeout)
    }

    // MARK: - Transport

    private func send(
        _ command: HarnessCommand,
        timeout: Duration
    ) async throws -> HarnessResponse {
        try await withCheckedThrowingContinuation { continuation in
            ioQueue.async { [self] in
                do {
                    let response = try performSend(
                        command,
                        timeout: timeout
                    )

                    continuation.resume(returning: response)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func performSend(
        _ command: HarnessCommand,
        timeout: Duration
    ) throws -> HarnessResponse {
        guard socketFD >= 0 else {
            throw HarnessError.connectionFailed("Not connected")
        }

        var data = try encoder.encode(command)

        data.append(0x0A)
        try writeAll(data)

        let responseData = try readLine(timeout: timeout)

        return try decoder.decode(HarnessResponse.self, from: responseData)
    }

    // MARK: - Socket I/O

    private func writeAll(_ data: Data) throws {
        let bytes = Array(data)
        var offset = 0

        while offset < bytes.count {
            let written = bytes.withUnsafeBufferPointer { buffer -> Int in
                guard let base = buffer.baseAddress else { return -1 }
                return Darwin.write(
                    socketFD,
                    base.advanced(by: offset),
                    bytes.count - offset
                )
            }

            guard written > 0 else {
                throw HarnessError.connectionFailed(
                    "Socket write failed (errno: \(errno))"
                )
            }
            offset += written
        }
    }

    private func readLine(timeout: Duration) throws -> Data {
        if let line = extractLine() {
            return line
        }

        let timeoutMs = Self.pollTimeoutMs(from: timeout)
        let bufSize = 4_096
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)

        defer { buf.deallocate() }

        while true {
            var pfd = pollfd(
                fd: socketFD,
                events: Int16(POLLIN),
                revents: 0
            )

            let pollResult = poll(&pfd, 1, timeoutMs)

            if pollResult == 0 {
                throw HarnessError.unexpectedResponse(
                    "Read timed out waiting for server response"
                )
            }
            if pollResult < 0 {
                throw HarnessError.connectionFailed(
                    "poll() failed (errno: \(errno))"
                )
            }

            let bytesRead = Darwin.read(socketFD, buf, bufSize)

            if bytesRead <= 0 {
                throw HarnessError.connectionFailed(
                    "Server closed the connection"
                )
            }
            readBuffer.append(buf, count: bytesRead)

            if let line = extractLine() {
                return line
            }
        }
    }

    private func extractLine() -> Data? {
        guard let idx = readBuffer.firstIndex(of: 0x0A) else {
            return nil
        }

        let line = Data(readBuffer[readBuffer.startIndex ..< idx])

        readBuffer = Data(readBuffer[readBuffer.index(after: idx)...])
        return line
    }

    // MARK: - Socket Connection

    private func trySocketConnect() -> Bool {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)

        guard fd >= 0 else { return false }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let maxLen = MemoryLayout.size(ofValue: addr.sun_path)

        withUnsafeMutablePointer(to: &addr.sun_path) { sunPath in
            let dest = UnsafeMutableRawPointer(sunPath)
                .assumingMemoryBound(to: CChar.self)
            socketPath.withCString { src in
                _ = strlcpy(dest, src, maxLen)
            }
        }

        let connected = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(
                to: sockaddr.self,
                capacity: 1
            ) { sockPtr in
                Darwin.connect(
                    fd,
                    sockPtr,
                    socklen_t(MemoryLayout<sockaddr_un>.size)
                )
            }
        }

        if connected == 0 {
            socketFD = fd
            return true
        }

        Darwin.close(fd)
        return false
    }

    // MARK: - Helpers

    private static func pollTimeoutMs(from duration: Duration) -> Int32 {
        let (seconds, attoseconds) = duration.components
        let msFromSeconds = seconds * 1_000
        let msFromAttoseconds = attoseconds / 1_000_000_000_000_000

        return Int32(clamping: msFromSeconds + msFromAttoseconds)
    }
}
