import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import mkdnLib

/// Smoke tests verifying the full test harness lifecycle works end-to-end.
///
/// **PRD**: automated-ui-testing REQ-001
/// **Dependencies**: Pre-built mkdn binary, Screen Recording permission
///
/// This suite validates the foundational IPC infrastructure that all
/// compliance suites depend on. Each test targets a specific lifecycle
/// step: launch, ping, loadFile, captureWindow, image validity, and quit.
@Suite("HarnessSmoke", .serialized)
struct HarnessSmokeTests {
    nonisolated(unsafe) static var launcher: AppLauncher?
    nonisolated(unsafe) static var client: TestHarnessClient?
    nonisolated(unsafe) static var capturedImagePath: String?

    // MARK: - AC-001a: Launch

    @Test("smokeTest_launch")
    func launch() async throws {
        let newLauncher = AppLauncher()
        let startTime = ContinuousClock.now

        let newClient = try await newLauncher.launch(buildFirst: false)

        let elapsed = ContinuousClock.now - startTime
        let elapsedSeconds = Double(elapsed.components.seconds)
            + Double(elapsed.components.attoseconds) / 1e18

        #expect(
            elapsedSeconds < 60,
            """
            automated-ui-testing AC-001a: \
            AppLauncher.launch() must complete within 60s, \
            took \(elapsedSeconds)s
            """
        )

        Self.launcher = newLauncher
        Self.client = newClient

        JSONResultReporter.record(TestResult(
            name: "automated-ui-testing AC-001a: harness launch",
            status: .pass,
            prdReference: "automated-ui-testing REQ-001",
            expected: "< 60s",
            actual: String(format: "%.2fs", elapsedSeconds),
            imagePaths: [],
            duration: elapsedSeconds,
            message: nil
        ))
    }

    // MARK: - AC-001b: Ping

    @Test("smokeTest_ping")
    func ping() async throws {
        let activeClient = try #require(
            Self.client,
            "Client must be connected (launch test must pass first)"
        )

        let response = try await activeClient.ping()

        #expect(
            response.status == "ok",
            """
            automated-ui-testing AC-001b: \
            ping must return status 'ok', got '\(response.status)'
            """
        )

        guard let data = response.data, case .pong = data else {
            Issue.record(
                """
                automated-ui-testing AC-001b: \
                ping response must contain pong data
                """
            )
            recordSmokeResult(
                name: "ping",
                status: .fail,
                expected: "pong response data",
                actual: "missing or wrong data type",
                message: "Ping response missing pong data"
            )
            return
        }

        recordSmokeResult(
            name: "ping",
            status: .pass,
            expected: "pong",
            actual: "pong"
        )
    }

    // MARK: - AC-001c: Load File

    @Test("smokeTest_loadFile")
    func loadFile() async throws {
        let activeClient = try #require(
            Self.client,
            "Client must be connected"
        )

        let fixturePath = smokeFixturePath("canonical.md")
        let response = try await activeClient.loadFile(path: fixturePath)

        #expect(
            response.status == "ok",
            """
            automated-ui-testing AC-001c: \
            loadFile must return status 'ok', \
            got '\(response.status)': \(response.message ?? "no message")
            """
        )

        recordSmokeResult(
            name: "loadFile",
            status: response.status == "ok" ? .pass : .fail,
            expected: "ok with render completion",
            actual: response.status,
            message: response.status == "ok"
                ? nil
                : "loadFile failed: \(response.message ?? "unknown")"
        )
    }

    // MARK: - AC-001d: Capture Window

    @Test("smokeTest_captureWindow")
    func captureWindow() async throws {
        let activeClient = try #require(
            Self.client,
            "Client must be connected"
        )

        let response = try await activeClient.captureWindow()
        #expect(
            response.status == "ok",
            """
            automated-ui-testing AC-001d: \
            captureWindow must return status 'ok', \
            got '\(response.status)': \(response.message ?? "no message")
            """
        )

        let capture = try extractCapture(from: response)
        assertCaptureMetrics(capture)
        Self.capturedImagePath = capture.imagePath
    }

    // MARK: - AC-001e: Image Content Validity

    @Test("smokeTest_imageContentValidity")
    func imageContentValidity() throws {
        let imagePath = try #require(
            Self.capturedImagePath,
            "Capture must produce an image path (captureWindow test must pass)"
        )
        let analyzer = try loadImageAnalyzer(at: imagePath)
        assertImageContent(analyzer, imagePath: imagePath)
    }

    // MARK: - AC-001f: Quit

    @Test("smokeTest_quit")
    func quit() async throws {
        let activeClient = try #require(
            Self.client,
            "Client must be connected"
        )

        let response = try await activeClient.quit()

        #expect(
            response.status == "ok",
            """
            automated-ui-testing AC-001f: \
            quit must return status 'ok', got '\(response.status)'
            """
        )

        activeClient.disconnect()
        Self.client = nil

        try await Task.sleep(for: .seconds(2))

        if let activeLauncher = Self.launcher {
            await activeLauncher.teardown()
        }
        Self.launcher = nil

        recordSmokeResult(
            name: "quit",
            status: .pass,
            expected: "clean shutdown",
            actual: "ok"
        )
    }
}

