import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import mkdnLib

/// Animation compliance tests verifying that mkdn's rendered animations
/// match the animation-design-language PRD specifications.
///
/// **PRD**: animation-design-language
/// **Dependencies**: T2 (harness server), T3 (harness client),
///   T4 (test fixtures), T5 (image analysis), T9 (frame capture)
///
/// Each test references its PRD functional requirement. Expected values
/// trace to `AnimationConstants` source-of-truth properties. Timing
/// measurements use curve-fitting across multiple frames per BR-004.
///
/// Calibration must pass before compliance tests run. All tests share
/// a single app instance via `AnimationHarness` for efficiency.
@Suite("AnimationCompliance", .serialized)
struct AnimationComplianceTests {
    nonisolated(unsafe) static var calibrationPassed = false

    // MARK: - Calibration

    @Test("calibration_frameCaptureInfrastructure")
    func calibrationFrameCapture() async throws {
        let client = try await AnimationHarness.ensureRunning()
        _ = try await client.setTheme("solarizedDark")

        let loadResp = try await client.loadFile(
            path: animationFixturePath("canonical.md")
        )
        #expect(loadResp.status == "ok", "File load must succeed")

        let infoResp = try await client.getWindowInfo()
        if let data = infoResp.data,
           case let .windowInfo(info) = data
        {
            AnimationHarness.cachedScaleFactor = CGFloat(
                info.scaleFactor
            )
        }

        let captureResp = try await client.startFrameCapture(
            fps: 30,
            duration: 1.0
        )
        let result = try extractFrameCapture(from: captureResp)

        #expect(result.frameCount > 0, "Must capture at least one frame")
        #expect(result.fps == 30, "FPS must match requested value")

        let frames = try loadFrameImages(from: result)
        #expect(!frames.isEmpty, "Must load captured frame images")

        Self.calibrationPassed = true
    }

    // MARK: - FR-1: Continuous Animations (Breathing Orb)

    /// animation-design-language FR-1: Breathing orb shows sinusoidal
    /// opacity/scale variation at approximately 12 cycles/min.
    ///
    /// Triggers a file change to make the file-change orb visible,
    /// locates the orb region, captures 5 seconds of frames at 30fps,
    /// and analyzes the brightness oscillation frequency.
    @Test("test_animationDesignLanguage_FR1_breathingOrbRhythm")
    func breathingOrbRhythm() async throws {
        try requireCalibration()
        let client = try await AnimationHarness.ensureRunning()
        _ = try await client.setTheme("solarizedDark")

        let orbRegion = try await triggerOrbAndLocate(client: client)

        let captureResp = try await client.startFrameCapture(
            fps: 30,
            duration: 5.0,
            timeout: .seconds(30)
        )
        let result = try extractFrameCapture(from: captureResp)
        let frames = try loadFrameImages(from: result)
        let scale = AnimationHarness.cachedScaleFactor

        let analyzer = FrameAnalyzer(
            frames: frames,
            fps: result.fps,
            scaleFactor: scale
        )
        let pulse = analyzer.measureOrbPulse(orbRegion: orbRegion)

        assertAnimationBool(
            value: !pulse.isStationary,
            expected: true,
            prdRef: "animation-design-language FR-1",
            aspect: "breathingOrb isAnimating"
        )

        let cpmTolerance = AnimationPRD.breatheCPM
            * cpmRelativeTolerance
        assertAnimationTiming(
            measured: pulse.cyclesPerMinute / 60.0,
            expected: AnimationPRD.breatheCPM / 60.0,
            tolerance: cpmTolerance / 60.0,
            prdRef: "animation-design-language FR-1",
            aspect: "breathingOrb cyclesPerMinute"
        )
    }

    // MARK: - FR-2: Spring Transitions

    /// animation-design-language FR-2: Spring-settle transition
    /// (mode overlay) shows response consistent with
    /// AnimationConstants.springSettle parameters.
    ///
    /// Triggers a mode switch to display the ModeTransitionOverlay,
    /// then captures frames to analyze the overlay's spring entrance.
    @Test("test_animationDesignLanguage_FR2_springSettleResponse")
    func springSettleResponse() async throws {
        try requireCalibration()
        let client = try await AnimationHarness.ensureRunning()
        _ = try await client.loadFile(
            path: animationFixturePath("canonical.md")
        )
        _ = try await client.switchMode("previewOnly")
        _ = try await client.switchMode("sideBySide")

        let captureResp = try await client.startFrameCapture(
            fps: 60,
            duration: 1.5
        )
        let result = try extractFrameCapture(from: captureResp)
        let frames = try loadFrameImages(from: result)

        let infoResp = try await client.getWindowInfo()
        let (winW, winH) = extractWindowSize(from: infoResp)

        let spring = analyzeSpringCurve(
            frames: frames,
            fps: result.fps,
            windowSize: (winW, winH)
        )
        assertSpringDamping(spring: spring)

        _ = try await client.switchMode("previewOnly")
    }

