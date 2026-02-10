import AppKit
import CoreGraphics

@MainActor
enum CaptureService {
    private static var captureCounter = 0
    static var activeFrameSession: FrameCaptureSession?

    // MARK: - Full Window Capture

    static func captureWindow(
        _ window: NSWindow,
        outputPath: String?,
        appSettings: AppSettings,
        documentState: DocumentState
    ) throws -> CaptureResult {
        let windowID = CGWindowID(window.windowNumber)
        guard let cgImage = captureWindowImage(windowID) else {
            throw HarnessError.captureFailed(
                "CGWindowListCreateImage returned nil"
            )
        }
        let path = try writePNG(cgImage, to: outputPath)
        return CaptureResult(
            imagePath: path,
            width: cgImage.width,
            height: cgImage.height,
            scaleFactor: window.backingScaleFactor,
            timestamp: Date(),
            theme: appSettings.theme.rawValue,
            viewMode: documentState.viewMode.rawValue
        )
    }

    // MARK: - Region Capture

    static func captureRegion(
        _ window: NSWindow,
        region: CGRect,
        outputPath: String?,
        appSettings: AppSettings,
        documentState: DocumentState
    ) throws -> CaptureResult {
        let windowID = CGWindowID(window.windowNumber)
        let scaleFactor = window.backingScaleFactor
        guard let fullImage = captureWindowImage(windowID) else {
            throw HarnessError.captureFailed(
                "CGWindowListCreateImage returned nil"
            )
        }
        let scaledRegion = CGRect(
            x: region.origin.x * scaleFactor,
            y: region.origin.y * scaleFactor,
            width: region.width * scaleFactor,
            height: region.height * scaleFactor
        )
        guard let cropped = fullImage.cropping(to: scaledRegion) else {
            throw HarnessError.captureFailed(
                "Could not crop to region \(scaledRegion)"
            )
        }
        let path = try writePNG(cropped, to: outputPath)
        return CaptureResult(
            imagePath: path,
            width: cropped.width,
            height: cropped.height,
            scaleFactor: scaleFactor,
            timestamp: Date(),
            theme: appSettings.theme.rawValue,
            viewMode: documentState.viewMode.rawValue
        )
    }

    // MARK: - Frame Sequence Capture

    static func startFrameCapture(
        _ window: NSWindow,
        fps: Int,
        duration: TimeInterval,
        outputDir: String?
    ) async throws -> FrameCaptureResult {
        let session = FrameCaptureSession()
        activeFrameSession = session
        defer { activeFrameSession = nil }

        let dir = outputDir ?? defaultFrameDir()

        return try await session.capture(
            windowID: CGWindowID(window.windowNumber),
            windowSize: window.frame.size,
            scaleFactor: window.backingScaleFactor,
            fps: fps,
            duration: duration,
            outputDir: dir
        )
    }

    // MARK: - Split Frame Capture (Non-Blocking)

    static func beginFrameCapture(
        _ window: NSWindow,
        fps: Int,
        outputDir: String?
    ) async throws {
        let session = FrameCaptureSession()
        activeFrameSession = session

        let dir = outputDir ?? defaultFrameDir()

        try await session.start(
            windowID: CGWindowID(window.windowNumber),
            windowSize: window.frame.size,
            scaleFactor: window.backingScaleFactor,
            fps: fps,
            outputDir: dir
        )
    }

    static func endFrameCapture() async throws -> FrameCaptureResult {
        guard let session = activeFrameSession else {
            throw HarnessError.captureFailed(
                "No active frame capture session"
            )
        }
        defer { activeFrameSession = nil }

        return try await session.stop()
    }

    private static func defaultFrameDir() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let dir = "/tmp/mkdn-frames/\(timestamp)"
        try? FileManager.default.createDirectory(
            atPath: dir,
            withIntermediateDirectories: true
        )
        return dir
    }

    // MARK: - Window Image Capture

    @available(macOS, deprecated: 14.0)
    private static func captureWindowImage(
        _ windowID: CGWindowID
    ) -> CGImage? {
        CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        )
    }

    // MARK: - PNG Writing

    private static func writePNG(
        _ image: CGImage,
        to outputPath: String?
    ) throws -> String {
        captureCounter += 1
        let path = outputPath ?? defaultCapturePath()
        let rep = NSBitmapImageRep(cgImage: image)
        guard let pngData = rep.representation(
            using: .png,
            properties: [:]
        )
        else {
            throw HarnessError.captureFailed("Failed to create PNG data")
        }
        try pngData.write(to: URL(fileURLWithPath: path))
        return path
    }

    private static func defaultCapturePath() -> String {
        let dir = "/tmp/mkdn-captures"
        try? FileManager.default.createDirectory(
            atPath: dir,
            withIntermediateDirectories: true
        )
        let counter = String(format: "%04d", captureCounter)
        return "\(dir)/mkdn-capture-\(counter).png"
    }
}
