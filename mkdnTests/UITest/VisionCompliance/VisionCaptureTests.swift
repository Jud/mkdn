import Foundation
import Testing

@testable import mkdnLib

/// Capture orchestrator for the LLM visual verification workflow.
///
/// Produces deterministic screenshots of all test fixtures across both
/// Solarized themes in preview-only mode. Screenshots are saved to
/// `.rp1/work/verification/captures/` with a manifest recording
/// metadata for each capture.
///
/// **PRD**: llm-visual-verification REQ-001 (Vision-Based Design Evaluation)
/// **Design**: design.md section 3.7 (Capture Orchestrator)
///
/// The capture matrix is: 4 fixtures x 2 themes x 1 mode = 8 captures.
/// A 1500ms sleep after each loadFile accounts for the entrance animation
/// (staggerCap 0.5s + fadeIn 0.5s + cleanup 0.1s = 1.1s, rounded up).
@Suite("VisionCapture", .serialized)
struct VisionCaptureTests {
    @Test("Capture all fixtures for vision verification")
    func captureAllFixtures() async throws {
        let client = try await VisionCaptureHarness.ensureRunning()

        // Workaround: Give the SwiftUI view hierarchy time to complete
        // initial layout. The harness socket becomes available before
        // SelectableTextView's .task(id:) completes its initial render
        // cycle, causing the RenderCompletionSignal to miss the first
        // loadFile. This delay ensures the view is ready to receive
        // content updates. See: RenderCompletionSignal.awaitRenderComplete()
        try await Task.sleep(for: .seconds(3))

        let outputDir = visionCaptureOutputDir()
        let projectRoot = visionCaptureProjectRoot().path

        try FileManager.default.createDirectory(
            atPath: outputDir,
            withIntermediateDirectories: true
        )

        var entries: [CaptureManifestEntry] = []

        for fixture in VisionCaptureConfig.fixtures {
            for theme in VisionCaptureConfig.themes {
                let entry = try await captureFixture(
                    fixture,
                    theme: theme,
                    client: client,
                    outputDir: outputDir,
                    projectRoot: projectRoot
                )
                entries.append(entry)
            }
        }

        try visionCaptureWriteManifest(entries: entries, to: outputDir)

        validateCaptureResults(entries: entries, projectRoot: projectRoot)

        recordCaptureResult(entries: entries)
    }

    // MARK: - Per-Fixture Capture

    private func captureFixture(
        _ fixture: String,
        theme: String,
        client: TestHarnessClient,
        outputDir: String,
        projectRoot: String
    ) async throws -> CaptureManifestEntry {
        let setResp = try await client.setTheme(theme)
        try #require(
            setResp.status == "ok",
            "setTheme(\(theme)) failed: \(setResp.message ?? "unknown error")"
        )

        let fixturePath = visionCaptureFixturePath(fixture)
        let loadResp = try await client.loadFile(path: fixturePath)
        try #require(
            loadResp.status == "ok",
            "loadFile(\(fixture)) failed: \(loadResp.message ?? "unknown error")"
        )

        try await Task.sleep(for: .milliseconds(1_500))

        let captureId = visionCaptureId(fixture: fixture, theme: theme)
        let outputURL = URL(fileURLWithPath: outputDir)
            .appendingPathComponent("\(captureId).png")

        let captureResp = try await client.captureWindow(
            outputPath: outputURL.path
        )
        let result = try VisionCaptureExtract.extractResult(
            from: captureResp
        )

        let imageHash = try visionCaptureImageHash(
            atPath: result.imagePath
        )

        let relativePath = String(
            result.imagePath.dropFirst(projectRoot.count + 1)
        )

        return CaptureManifestEntry(
            id: captureId,
            imagePath: relativePath,
            fixture: fixture,
            theme: theme,
            viewMode: VisionCaptureConfig.viewMode,
            width: result.width,
            height: result.height,
            scaleFactor: result.scaleFactor,
            imageHash: imageHash
        )
    }

    // MARK: - Validation

    private func validateCaptureResults(
        entries: [CaptureManifestEntry],
        projectRoot: String
    ) {
        #expect(
            entries.count == 8,
            "Capture matrix must produce 8 captures (4 fixtures x 2 themes)"
        )

        let manifestURL = URL(fileURLWithPath: visionCaptureOutputDir())
            .appendingPathComponent("manifest.json")
        #expect(
            FileManager.default.fileExists(atPath: manifestURL.path),
            "manifest.json must exist after capture"
        )

        for entry in entries {
            let absoluteURL = URL(fileURLWithPath: projectRoot)
                .appendingPathComponent(entry.imagePath)
            #expect(
                FileManager.default.fileExists(atPath: absoluteURL.path),
                "Capture \(entry.id) must produce a PNG file"
            )
            #expect(
                entry.imageHash.hasPrefix("sha256:"),
                "Image hash for \(entry.id) must be a SHA-256 digest"
            )
            #expect(
                entry.width > 0 && entry.height > 0,
                "Capture \(entry.id) must have non-zero dimensions"
            )
            #expect(
                entry.scaleFactor > 0,
                "Capture \(entry.id) must have a positive scale factor"
            )
        }
    }

    // MARK: - Result Recording

    private func recordCaptureResult(entries: [CaptureManifestEntry]) {
        JSONResultReporter.record(TestResult(
            name: "llm-visual-verification: capture orchestrator",
            status: entries.count == 8 ? .pass : .fail,
            prdReference: "llm-visual-verification REQ-001",
            expected: "8 captures",
            actual: "\(entries.count) captures",
            imagePaths: entries.map(\.imagePath),
            duration: 0,
            message: entries.count == 8
                ? nil
                : "Expected 8 captures, got \(entries.count)"
        ))
    }
}
