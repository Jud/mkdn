import Foundation
import Testing

@testable import mkdnLib

/// Capture orchestrator for the animation vision verification workflow.
///
/// Produces frame sequences of entrance animations for all animation
/// fixtures across both Solarized themes in preview-only mode. Frame
/// sequences are saved to `.rp1/work/verification/captures/animation/`
/// with a manifest recording per-sequence metadata.
///
/// Uses the capture-before-load pattern: beginFrameCapture starts
/// SCStream (returns immediately), then loadFile triggers the entrance
/// animation, then after a delay endFrameCapture stops and returns
/// frame paths.
///
/// The capture matrix is: 6 fixtures x 2 themes = 12 sequences.
@Suite("AnimationVisionCapture", .serialized)
struct AnimationVisionCaptureTests {
    @Test("Capture all animation fixtures for vision verification")
    func captureAllAnimationFixtures() async throws {
        let client = try await AnimationVisionHarness.ensureRunning()

        try await Task.sleep(for: .seconds(3))

        let outputDir = animationVisionOutputDir()
        let projectRoot = animationVisionProjectRoot().path

        try FileManager.default.createDirectory(
            atPath: outputDir,
            withIntermediateDirectories: true
        )

        var entries: [AnimationFrameSequenceEntry] = []

        for fixture in AnimationVisionConfig.fixtures {
            for theme in AnimationVisionConfig.themes {
                let entry = try await captureAnimation(
                    fixture,
                    theme: theme,
                    client: client,
                    outputDir: outputDir,
                    projectRoot: projectRoot
                )
                entries.append(entry)
            }
        }

        try animationVisionWriteManifest(entries: entries, to: outputDir)

        validateCaptureResults(entries: entries)

        recordCaptureResult(entries: entries)
    }

    // MARK: - Per-Fixture Capture

    private func captureAnimation(
        _ fixture: String,
        theme: String,
        client: TestHarnessClient,
        outputDir: String,
        projectRoot: String
    ) async throws -> AnimationFrameSequenceEntry {
        let setResp = try await client.setTheme(theme)
        try #require(
            setResp.status == "ok",
            "setTheme(\(theme)) failed: \(setResp.message ?? "unknown")"
        )

        let captureId = animationVisionCaptureId(
            fixture: fixture,
            theme: theme
        )
        let sequenceDir = URL(fileURLWithPath: outputDir)
            .appendingPathComponent(captureId)
            .path

        try FileManager.default.createDirectory(
            atPath: sequenceDir,
            withIntermediateDirectories: true
        )

        let result = try await executeCapture(
            fixture: fixture,
            sequenceDir: sequenceDir,
            client: client
        )

        return try buildEntry(
            captureId: captureId,
            fixture: fixture,
            theme: theme,
            sequenceDir: sequenceDir,
            result: result,
            projectRoot: projectRoot
        )
    }

    private func executeCapture(
        fixture: String,
        sequenceDir: String,
        client: TestHarnessClient
    ) async throws -> FrameCaptureResult {
        let resetPath = animationVisionFixturePath("anim-headings.md")
        if fixture != "anim-headings.md" {
            _ = try await client.loadFile(path: resetPath)
            try await Task.sleep(for: .milliseconds(1_500))
        }

        let beginResp = try await client.beginFrameCapture(
            fps: AnimationVisionConfig.captureFPS,
            outputDir: sequenceDir
        )
        try #require(
            beginResp.status == "ok",
            "beginFrameCapture failed: \(beginResp.message ?? "unknown")"
        )

        let fixturePath = animationVisionFixturePath(fixture)
        let loadResp = try await client.loadFile(path: fixturePath)
        try #require(
            loadResp.status == "ok",
            "loadFile(\(fixture)) failed: \(loadResp.message ?? "unknown")"
        )

        try await Task.sleep(
            for: .seconds(AnimationVisionConfig.captureDuration)
        )

        let endResp = try await client.endFrameCapture()
        return try animationVisionExtractFrameCapture(from: endResp)
    }

    private func buildEntry(
        captureId: String,
        fixture: String,
        theme: String,
        sequenceDir: String,
        result: FrameCaptureResult,
        projectRoot: String
    ) throws -> AnimationFrameSequenceEntry {
        let relativeDir = String(
            sequenceDir.dropFirst(projectRoot.count + 1)
        )
        let frameHashes = try result.framePaths.map { path in
            try animationVisionImageHash(atPath: path)
        }
        let relativePaths = result.framePaths.map { path in
            String(path.dropFirst(projectRoot.count + 1))
        }

        return AnimationFrameSequenceEntry(
            id: captureId,
            fixture: fixture,
            theme: theme,
            viewMode: AnimationVisionConfig.viewMode,
            frameDir: relativeDir,
            frameCount: result.frameCount,
            fps: result.fps,
            duration: result.duration,
            framePaths: relativePaths,
            frameHashes: frameHashes
        )
    }

    // MARK: - Validation

    private func validateCaptureResults(
        entries: [AnimationFrameSequenceEntry]
    ) {
        let expectedCount = AnimationVisionConfig.fixtures.count
            * AnimationVisionConfig.themes.count
        #expect(
            entries.count == expectedCount,
            """
            Capture matrix must produce \(expectedCount) sequences \
            (\(AnimationVisionConfig.fixtures.count) fixtures \
            x \(AnimationVisionConfig.themes.count) themes)
            """
        )

        let manifestURL = URL(
            fileURLWithPath: animationVisionOutputDir()
        ).appendingPathComponent("manifest.json")
        #expect(
            FileManager.default.fileExists(atPath: manifestURL.path),
            "manifest.json must exist after capture"
        )

        for entry in entries {
            #expect(
                entry.frameCount > 0,
                "Sequence \(entry.id) must capture at least one frame"
            )
            #expect(
                entry.fps == AnimationVisionConfig.captureFPS,
                "Sequence \(entry.id) must use configured FPS"
            )
            #expect(
                !entry.frameHashes.isEmpty,
                "Sequence \(entry.id) must have frame hashes"
            )
        }
    }

    // MARK: - Result Recording

    private func recordCaptureResult(
        entries: [AnimationFrameSequenceEntry]
    ) {
        let expectedCount = AnimationVisionConfig.fixtures.count
            * AnimationVisionConfig.themes.count
        let totalFrames = entries.reduce(0) { $0 + $1.frameCount }

        JSONResultReporter.record(TestResult(
            name: "animation-vision: capture orchestrator",
            status: entries.count == expectedCount ? .pass : .fail,
            prdReference: "animation-vision REQ-001",
            expected: "\(expectedCount) sequences",
            actual: "\(entries.count) sequences, \(totalFrames) total frames",
            imagePaths: [],
            duration: 0,
            message: entries.count == expectedCount
                ? nil
                : "Expected \(expectedCount) sequences, got \(entries.count)"
        ))
    }
}
