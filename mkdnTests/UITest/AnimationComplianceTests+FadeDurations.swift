import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import mkdnLib

/// Fade duration compliance tests for the animation design language.
///
/// Extension of `AnimationComplianceTests` covering FR-3 fadeIn and
/// fadeOut verification. Crossfade is covered in the main struct.
///
/// **Architecture constraint**: SCStream startup latency (~200-400ms)
/// overlaps with fade durations (fadeIn 0.5s, fadeOut 0.4s). Frame
/// captures may miss the beginning of transitions. Tests verify that
/// content state changes occur and that AnimationConstants values
/// match PRD specifications, rather than measuring exact durations.
///
/// **Region strategy**: Multi-region sampling for fadeIn; lower
/// content region (y:450) for fadeOut where `canonical.md` renders
/// content but `geometry-calibration.md` (short) shows background.
extension AnimationComplianceTests {
    // MARK: - FR-3: Fade Transitions (FadeIn)

    /// animation-design-language FR-3: fadeIn entrance animation
    /// occurs when loading content.
    @Test("test_animationDesignLanguage_FR3_fadeInDuration")
    func fadeInDuration() async throws {
        try await requireCalibration()
        let client = try await AnimationHarness.ensureRunning()
        _ = try await client.setTheme("solarizedDark")
        _ = try await client.switchMode("previewOnly")

        _ = try await client.loadFile(
            path: animationFixturePath("geometry-calibration.md")
        )
        try await Task.sleep(for: .seconds(0.5))
        let beforeCapture = try await captureAndExtract(client: client)
        let beforeAnalyzer = try loadAnalyzer(from: beforeCapture)

        _ = try await client.loadFile(
            path: animationFixturePath("canonical.md")
        )
        try await Task.sleep(for: .seconds(1.0))
        let afterCapture = try await captureAndExtract(client: client)
        let afterAnalyzer = try loadAnalyzer(from: afterCapture)

        let avgDiff = multiRegionDifference(
            before: beforeAnalyzer, after: afterAnalyzer
        )
        let contentChanged = avgDiff > 3
        let constantMatch = AnimationPRD.fadeInDuration == 0.5
        let passed = contentChanged && constantMatch

        #expect(contentChanged, """
        animation-design-language FR-3: fadeIn avgDiff=\(avgDiff)
        """)
        #expect(constantMatch, """
        animation-design-language FR-3: fadeIn must be 0.5s
        """)
        recordFadeResult(
            name: "fadeIn",
            passed: passed,
            detail: "avgDiff=\(avgDiff)",
            images: [beforeCapture.imagePath, afterCapture.imagePath]
        )
    }

    // MARK: - FR-3: Fade Transitions (FadeOut)

    /// animation-design-language FR-3: fadeOut exit animation occurs
    /// when content is replaced.
    @Test("test_animationDesignLanguage_FR3_fadeOutDuration")
    func fadeOutDuration() async throws {
        try await requireCalibration()
        let client = try await AnimationHarness.ensureRunning()
        _ = try await client.setTheme("solarizedDark")

        let colorsResp = try await client.getThemeColors()
        let colors = try extractAnimThemeColors(from: colorsResp)
        let bgColor = PixelColor.from(rgbColor: colors.background)

        _ = try await client.loadFile(
            path: animationFixturePath("canonical.md")
        )
        try await Task.sleep(for: .seconds(1.0))

        let lowerRegion = CGRect(
            x: 50, y: 450, width: 200, height: 30
        )
        let beforeCapture = try await captureAndExtract(client: client)
        let beforeAnalyzer = try loadAnalyzer(from: beforeCapture)
        let contentColor = beforeAnalyzer.averageColor(
            in: lowerRegion
        )
        let contentDist = contentColor.distance(to: bgColor)
        let hasContent = contentDist > 10

        _ = try await client.loadFile(
            path: animationFixturePath("geometry-calibration.md")
        )
        try await Task.sleep(for: .seconds(1.0))

        let afterCapture = try await captureAndExtract(client: client)
        let afterAnalyzer = try loadAnalyzer(from: afterCapture)
        let afterColor = afterAnalyzer.averageColor(in: lowerRegion)
        let afterDist = afterColor.distance(to: bgColor)

        let contentCleared = afterDist < contentDist - 5
            || afterDist < 35
        let constantMatch = AnimationPRD.fadeOutDuration == 0.4
        let passed = hasContent && contentCleared && constantMatch

        #expect(hasContent, """
        animation-design-language FR-3: \
        fadeOut needs content (dist=\(contentDist))
        """)
        #expect(contentCleared, """
        animation-design-language FR-3: \
        fadeOut must clear (dist=\(afterDist))
        """)
        recordFadeResult(
            name: "fadeOut",
            passed: passed,
            detail: "before=\(contentDist), after=\(afterDist)",
            images: [beforeCapture.imagePath, afterCapture.imagePath]
        )
    }

    // MARK: - Fade Helpers

    private func captureAndExtract(
        client: TestHarnessClient
    ) async throws -> CaptureResult {
        let resp = try await client.captureWindow()
        return try extractCapture(from: resp)
    }

    private func multiRegionDifference(
        before: ImageAnalyzer, after: ImageAnalyzer
    ) -> Int {
        let regions = [
            CGRect(x: 30, y: 60, width: 300, height: 30),
            CGRect(x: 30, y: 150, width: 300, height: 30),
            CGRect(x: 30, y: 240, width: 300, height: 30),
            CGRect(x: 30, y: 330, width: 300, height: 30),
        ]
        var total = 0
        for region in regions {
            let bc = before.averageColor(in: region)
            let ac = after.averageColor(in: region)
            total += bc.distance(to: ac)
        }
        return total / regions.count
    }

    private func recordFadeResult(
        name: String,
        passed: Bool,
        detail: String,
        images: [String]
    ) {
        JSONResultReporter.record(TestResult(
            name: "animation-design-language FR-3: \(name)",
            status: passed ? .pass : .fail,
            prdReference: "animation-design-language FR-3",
            expected: "\(name) constant matches PRD",
            actual: detail,
            imagePaths: images,
            duration: 0,
            message: passed ? nil : "\(name) verification failed",
        ))
    }
}
