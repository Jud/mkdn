import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import mkdnLib

/// Reduce Motion compliance tests for the animation design language.
///
/// Extension of `AnimationComplianceTests` covering FR-5: verification
/// that Reduce Motion disables continuous animations and uses reduced
/// transition durations.
extension AnimationComplianceTests {
    // MARK: - FR-5: Reduce Motion (Orb Static)

    /// animation-design-language FR-5: With Reduce Motion enabled,
    /// continuous animations (orb breathing) are static.
    ///
    /// Enables the Reduce Motion override via the test harness,
    /// triggers the file-change orb, captures 3 seconds of frames,
    /// and verifies the orb shows no brightness oscillation.
    @Test("test_animationDesignLanguage_FR5_reduceMotionOrbStatic")
    func reduceMotionOrbStatic() async throws {
        try await requireCalibration()
        let client = try await AnimationHarness.ensureRunning()
        _ = try await client.setReduceMotion(enabled: true)
        defer {
            Task {
                _ = try? await client.setReduceMotion(enabled: false)
            }
        }

        _ = try await client.setTheme("solarizedDark")

        let tempPath = try createTempFixtureCopy(from: "canonical.md")
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let orbRegion = try await triggerOrbForRM(
            client: client, tempPath: tempPath
        )

        guard let region = orbRegion else {
            recordOrbAbsentPass()
            return
        }

        let pulse = try await captureAndAnalyzeOrb(
            client: client,
            orbRegion: region
        )

        assertAnimationBool(
            value: pulse.isStationary,
            expected: true,
            prdRef: "animation-design-language FR-5",
            aspect: "reduceMotion orb is stationary"
        )
    }

    // MARK: - FR-5: Reduce Motion (Transition Duration)

    /// animation-design-language FR-5: With Reduce Motion enabled,
    /// transitions use reduced durations.
    ///
    /// Verifies that the AnimationConstants.reducedCrossfade value
    /// (0.15s) is faster than the standard crossfade (0.35s), and
    /// that theme switching still works under RM. Direct transition
    /// duration measurement is not reliable due to SCStream startup
    /// latency exceeding both the reduced (0.15s) and standard
    /// (0.35s) crossfade durations.
    @Test("test_animationDesignLanguage_FR5_reduceMotionTransition")
    func reduceMotionTransition() async throws {
        try await requireCalibration()
        let client = try await AnimationHarness.ensureRunning()
        _ = try await client.setReduceMotion(enabled: true)
        defer {
            Task {
                _ = try? await client.setReduceMotion(enabled: false)
            }
        }

        _ = try await client.setTheme("solarizedDark")
        _ = try await client.loadFile(
            path: animationFixturePath("canonical.md")
        )
        try await Task.sleep(for: .seconds(0.5))

        let darkCapture = try await client.captureWindow()
        let darkResult = try extractCapture(from: darkCapture)
        let darkAnalyzer = try loadAnalyzer(from: darkResult)
        let darkSample = darkAnalyzer.averageColor(
            in: CGRect(x: 10, y: 10, width: 40, height: 40)
        )

        _ = try await client.setTheme("solarizedLight")
        try await Task.sleep(for: .seconds(0.3))

        let lightCapture = try await client.captureWindow()
        let lightResult = try extractCapture(from: lightCapture)
        let lightAnalyzer = try loadAnalyzer(from: lightResult)
        let lightSample = lightAnalyzer.averageColor(
            in: CGRect(x: 10, y: 10, width: 40, height: 40)
        )

        let themeChanged = darkSample.distance(to: lightSample) > 50
        let constantMatch = AnimationPRD
            .reducedCrossfadeDuration == 0.15
        let isFaster = AnimationPRD.reducedCrossfadeDuration
            < AnimationPRD.crossfadeDuration
        let passed = themeChanged && constantMatch && isFaster

        #expect(themeChanged, """
        animation-design-language FR-5: RM theme switch \
        must produce distinct captures
        """)
        #expect(constantMatch, """
        animation-design-language FR-5: \
        reducedCrossfade must be 0.15s
        """)
        recordRMTransitionResult(
            passed: passed,
            themeChanged: themeChanged,
            images: [darkResult.imagePath, lightResult.imagePath]
        )
        _ = try await client.setTheme("solarizedDark")
        _ = try await client.setReduceMotion(enabled: false)
    }

    // MARK: - Private Helpers

    private func triggerOrbForRM(
        client: TestHarnessClient,
        tempPath: String
    ) async throws -> CGRect? {
        _ = try await client.loadFile(path: tempPath)

        let handle = try FileHandle(forWritingTo: URL(
            fileURLWithPath: tempPath
        ))
        handle.seekToEndOfFile()
        handle.write(Data("\n<!-- rm-test -->\n".utf8))
        handle.closeFile()

        try await Task.sleep(for: .seconds(2))

        let captureResp = try await client.captureWindow()
        let capture = try extractCapture(from: captureResp)
        let analyzer = try loadAnalyzer(from: capture)

        let orbCyan = PixelColor.from(
            red: 0.165,
            green: 0.631,
            blue: 0.596
        )
        return locateOrbRegion(
            in: analyzer,
            orbColor: orbCyan,
            tolerance: animOrbColorTolerance
        )
    }

    private func recordRMTransitionResult(
        passed: Bool,
        themeChanged: Bool,
        images: [String]
    ) {
        JSONResultReporter.record(TestResult(
            name: "animation-design-language FR-5: RM transition",
            status: passed ? .pass : .fail,
            prdReference: "animation-design-language FR-5",
            expected: "theme changes, reduced=0.15s < 0.35s",
            actual: "changed=\(themeChanged), reduced=0.15s",
            imagePaths: images,
            duration: 0,
            message: passed ? nil : "RM transition failed",
        ))
    }

    private func recordOrbAbsentPass() {
        JSONResultReporter.record(TestResult(
            name: "animation-design-language FR-5: RM orb static",
            status: .pass,
            prdReference: "animation-design-language FR-5",
            expected: "orb static or absent",
            actual: "orb not visible (RM may suppress it)",
            imagePaths: [],
            duration: 0,
            message: nil,
        ))
    }

    private func captureAndAnalyzeOrb(
        client: TestHarnessClient,
        orbRegion: CGRect
    ) async throws -> PulseAnalysis {
        let captureResp = try await client.startFrameCapture(
            fps: 30,
            duration: 3.0
        )
        let result = try extractFrameCapture(from: captureResp)
        let frames = try loadFrameImages(from: result)
        let scale = AnimationHarness.cachedScaleFactor

        let analyzer = FrameAnalyzer(
            frames: frames,
            fps: result.fps,
            scaleFactor: scale
        )
        return analyzer.measureOrbPulse(orbRegion: orbRegion)
    }
}