// MARK: - Capture Assertions

private extension HarnessSmokeTests {
    func assertCaptureMetrics(_ capture: CaptureResult) {
        #expect(capture.width > 0, "Captured image must have non-zero width")
        #expect(capture.height > 0, "Captured image must have non-zero height")
        #expect(
            capture.scaleFactor == 2.0,
            "Scale factor must be 2.0 (Retina), got \(capture.scaleFactor)"
        )
        let fileExists = FileManager.default.fileExists(
            atPath: capture.imagePath
        )
        #expect(fileExists, "PNG file must exist at \(capture.imagePath)")

        let passed = capture.width > 0
            && capture.height > 0
            && capture.scaleFactor == 2.0
            && fileExists

        recordSmokeResult(
            name: "captureWindow",
            status: passed ? .pass : .fail,
            expected: "non-zero dimensions, 2x scale, PNG exists",
            actual: "\(capture.width)x\(capture.height) @\(capture.scaleFactor)x, exists=\(fileExists)",
            imagePaths: [capture.imagePath],
            message: passed ? nil : "Capture validation failed"
        )
    }
}

// MARK: - Image Validation

private extension HarnessSmokeTests {
    func loadImageAnalyzer(at path: String) throws -> ImageAnalyzer {
        let url = URL(fileURLWithPath: path) as CFURL
        let source = try #require(
            CGImageSourceCreateWithURL(url, nil),
            "AC-001e: PNG must be loadable via CGImageSource"
        )
        let image = try #require(
            CGImageSourceCreateImageAtIndex(source, 0, nil),
            "AC-001e: CGImageSource must produce a CGImage"
        )
        return ImageAnalyzer(image: image, scaleFactor: 2.0)
    }

    func assertImageContent(
        _ analyzer: ImageAnalyzer,
        imagePath: String
    ) {
        #expect(analyzer.pointWidth > 0, "Non-zero point width")
        #expect(analyzer.pointHeight > 0, "Non-zero point height")

        let centerColor = analyzer.sampleColor(
            at: CGPoint(
                x: analyzer.pointWidth / 2,
                y: analyzer.pointHeight / 2
            )
        )
        let cornerColor = analyzer.sampleColor(
            at: CGPoint(x: 10, y: 10)
        )

        let isNotBlank = centerColor.alpha > 0 || cornerColor.alpha > 0
        #expect(isNotBlank, "AC-001e: image must contain pixel data")

        let isNotAllBlack = hasNonBlackPixel(centerColor)
            || hasNonBlackPixel(cornerColor)
        #expect(
            isNotAllBlack,
            "AC-001e: image must not be all black. center=\(centerColor), corner=\(cornerColor)"
        )

        let passed = isNotBlank && isNotAllBlack
        let variation = centerColor.distance(to: cornerColor) > 0

        recordSmokeResult(
            name: "imageContentValidity",
            status: passed ? .pass : .fail,
            expected: "real pixel data, not blank/black",
            actual: "center=\(centerColor), corner=\(cornerColor), variation=\(variation)",
            imagePaths: [imagePath],
            message: passed ? nil : "Image appears blank or all-black"
        )
    }

    func hasNonBlackPixel(_ color: PixelColor) -> Bool {
        color.red > 0 || color.green > 0 || color.blue > 0
    }
}

// MARK: - Result Recording

private extension HarnessSmokeTests {
    func recordSmokeResult(
        name: String,
        status: TestStatus,
        expected: String,
        actual: String,
        imagePaths: [String] = [],
        message: String? = nil
    ) {
        JSONResultReporter.record(TestResult(
            name: "automated-ui-testing AC-001: \(name)",
            status: status,
            prdReference: "automated-ui-testing REQ-001",
            expected: expected,
            actual: actual,
            imagePaths: imagePaths,
            duration: 0,
            message: message
        ))
    }
}

// MARK: - Fixture Path

private func smokeFixturePath(_ name: String) -> String {
    var url = URL(fileURLWithPath: #filePath)
    while url.path != "/" {
        url = url.deletingLastPathComponent()
        let candidate = url
            .appendingPathComponent("mkdnTests/Fixtures/UITest")
            .appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate.path
        }
    }
    preconditionFailure("Fixture \(name) not found")
}
