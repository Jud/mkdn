import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import mkdnLib

/// Fade duration compliance tests for the animation design language.
///
/// Extension of `AnimationComplianceTests` covering FR-3 fadeIn and
/// fadeOut duration verification. Crossfade duration is covered in the
/// main struct.
extension AnimationComplianceTests {
    // MARK: - FR-3: Fade Transitions (FadeIn)

    /// animation-design-language FR-3: fadeIn duration matches
    /// AnimationConstants.fadeIn (0.5s easeOut).
    ///
    /// Loads a minimal file first so the target region is background,
    /// then loads a content-rich file to trigger block entrance fadeIn.
    /// Captures frames and measures the content region's opacity
    /// transition duration. Uses the last captured frame as the
    /// settled end-state reference.
    @Test("test_animationDesignLanguage_FR3_fadeInDuration")
    func fadeInDuration() async throws {
        try requireCalibration()
        let client = try await AnimationHarness.ensureRunning()
        _ = try await client.setTheme("solarizedDark")

        let colorsResp = try await client.getThemeColors()
        let colors = try extractAnimThemeColors(from: colorsResp)
        let bgColor = PixelColor.from(rgbColor: colors.background)

        _ = try await client.loadFile(
            path: animationFixturePath("geometry-calibration.md")
        )
        try await Task.sleep(for: .seconds(0.5))

        _ = try await client.loadFile(
            path: animationFixturePath("canonical.md")
        )

        let captureResp = try await client.startFrameCapture(
            fps: 30, duration: 2.0
        )
        let result = try extractFrameCapture(from: captureResp)
        let frames = try loadFrameImages(from: result)
        let scale = AnimationHarness.cachedScaleFactor

        let contentRegion = CGRect(
            x: 50, y: 200, width: 200, height: 20
        )
        let endColor = fadeSettledColor(
            frames: frames, region: contentRegion, scale: scale
        )

        let analyzer = FrameAnalyzer(
            frames: frames,
            fps: result.fps,
            scaleFactor: scale,
        )
        let transition = analyzer.measureTransitionDuration(
            region: contentRegion,
            startColor: bgColor,
            endColor: endColor,
        )

        let tolerance = animTolerance30fps * 3
        assertAnimationTiming(
            measured: transition.duration,
            expected: AnimationPRD.fadeInDuration,
            tolerance: tolerance,
            prdRef: "animation-design-language FR-3",
            aspect: "fadeIn duration"
        )
    }

    // MARK: - FR-3: Fade Transitions (FadeOut)

    /// animation-design-language FR-3: fadeOut duration matches
    /// AnimationConstants.fadeOut (0.4s easeIn).
    ///
    /// Loads a content-rich file and waits for render. Captures the
    /// settled content color in a lower region. Then loads a minimal
    /// file to trigger block exit fadeOut animation. Measures the
    /// content region transitioning from visible content back to
    /// background.
    @Test("test_animationDesignLanguage_FR3_fadeOutDuration")
    func fadeOutDuration() async throws {
        try requireCalibration()
        let client = try await AnimationHarness.ensureRunning()
        _ = try await client.setTheme("solarizedDark")

        let colorsResp = try await client.getThemeColors()
        let colors = try extractAnimThemeColors(from: colorsResp)
        let bgColor = PixelColor.from(rgbColor: colors.background)

        _ = try await client.loadFile(
            path: animationFixturePath("canonical.md")
        )
        try await Task.sleep(for: .seconds(1.0))

        let contentRegion = CGRect(
            x: 50, y: 300, width: 200, height: 20
        )
        let captureResp = try await client.captureWindow()
        let capture = try extractCapture(from: captureResp)
        let imgAnalyzer = try loadAnalyzer(from: capture)
        let startColor = imgAnalyzer.averageColor(
            in: contentRegion
        )

        _ = try await client.loadFile(
            path: animationFixturePath("geometry-calibration.md")
        )

        let frameResp = try await client.startFrameCapture(
            fps: 30, duration: 2.0
        )
        let frameResult = try extractFrameCapture(from: frameResp)
        let frames = try loadFrameImages(from: frameResult)
        let scale = AnimationHarness.cachedScaleFactor

        let analyzer = FrameAnalyzer(
            frames: frames,
            fps: frameResult.fps,
            scaleFactor: scale,
        )
        let transition = analyzer.measureTransitionDuration(
            region: contentRegion,
            startColor: startColor,
            endColor: bgColor,
        )

        let tolerance = animTolerance30fps * 3
        assertAnimationTiming(
            measured: transition.duration,
            expected: AnimationPRD.fadeOutDuration,
            tolerance: tolerance,
            prdRef: "animation-design-language FR-3",
            aspect: "fadeOut duration"
        )
    }

    // MARK: - Fade Duration Helpers

    /// Extracts the settled end-state color from the last captured
    /// frame in a region. Used as the endColor reference for fadeIn
    /// measurement, since text content creates a mixed color that
    /// cannot be predicted from theme colors alone.
    private func fadeSettledColor(
        frames: [CGImage],
        region: CGRect,
        scale: CGFloat
    ) -> PixelColor {
        guard let lastFrame = frames.last else {
            return PixelColor(
                red: 128, green: 128, blue: 128, alpha: 255
            )
        }
        let analyzer = ImageAnalyzer(
            image: lastFrame, scaleFactor: scale
        )
        return analyzer.averageColor(in: region)
    }
}
