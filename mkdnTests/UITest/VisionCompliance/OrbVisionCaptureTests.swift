import Foundation
import Testing

@testable import mkdnLib

/// Capture orchestrator for orb animation vision evaluation.
///
/// Produces frame sequences of the orb indicator's two key animation
/// behaviors: (1) the violet-to-orange color crossfade when a file
/// changes on disk, and (2) the breathing pulse cycle that follows.
///
/// The test loads the fixture file via the harness, then writes
/// additional content to the file on disk to trigger the FileWatcher's
/// DispatchSource. This sets `isFileOutdated = true`, which activates
/// the orb with a crossfade from violet (defaultHandler) to orange
/// (fileChanged). The frame capture records the transition.
///
/// Uses the capture-before-trigger pattern: beginFrameCapture starts
/// SCStream, then the file modification triggers the animation, and
/// after the configured duration endFrameCapture stops and returns
/// frame paths.
///
/// The capture matrix is: 2 scenarios (crossfade, breathing) x 2 themes = 4 sequences.
@Suite("OrbVisionCapture", .serialized)
struct OrbVisionCaptureTests {
    @Test("Capture orb crossfade and breathing across themes")
    func captureOrbAnimations() async throws {
        let client = try await OrbVisionHarness.ensureRunning()

        try await Task.sleep(for: .seconds(3))

        let outputDir = orbVisionOutputDir()
        let projectRoot = orbVisionProjectRoot().path

        try FileManager.default.createDirectory(
            atPath: outputDir,
            withIntermediateDirectories: true
        )

        var entries: [OrbFrameSequenceEntry] = []
        let scenarios = ["crossfade", "breathing"]

        for theme in OrbVisionConfig.themes {
            for scenario in scenarios {
                let entry = try await captureSequence(
                    fixture: OrbVisionConfig.fixtures[0],
                    theme: theme,
                    scenario: scenario,
                    client: client,
                    outputDir: outputDir,
                    projectRoot: projectRoot
                )
                entries.append(entry)
            }
        }

        try orbVisionWriteManifest(entries: entries, to: outputDir)

        validateCaptureResults(entries: entries)

        recordCaptureResult(entries: entries)
    }

    // MARK: - Capture Identity

    private struct CaptureIdentity {
        let captureId: String
        let fixture: String
        let theme: String
        let scenario: String
    }

    // MARK: - Per-Sequence Capture

    private func captureSequence(
        fixture: String,
        theme: String,
        scenario: String,
        client: TestHarnessClient,
        outputDir: String,
        projectRoot: String
    ) async throws -> OrbFrameSequenceEntry {
        let setResp = try await client.setTheme(theme)
        try #require(
            setResp.status == "ok",
            "setTheme(\(theme)) failed: \(setResp.message ?? "unknown")"
        )

        let identity = CaptureIdentity(
            captureId: orbVisionCaptureId(
                fixture: fixture,
                theme: theme,
                scenario: scenario
            ),
            fixture: fixture,
            theme: theme,
            scenario: scenario
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
            scenario: scenario,
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
        scenario: String,
        sequenceDir: String,
        client: TestHarnessClient
    ) async throws -> FrameCaptureResult {
        let fixturePath = orbVisionFixturePath(fixture)
        let workingCopy = try orbVisionCreateWorkingCopy(of: fixturePath)

        let loadResp = try await client.loadFile(path: workingCopy)
        try #require(
            loadResp.status == "ok",
            "loadFile(\(fixture)) failed: \(loadResp.message ?? "unknown")"
        )

        try await Task.sleep(for: .milliseconds(1_500))

        let beginResp = try await client.beginFrameCapture(
            fps: OrbVisionConfig.captureFPS,
            outputDir: sequenceDir
        )
        try #require(
            beginResp.status == "ok",
            "beginFrameCapture failed: \(beginResp.message ?? "unknown")"
        )

        try await Task.sleep(for: .milliseconds(300))

        try orbVisionTriggerFileChange(at: workingCopy)

        let captureDuration: TimeInterval = scenario == "crossfade"
            ? OrbVisionConfig.crossfadeDuration
            : OrbVisionConfig.autoReloadDuration

        try await Task.sleep(for: .seconds(captureDuration))

        let endResp = try await client.endFrameCapture()
        let result = try orbVisionExtractFrameCapture(from: endResp)

        try? FileManager.default.removeItem(
            atPath: URL(fileURLWithPath: workingCopy)
                .deletingLastPathComponent().path
        )

        return result
    }

    private func buildEntry(
        identity: CaptureIdentity,
        sequenceDir: String,
        result: FrameCaptureResult,
        projectRoot: String
    ) throws -> OrbFrameSequenceEntry {
        let relativeDir = String(
            sequenceDir.dropFirst(projectRoot.count + 1)
        )
        let frameHashes = try result.framePaths.map { path in
            try orbVisionImageHash(atPath: path)
        }
        let relativePaths = result.framePaths.map { path in
            String(path.dropFirst(projectRoot.count + 1))
        }

        return OrbFrameSequenceEntry(
            id: identity.captureId,
            fixture: identity.fixture,
            theme: identity.theme,
            scenario: identity.scenario,
            viewMode: OrbVisionConfig.viewMode,
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
        entries: [OrbFrameSequenceEntry]
    ) {
        let expectedCount = OrbVisionConfig.fixtures.count
            * OrbVisionConfig.themes.count
            * 2 // scenarios: crossfade + breathing
        #expect(
            entries.count == expectedCount,
            """
            Capture matrix must produce \(expectedCount) sequences \
            (\(OrbVisionConfig.fixtures.count) fixtures \
            x \(OrbVisionConfig.themes.count) themes \
            x 2 scenarios)
            """
        )

        let manifestURL = URL(
            fileURLWithPath: orbVisionOutputDir()
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
                entry.fps == OrbVisionConfig.captureFPS,
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
        entries: [OrbFrameSequenceEntry]
    ) {
        let expectedCount = OrbVisionConfig.fixtures.count
            * OrbVisionConfig.themes.count
            * 2
        let totalFrames = entries.reduce(0) { $0 + $1.frameCount }

        JSONResultReporter.record(TestResult(
            name: "orb-vision: capture orchestrator",
            status: entries.count == expectedCount ? .pass : .fail,
            prdReference: "orb-vision-capture",
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