    // MARK: - FR-3: Fade Transitions (Crossfade)

    /// animation-design-language FR-3: Theme crossfade duration
    /// matches AnimationConstants.crossfade (0.35s).
    ///
    /// Switches themes and immediately captures frames to measure the
    /// background color transition duration.
    @Test("test_animationDesignLanguage_FR3_crossfadeDuration")
    func crossfadeDuration() async throws {
        try requireCalibration()
        let client = try await AnimationHarness.ensureRunning()
        _ = try await client.setTheme("solarizedDark")
        _ = try await client.loadFile(
            path: animationFixturePath("canonical.md")
        )

        let darkColorsResp = try await client.getThemeColors()
        let darkColors = try extractAnimThemeColors(
            from: darkColorsResp
        )
        let darkBg = PixelColor.from(rgbColor: darkColors.background)

        _ = try await client.setTheme("solarizedLight")

        let lightColorsResp = try await client.getThemeColors()
        let lightColors = try extractAnimThemeColors(
            from: lightColorsResp
        )
        let lightBg = PixelColor.from(rgbColor: lightColors.background)

        let captureResp = try await client.startFrameCapture(
            fps: 30,
            duration: 1.5
        )
        let result = try extractFrameCapture(from: captureResp)
        let frames = try loadFrameImages(from: result)
        let scale = AnimationHarness.cachedScaleFactor

        let sampleRegion = CGRect(x: 10, y: 10, width: 40, height: 40)
        let analyzer = FrameAnalyzer(
            frames: frames,
            fps: result.fps,
            scaleFactor: scale
        )
        let transition = analyzer.measureTransitionDuration(
            region: sampleRegion,
            startColor: darkBg,
            endColor: lightBg
        )

        let tolerance = animTolerance30fps * 3
        assertAnimationTiming(
            measured: transition.duration,
            expected: AnimationPRD.crossfadeDuration,
            tolerance: tolerance,
            prdRef: "animation-design-language FR-3",
            aspect: "crossfade duration"
        )

        _ = try await client.setTheme("solarizedDark")
    }

    // MARK: - FR-4: Orchestration (Stagger)

    /// animation-design-language FR-4: Content load stagger shows
    /// per-block delays matching AnimationConstants.staggerDelay (30ms).
    ///
    /// Loads a long document to trigger entrance stagger animation,
    /// then captures frames and measures when vertical content regions
    /// become visible.
    @Test("test_animationDesignLanguage_FR4_staggerDelays")
    func staggerDelays() async throws {
        try requireCalibration()
        let client = try await AnimationHarness.ensureRunning()
        _ = try await client.setTheme("solarizedDark")

        _ = try await client.loadFile(
            path: animationFixturePath("canonical.md")
        )
        let colorsResp = try await client.getThemeColors()
        let colors = try extractAnimThemeColors(from: colorsResp)
        let bgColor = PixelColor.from(rgbColor: colors.background)

        _ = try await client.loadFile(
            path: animationFixturePath("long-document.md")
        )

        let captureResp = try await client.startFrameCapture(
            fps: 60,
            duration: 2.0
        )
        let result = try extractFrameCapture(from: captureResp)
        let frames = try loadFrameImages(from: result)

        let delays = measureStaggerFromFrames(
            frames: frames,
            fps: result.fps,
            background: bgColor
        )
        assertStaggerOrder(delays: delays)
        assertStaggerCap(delays: delays)
    }

    /// animation-design-language FR-4: Verify that AnimationConstants
    /// numeric stagger values match the PRD specifications.
    @Test("test_animationDesignLanguage_FR4_staggerConstants")
    func staggerConstants() throws {
        try requireCalibration()

        let delayMatches = AnimationConstants.staggerDelay
            == AnimationPRD.staggerDelay
        let capMatches = AnimationConstants.staggerCap
            == AnimationPRD.staggerCap

        assertAnimationBool(
            value: delayMatches,
            expected: true,
            prdRef: "animation-design-language FR-4",
            aspect: "staggerDelay constant matches PRD (0.03s)"
        )
        assertAnimationBool(
            value: capMatches,
            expected: true,
            prdRef: "animation-design-language FR-4",
            aspect: "staggerCap constant matches PRD (0.5s)"
        )
    }

    // MARK: - Private Helpers

