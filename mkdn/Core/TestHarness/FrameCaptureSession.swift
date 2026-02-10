import AppKit
import CoreImage
import CoreMedia
import ScreenCaptureKit

/// Manages a ScreenCaptureKit-based frame capture session for animation verification.
///
/// Uses ``SCStream`` for asynchronous, hardware-accelerated frame delivery at
/// configurable frame rates (30--60 fps). Frames are written as numbered PNGs
/// to the output directory as they arrive, using a dedicated serial I/O queue
/// to avoid blocking the capture pipeline.
///
/// **Permission**: Screen Recording permission is required. The system will
/// prompt on first use. Grant access in System Preferences > Privacy & Security
/// > Screen Recording for Terminal (or the CI agent).
final class FrameCaptureSession: NSObject, @unchecked Sendable {
    private let captureQueue = DispatchQueue(
        label: "mkdn.frame-capture.stream"
    )
    private let ioQueue = DispatchQueue(
        label: "mkdn.frame-capture.io"
    )
    private let writeGroup = DispatchGroup()
    private let lock = NSLock()

    private var stream: SCStream?
    private var frameCount = 0
    private var framePaths: [String] = []
    private var outputDirectory = ""
    private var startTime: Date?
    private var captureError: (any Error)?

    private let ciContext = CIContext()

    /// Captures frames from the specified window for a given duration.
    ///
    /// Creates an ``SCStream`` filtered to the app's own window using
    /// ``SCContentFilter(desktopIndependentWindow:)``, starts capture,
    /// waits for `duration` seconds, then stops and returns the result.
    ///
    /// - Parameters:
    ///   - windowID: The ``CGWindowID`` of the target window.
    ///   - windowSize: Window size in points.
    ///   - scaleFactor: Display scale factor (e.g., 2.0 for Retina).
    ///   - fps: Target frames per second (30--60).
    ///   - duration: Capture duration in seconds.
    ///   - outputDir: Directory to write numbered PNG frames.
    /// - Returns: A ``FrameCaptureResult`` with frame paths and metadata.
    func capture(
        windowID: CGWindowID,
        windowSize: CGSize,
        scaleFactor: CGFloat,
        fps: Int,
        duration: TimeInterval,
        outputDir: String
    ) async throws -> FrameCaptureResult {
        try FileManager.default.createDirectory(
            atPath: outputDir,
            withIntermediateDirectories: true
        )

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: false
        )

        guard let scWindow = content.windows.first(where: { window in
            window.windowID == windowID
        })
        else {
            throw HarnessError.captureFailed(
                "No ScreenCaptureKit window for ID \(windowID)"
            )
        }

        let filter = SCContentFilter(desktopIndependentWindow: scWindow)

        let config = SCStreamConfiguration()
        config.width = Int(windowSize.width * scaleFactor)
        config.height = Int(windowSize.height * scaleFactor)
        config.minimumFrameInterval = CMTime(
            value: 1,
            timescale: CMTimeScale(fps)
        )
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false

        let scStream = SCStream(
            filter: filter,
            configuration: config,
            delegate: self
        )
        try scStream.addStreamOutput(
            self,
            type: .screen,
            sampleHandlerQueue: captureQueue
        )

        resetState(scStream: scStream, outputDir: outputDir)

        try await scStream.startCapture()
        try await Task.sleep(for: .seconds(duration))
        try await scStream.stopCapture()

        await awaitPendingWrites()

