import AppKit
import Foundation

// MARK: - Test Harness Mode

public enum ReduceMotionOverride: Sendable {
    case systemDefault
    case forceEnabled
    case forceDisabled
}

public enum TestHarnessMode {
    public nonisolated(unsafe) static var isEnabled = false
    public nonisolated(unsafe) static var socketPath: String?
    public nonisolated(unsafe) static var parentPID: pid_t?
    @MainActor public static var reduceMotion: ReduceMotionOverride = .systemDefault

    /// Monitor whether the parent process (test runner) is still alive.
    /// Polls every 2 seconds. When the parent PID no longer exists,
    /// terminates this app so no orphaned processes remain.
    public static func startWatchdog() {
        guard let ppid = parentPID else { return }
        DispatchQueue.global(qos: .utility).async {
            while true {
                sleep(2)
                // kill(pid, 0) checks existence without sending a signal.
                if kill(ppid, 0) != 0 {
                    DispatchQueue.main.async {
                        NSApplication.shared.terminate(nil)
                    }
                    return
                }
            }
        }
    }
}

// MARK: - Async Bridge

private final class AsyncBridge<T: Sendable>: @unchecked Sendable {
    private var result: T?
    private let semaphore = DispatchSemaphore(value: 0)

    func complete(with value: T) {
        result = value
        semaphore.signal()
    }

    func wait() -> T {
        semaphore.wait()
        // swiftlint:disable:next force_unwrapping
        return result!
    }
}

// MARK: - Test Harness Server

public final class TestHarnessServer: @unchecked Sendable {
    public static let shared = TestHarnessServer()

    private let socketQueue = DispatchQueue(label: "mkdn.test-harness.socket")
    private var serverFD: Int32 = -1
    private var isRunning = false
    private var socketPath = ""

    private init() {}

    @MainActor
    public func start() {
        guard !isRunning else { return }
        socketPath = TestHarnessMode.socketPath ?? HarnessSocket.currentPath
        isRunning = true
        let path = socketPath
        socketQueue.async { [self] in
            runSocketLoop(path: path)
        }
    }

    public func stop() {
        isRunning = false
        if serverFD >= 0 {
            Darwin.close(serverFD)
            serverFD = -1
        }
        if !socketPath.isEmpty {
            unlink(socketPath)
        }
    }

    // MARK: - Socket Setup

    private func createServerSocket(path: String) -> Int32? {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }

        unlink(path)

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        copySocketPath(path, into: &addr)

        let bound = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0 else {
            Darwin.close(fd)
            return nil
        }
        guard listen(fd, 1) == 0 else {
            Darwin.close(fd)
            return nil
        }
        return fd
    }

    private func copySocketPath(_ path: String, into addr: inout sockaddr_un) {
        let maxLen = MemoryLayout.size(ofValue: addr.sun_path)
        withUnsafeMutablePointer(to: &addr.sun_path) { sunPath in
            let dest = UnsafeMutableRawPointer(sunPath)
                .assumingMemoryBound(to: CChar.self)
            path.withCString { src in
                _ = strlcpy(dest, src, maxLen)
            }
        }
    }

    // MARK: - Socket Loop

    private func runSocketLoop(path: String) {
        guard let fd = createServerSocket(path: path) else {
            isRunning = false
            return
        }
        serverFD = fd

        while isRunning {
            let clientFD = accept(serverFD, nil, nil)
            guard clientFD >= 0 else {
                if !isRunning { break }
                continue
            }
            handleClient(clientFD)
            Darwin.close(clientFD)
        }
    }

    // MARK: - Client Handling

    private func handleClient(_ clientFD: Int32) {
        var buffer = Data()
        let readSize = 4_096
        let readBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: readSize)
        defer { readBuf.deallocate() }

        while isRunning {
            let bytesRead = Darwin.read(clientFD, readBuf, readSize)
            if bytesRead <= 0 { break }
            buffer.append(readBuf, count: bytesRead)

            while let newlineIdx = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer[buffer.startIndex ..< newlineIdx]
                buffer = Data(buffer[buffer.index(after: newlineIdx)...])
                processLine(Data(lineData), clientFD: clientFD)
                if !isRunning { return }
            }
        }
    }

    private func processLine(_ lineData: Data, clientFD: Int32) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let command = try? decoder.decode(
            HarnessCommand.self,
            from: lineData
        )
        else {
            writeResponse(.error("Failed to decode command"), to: clientFD)
            return
        }

        let bridge = AsyncBridge<HarnessResponse>()
        Task { @MainActor in
            let response = await TestHarnessHandler.process(command)
            bridge.complete(with: response)
        }
        let response = bridge.wait()
        writeResponse(response, to: clientFD)

        if case .quit = command {
            isRunning = false
        }
    }

    // MARK: - Response Writing

    private func writeResponse(_ response: HarnessResponse, to fd: Int32) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard var data = try? encoder.encode(response) else { return }
        data.append(0x0A)
        data.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress else { return }
            var remaining = ptr.count
            var offset = 0
            while remaining > 0 {
                let written = Darwin.write(fd, base + offset, remaining)
                if written <= 0 { break }
                offset += written
                remaining -= written
            }
        }
    }
}