    func requireCalibration() throws {
        try #require(
            Self.calibrationPassed,
            "Calibration must pass before animation compliance tests"
        )
    }

    private func triggerOrbAndLocate(
        client: TestHarnessClient
    ) async throws -> CGRect {
        let tempPath = try createTempFixtureCopy(from: "canonical.md")
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        _ = try await client.loadFile(path: tempPath)

        let handle = try FileHandle(forWritingTo: URL(
            fileURLWithPath: tempPath
        ))
        handle.seekToEndOfFile()
        handle.write(Data("\n<!-- modified -->\n".utf8))
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
        return try #require(
            locateOrbRegion(
                in: analyzer,
                orbColor: orbCyan,
                tolerance: animOrbColorTolerance
            ),
            "File-change orb must be visible after file modification"
        )
    }

    private func measureStaggerFromFrames(
        frames: [CGImage],
        fps: Int,
        background: PixelColor
    ) -> [TimeInterval] {
        let scale = AnimationHarness.cachedScaleFactor
        let regions = staggerMeasurementRegions()
        let analyzer = FrameAnalyzer(
            frames: frames,
            fps: fps,
            scaleFactor: scale
        )
        return analyzer.measureStaggerDelays(
            regions: regions,
            revealColor: PixelColor(red: 128, green: 128, blue: 128),
            background: background,
            threshold: 15
        )
    }

    private func assertStaggerOrder(delays: [TimeInterval]) {
        let ordered = delays.enumerated().allSatisfy { idx, delay in
            idx == 0 || delay >= delays[idx - 1]
        }
        assertAnimationBool(
            value: ordered,
            expected: true,
            prdRef: "animation-design-language FR-4",
            aspect: "stagger blocks appear in order"
        )
    }

    private func assertStaggerCap(delays: [TimeInterval]) {
        guard delays.count >= 2,
              let maxDelay = delays.max()
        else { return }

        let capTolerance = AnimationPRD.staggerCap + 0.3
        let withinCap = maxDelay <= capTolerance

        #expect(
            withinCap,
            """
            animation-design-language FR-4: total stagger \
            expected <= \(AnimationPRD.staggerCap)s, \
            measured \(maxDelay)s
            """
        )

        JSONResultReporter.record(TestResult(
            name: "animation-design-language FR-4: stagger total",
            status: withinCap ? .pass : .fail,
            prdReference: "animation-design-language FR-4",
            expected: "<= \(AnimationPRD.staggerCap)s",
            actual: "\(maxDelay)s",
            imagePaths: [],
            duration: 0,
            message: withinCap ? nil : "Stagger exceeds cap",
        ))
    }

    private func analyzeSpringCurve(
        frames: [CGImage],
        fps: Int,
        windowSize: (CGFloat, CGFloat)
    ) -> SpringAnalysis {
        let scale = AnimationHarness.cachedScaleFactor
        let overlayRegion = CGRect(
            x: windowSize.0 / 2 - 60,
            y: windowSize.1 / 2 - 20,
            width: 120,
            height: 40
        )
        let analyzer = FrameAnalyzer(
            frames: frames,
            fps: fps,
            scaleFactor: scale
        )
        return analyzer.measureSpringCurve(
            region: overlayRegion,
            property: .opacity
        )
    }

    private func assertSpringDamping(spring: SpringAnalysis) {
        let dampingTolerance = 0.3
        let dampingPassed = abs(
            spring.dampingFraction - AnimationPRD.springDamping
        ) <= dampingTolerance

        #expect(
            dampingPassed,
            """
            animation-design-language FR-2: springSettle damping \
            expected ~\(AnimationPRD.springDamping), \
            measured \(spring.dampingFraction)
            """
        )

        JSONResultReporter.record(TestResult(
            name: "animation-design-language FR-2: springSettle",
            status: dampingPassed ? .pass : .fail,
            prdReference: "animation-design-language FR-2",
            expected: "damping ~\(AnimationPRD.springDamping)",
            actual: "damping \(spring.dampingFraction)",
            imagePaths: [],
            duration: 0,
            message: dampingPassed
                ? nil
                : "Spring damping mismatch",
        ))
    }

    private func staggerMeasurementRegions() -> [CGRect] {
        let contentX: CGFloat = 50
        let regionW: CGFloat = 200
        let regionH: CGFloat = 20
        let startY: CGFloat = 60
        let spacing: CGFloat = 80

        return (0 ..< 5).map { idx in
            CGRect(
                x: contentX,
                y: startY + CGFloat(idx) * spacing,
                width: regionW,
                height: regionH,
            )
        }
    }
}

// MARK: - Theme Colors Helper

func extractAnimThemeColors(
    from response: HarnessResponse
) throws -> ThemeColorsResult {
    guard response.status == "ok",
          let data = response.data,
          case let .themeColors(result) = data
    else {
        throw HarnessError.unexpectedResponse(
            "No theme colors in response"
        )
    }
    return result
}

// MARK: - Window Info Helper

func extractWindowSize(
    from response: HarnessResponse
) -> (CGFloat, CGFloat) {
    if let data = response.data,
       case let .windowInfo(info) = data
    {
        return (CGFloat(info.width), CGFloat(info.height))
    }
    return (800, 600)
}