        return try gatherResult(outputDir: outputDir, fps: fps)
    }

    // MARK: - Split Start/Stop Lifecycle

    /// Starts frame capture without blocking. Call ``stop()`` to end
    /// capture and retrieve results.
    ///
    /// Creates an ``SCStream`` filtered to the app's own window, starts
    /// capture, and returns immediately. The session continues capturing
    /// frames in the background until ``stop()`` is called.
    ///
    /// - Parameters:
    ///   - windowID: The ``CGWindowID`` of the target window.
    ///   - windowSize: Window size in points.
    ///   - scaleFactor: Display scale factor (e.g., 2.0 for Retina).
    ///   - fps: Target frames per second (30--60).
    ///   - outputDir: Directory to write numbered PNG frames.
    func start(
        windowID: CGWindowID,
        windowSize: CGSize,
        scaleFactor: CGFloat,
        fps: Int,
        outputDir: String
    ) async throws {
        try FileManager.default.createDirectory(
            atPath: outputDir,
            withIntermediateDirectories: true
        )

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: false
        )

        guard let scWindow = content.windows.first(where: { window in
            window.windowID == windowID
        })
        else {
            throw HarnessError.captureFailed(
                "No ScreenCaptureKit window for ID \(windowID)"
            )
        }

        let filter = SCContentFilter(desktopIndependentWindow: scWindow)

        let config = SCStreamConfiguration()
        config.width = Int(windowSize.width * scaleFactor)
        config.height = Int(windowSize.height * scaleFactor)
        config.minimumFrameInterval = CMTime(
            value: 1,
            timescale: CMTimeScale(fps)
        )
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false

        let scStream = SCStream(
            filter: filter,
            configuration: config,
            delegate: self
        )
        try scStream.addStreamOutput(
            self,
            type: .screen,
            sampleHandlerQueue: captureQueue
        )

        resetState(scStream: scStream, outputDir: outputDir)
        setActiveFPS(fps)

        try await scStream.startCapture()
    }

    /// Stops an in-progress capture session and returns the result.
    ///
    /// Stops the ``SCStream``, waits for all pending PNG writes to
    /// complete, and returns the ``FrameCaptureResult``.
    func stop() async throws -> FrameCaptureResult {
        let snapshot = readStopSnapshot()

        guard let activeStream = snapshot.stream else {
            throw HarnessError.captureFailed("No active capture stream")
        }

        try await activeStream.stopCapture()
        await awaitPendingWrites()

        return try gatherResult(outputDir: snapshot.dir, fps: snapshot.fps)
    }

    // MARK: - State Management

    private var activeFPS = 30

    private func setActiveFPS(_ fps: Int) {
        lock.lock()
        activeFPS = fps
        lock.unlock()
    }

    private struct StopSnapshot {
        let stream: SCStream?
        let fps: Int
        let dir: String
    }

    private func readStopSnapshot() -> StopSnapshot {
        lock.lock()
        let snapshot = StopSnapshot(
            stream: stream,
            fps: activeFPS,
            dir: outputDirectory
        )
        lock.unlock()
        return snapshot
    }

    private func resetState(scStream: SCStream, outputDir: String) {
        lock.lock()
        stream = scStream
        frameCount = 0
        framePaths = []
        outputDirectory = outputDir
        startTime = Date()
        captureError = nil
        lock.unlock()
    }

    private func awaitPendingWrites() async {
        await withCheckedContinuation { continuation in
            writeGroup.notify(queue: ioQueue) {
                continuation.resume()
            }
        }
    }

    private func gatherResult(
        outputDir: String,
        fps: Int
    ) throws -> FrameCaptureResult {
        lock.lock()
        let paths = framePaths.sorted()
        let count = paths.count
        let start = startTime ?? Date()
        let error = captureError
        lock.unlock()

        if let error {
            throw HarnessError.captureFailed(
                "Stream error: \(error.localizedDescription)"
            )
        }

        return FrameCaptureResult(
            frameDir: outputDir,
            frameCount: count,
            fps: fps,
            duration: Date().timeIntervalSince(start),
            framePaths: paths
        )
    }
}

// MARK: - SCStreamOutput

extension FrameCaptureSession: SCStreamOutput {
    func stream(
        _: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        guard let cgImage = ciContext.createCGImage(
            ciImage,
            from: ciImage.extent
        )
        else { return }

        lock.lock()
        frameCount += 1
        let index = frameCount
        let dir = outputDirectory
        lock.unlock()

        let filename = String(format: "frame_%04d.png", index)
        let dirURL = URL(fileURLWithPath: dir)
        let path = dirURL.appendingPathComponent(filename).path

        writeGroup.enter()
        ioQueue.async { [self] in
            defer { writeGroup.leave() }
            let rep = NSBitmapImageRep(cgImage: cgImage)

            guard let data = rep.representation(
                using: .png,
                properties: [:]
            )
            else { return }
            try? data.write(to: URL(fileURLWithPath: path))

            lock.lock()
            framePaths.append(path)
            lock.unlock()
        }
    }
}

// MARK: - SCStreamDelegate

extension FrameCaptureSession: SCStreamDelegate {
    func stream(_: SCStream, didStopWithError error: any Error) {
        lock.lock()
        captureError = error
        lock.unlock()
    }
}
