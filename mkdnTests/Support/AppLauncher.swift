import Foundation

@testable import mkdnLib

/// Builds and launches the mkdn executable in test harness mode,
/// waits for socket readiness, and returns a connected client.
///
/// Each ``AppLauncher`` instance manages one app process lifecycle:
/// launch, communicate via ``TestHarnessClient``, and teardown.
///
/// Usage:
/// ```swift
/// let launcher = AppLauncher()
/// let client = try await launcher.launch()
/// defer { await launcher.teardown() }
///
/// let response = try await client.loadFile(path: testFixturePath)
/// ```
final class AppLauncher: @unchecked Sendable {
    private var process: Process?
    private var client: TestHarnessClient?
    private var socketPath: String?
    private let executablePath: String?

    // MARK: - Process Registry

    private static let registryLock = NSLock()
    private nonisolated(unsafe) static var trackedPIDs: [pid_t] = []
    private nonisolated(unsafe) static var atexitRegistered = false

    private static func trackPID(_ pid: pid_t) {
        registryLock.lock()
        defer { registryLock.unlock() }
        trackedPIDs.append(pid)
        if !atexitRegistered {
            atexitRegistered = true
            // swiftlint:disable:next prefer_self_in_static_references
            atexit { AppLauncher.killAllTracked() }
        }
    }

    private static func untrackPID(_ pid: pid_t) {
        registryLock.lock()
        defer { registryLock.unlock() }
        trackedPIDs.removeAll { $0 == pid }
    }

    private static func killAllTracked() {
        registryLock.lock()
        let pids = trackedPIDs
        trackedPIDs.removeAll()
        registryLock.unlock()
        for pid in pids {
            kill(pid, SIGTERM)
        }
        if !pids.isEmpty {
            usleep(500_000)
            for pid in pids {
                kill(pid, SIGKILL)
            }
        }
    }

    /// Create a launcher with an optional pre-built executable path.
    ///
    /// - Parameter executablePath: Path to the mkdn binary. When nil,
    ///   ``launch(buildFirst:)`` runs `swift build` and locates
    ///   the binary automatically.
    init(executablePath: String? = nil) {
        self.executablePath = executablePath
    }

    // MARK: - Launch

    /// Build, launch, and connect to the mkdn test harness.
    ///
    /// - Parameter buildFirst: When true, runs `swift build --product mkdn`
    ///   before launching. Set to false if the binary is already built.
    /// - Returns: A connected ``TestHarnessClient`` ready for commands.
    func launch(buildFirst: Bool = true) async throws -> TestHarnessClient {
        let binPath = try await resolveBinaryPath(build: buildFirst)
        let proc = try startProcess(at: binPath)

        process = proc

        let pid = proc.processIdentifier
        Self.trackPID(pid)
        let sockPath = HarnessSocket.path(forPID: pid)

        socketPath = sockPath

        let harnessClient = TestHarnessClient(socketPath: sockPath)

        do {
            try await harnessClient.connect()
        } catch {
            proc.terminate()
            Self.untrackPID(pid)
            process = nil
            throw error
        }
        client = harnessClient

        return harnessClient
    }

    private func resolveBinaryPath(build: Bool) async throws -> String {
        if let path = executablePath {
            return path
        }
        if build {
            return try await Self.buildExecutable()
        }
        return Self.packageRoot
            .appendingPathComponent(".build/debug/mkdn").path
    }

    private func startProcess(at path: String) throws -> Process {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = ["--test-harness"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try proc.run()
        return proc
    }

    // MARK: - Teardown

    /// Gracefully shut down the app and clean up resources.
    ///
    /// Sends a quit command to the app, waits for process termination,
    /// and removes the socket file.
    func teardown() async {
        await sendQuit()
        await terminateProcess()
        cleanupSocket()
    }

    private func sendQuit() async {
        guard let activeClient = client else { return }
        _ = try? await activeClient.quit(timeout: .seconds(5))
        activeClient.disconnect()
        client = nil
    }

    private func terminateProcess() async {
        guard let proc = process else { return }

        let pid = proc.processIdentifier
        if proc.isRunning {
            proc.terminate()
            try? await Task.sleep(for: .seconds(2))
        }
        if proc.isRunning {
            kill(pid, SIGKILL)
        }
        Self.untrackPID(pid)
        process = nil
    }

    private func cleanupSocket() {
        guard let path = socketPath else { return }
        unlink(path)
        socketPath = nil
    }

    // MARK: - Build

    private static func buildExecutable() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    let path = try runBuild()
                    continuation.resume(returning: path)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func runBuild() throws -> String {
        let buildProcess = Process()
        buildProcess.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        buildProcess.arguments = ["build", "--product", "mkdn"]
        buildProcess.currentDirectoryURL = packageRoot

        let errorPipe = Pipe()
        buildProcess.standardError = errorPipe
        buildProcess.standardOutput = FileHandle.nullDevice

        try buildProcess.run()
        buildProcess.waitUntilExit()

        guard buildProcess.terminationStatus == 0 else {
            let errData = errorPipe.fileHandleForReading
                .readDataToEndOfFile()

            let errMsg = String(data: errData, encoding: .utf8)
                ?? "Unknown build error"
            throw HarnessError.connectionFailed(
                "swift build failed:\n\(errMsg)"
            )
        }

        return packageRoot
            .appendingPathComponent(".build/debug/mkdn").path
    }

    // MARK: - Helpers

    private static let packageRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        while url.path != "/" {
            url = url.deletingLastPathComponent()

            let manifest = url.appendingPathComponent("Package.swift")

            if FileManager.default.fileExists(atPath: manifest.path) {
                return url
            }
        }
        preconditionFailure("Package.swift not found")
    }()
}
