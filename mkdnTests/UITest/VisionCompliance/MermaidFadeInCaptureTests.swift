import Foundation
import Testing

@testable import mkdnLib

/// Capture orchestrator for mermaid fade-in animation diagnosis.
///
/// Produces frame sequences of the mermaid entrance animation to
/// reproduce and diagnose a fade-in rendering artifact. Captures
/// are taken across both Solarized themes and both motion modes
/// (normal vs reduce-motion) as an A/B control.
///
/// Uses the capture-before-load pattern: beginFrameCapture starts
/// SCStream, then loadFile triggers the entrance animation, then
/// after 8s endFrameCapture stops and returns frame paths.
///
/// The capture matrix is: 1 fixture x 2 themes x 2 motion modes = 4 sequences.
@Suite("MermaidFadeIn", .serialized)
struct MermaidFadeInCaptureTests {
    @Test("Capture mermaid fade-in across themes and motion modes")
    func captureMermaidFadeIn() async throws {
        let client = try await MermaidFadeInHarness.ensureRunning()

        try await Task.sleep(for: .seconds(3))

        let outputDir = mermaidFadeInOutputDir()
        let projectRoot = mermaidFadeInProjectRoot().path

        try FileManager.default.createDirectory(
            atPath: outputDir,
            withIntermediateDirectories: true
        )

        var entries: [MermaidFadeInFrameSequenceEntry] = []

        for theme in MermaidFadeInConfig.themes {
            for motionMode in MermaidFadeInConfig.motionModes {
                let entry = try await captureSequence(
                    fixture: MermaidFadeInConfig.fixtures[0],
                    theme: theme,
                    motionMode: motionMode,
                    client: client,
                    outputDir: outputDir,
                    projectRoot: projectRoot
                )
                entries.append(entry)
            }
        }

        try mermaidFadeInWriteManifest(entries: entries, to: outputDir)

        validateCaptureResults(entries: entries)

        recordCaptureResult(entries: entries)
    }

    // MARK: - Capture Identity

    private struct CaptureIdentity {
        let captureId: String
        let fixture: String
        let theme: String
        let motionMode: String
    }

    // MARK: - Per-Sequence Capture

    private func captureSequence(
        fixture: String,
        theme: String,
        motionMode: String,
        client: TestHarnessClient,
        outputDir: String,
        projectRoot: String
    ) async throws -> MermaidFadeInFrameSequenceEntry {
        let setResp = try await client.setTheme(theme)
        try #require(
            setResp.status == "ok",
            "setTheme(\(theme)) failed: \(setResp.message ?? "unknown")"
        )

        let reduceMotion = motionMode == "reduceMotion"
        let rmResp = try await client.setReduceMotion(enabled: reduceMotion)
        try #require(
            rmResp.status == "ok",
            "setReduceMotion(\(reduceMotion)) failed: \(rmResp.message ?? "unknown")"
        )

        let identity = CaptureIdentity(
            captureId: mermaidFadeInCaptureId(
                fixture: fixture,
                theme: theme,
                motionMode: motionMode
            ),
            fixture: fixture,
            theme: theme,
            motionMode: motionMode
        )
        let sequenceDir = URL(fileURLWithPath: outputDir)
            .appendingPathComponent(identity.captureId)
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
            identity: identity,
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
        let resetPath = mermaidFadeInFixturePath("geometry-calibration.md")
        _ = try await client.loadFile(path: resetPath)
        try await Task.sleep(for: .milliseconds(1_500))

        let beginResp = try await client.beginFrameCapture(
            fps: MermaidFadeInConfig.captureFPS,
            outputDir: sequenceDir
        )
        try #require(
            beginResp.status == "ok",
            "beginFrameCapture failed: \(beginResp.message ?? "unknown")"
        )

        let fixturePath = mermaidFadeInFixturePath(fixture)
        let loadResp = try await client.loadFile(path: fixturePath)
        try #require(
            loadResp.status == "ok",
            "loadFile(\(fixture)) failed: \(loadResp.message ?? "unknown")"
        )

        try await Task.sleep(
            for: .seconds(MermaidFadeInConfig.captureDuration)
        )

        let endResp = try await client.endFrameCapture()
        return try mermaidFadeInExtractFrameCapture(from: endResp)
    }

    private func buildEntry(
        identity: CaptureIdentity,
        sequenceDir: String,
        result: FrameCaptureResult,
        projectRoot: String
    ) throws -> MermaidFadeInFrameSequenceEntry {
        let relativeDir = String(
            sequenceDir.dropFirst(projectRoot.count + 1)
        )
        let frameHashes = try result.framePaths.map { path in
            try mermaidFadeInImageHash(atPath: path)
        }
        let relativePaths = result.framePaths.map { path in
            String(path.dropFirst(projectRoot.count + 1))
        }

        return MermaidFadeInFrameSequenceEntry(
            id: identity.captureId,
            fixture: identity.fixture,
            theme: identity.theme,
            motionMode: identity.motionMode,
            viewMode: MermaidFadeInConfig.viewMode,
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
        entries: [MermaidFadeInFrameSequenceEntry]
    ) {
        let expectedCount = MermaidFadeInConfig.fixtures.count
            * MermaidFadeInConfig.themes.count
            * MermaidFadeInConfig.motionModes.count
        #expect(
            entries.count == expectedCount,
            """
            Capture matrix must produce \(expectedCount) sequences \
            (\(MermaidFadeInConfig.fixtures.count) fixtures \
            x \(MermaidFadeInConfig.themes.count) themes \
            x \(MermaidFadeInConfig.motionModes.count) motion modes)
            """
        )

        let manifestURL = URL(
            fileURLWithPath: mermaidFadeInOutputDir()
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
                entry.fps == MermaidFadeInConfig.captureFPS,
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
        entries: [MermaidFadeInFrameSequenceEntry]
    ) {
        let expectedCount = MermaidFadeInConfig.fixtures.count
            * MermaidFadeInConfig.themes.count
            * MermaidFadeInConfig.motionModes.count
        let totalFrames = entries.reduce(0) { $0 + $1.frameCount }

        JSONResultReporter.record(TestResult(
            name: "mermaid-fadein: capture orchestrator",
            status: entries.count == expectedCount ? .pass : .fail,
            prdReference: "mermaid-fadein-capture",
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
