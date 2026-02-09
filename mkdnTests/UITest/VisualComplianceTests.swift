import CoreGraphics
import Foundation
import Testing

@testable import mkdnLib

/// Visual compliance tests verifying that mkdn's rendered output matches
/// the theme color specifications for both Solarized themes.
///
/// **PRD**: automated-ui-testing REQ-004 (Visual Compliance Verification)
/// **Dependencies**: T2 (harness server), T3 (harness client),
///   T4 (test fixtures), T5 (image analysis)
///
/// Each test references its PRD acceptance criterion. Expected values
/// come from `ThemeColors` (via the harness `getThemeColors` command)
/// and `VisualPRD` (hard-coded accent palette values matching
/// `SyntaxColors`).
///
/// Calibration runs lazily on first access via `ensureCalibrated()`.
/// All tests share a single app instance via `VisualHarness`.
@Suite("VisualCompliance", .serialized)
struct VisualComplianceTests {
    nonisolated(unsafe) static var calibrationPassed = false
    nonisolated(unsafe) static var calibrationAttempted = false
    nonisolated(unsafe) static var darkCapture: CaptureResult?
    nonisolated(unsafe) static var darkColors: ThemeColorsResult?
    nonisolated(unsafe) static var darkRenderedBg: PixelColor?
    nonisolated(unsafe) static var lightCapture: CaptureResult?
    nonisolated(unsafe) static var lightColors: ThemeColorsResult?
    nonisolated(unsafe) static var lightRenderedBg: PixelColor?

    // MARK: - Lazy Calibration

    /// Runs the calibration sequence once. Subsequent calls are no-ops.
    /// Swift Testing does not guarantee test ordering even with
    /// `.serialized`, so every test triggers this lazily via
    /// `prepareDark()` / `prepareLight()` rather than depending on
    /// execution order.
    static func ensureCalibrated() async throws {
        guard !calibrationAttempted else { return }
        calibrationAttempted = true

        let client = try await VisualHarness.ensureRunning()
        _ = try await client.setTheme("solarizedDark")

        let loadResp = try await client.loadFile(
            path: visualFixturePath("canonical.md")
        )
        guard loadResp.status == "ok" else { return }

        // Wait for the entrance animation to complete.
        // EntranceAnimator places opaque cover layers over each layout
        // fragment and fades them out. Total duration is staggerCap
        // (0.5s) + fadeInDuration (0.5s) + cleanup (0.1s) = 1.1s.
        // Wait 1.5s to ensure all cover layers are fully removed.
        try await Task.sleep(for: .milliseconds(1_500))

        let colorsResp = try await client.getThemeColors()
        let themeColors = try VisualCapture.extractColors(
            from: colorsResp
        )
        let bgColor = PixelColor.from(rgbColor: themeColors.background)

        let captureResp = try await client.captureWindow()
        let capture = try VisualCapture.extractResult(
            from: captureResp
        )
        let analyzer = try VisualCapture.loadImage(from: capture)

        guard analyzer.pointWidth > 0, analyzer.pointHeight > 0 else {
            return
        }

        let renderedBg = visualSampleBackground(from: analyzer)

        guard ColorExtractor.matches(
            renderedBg,
            expected: bgColor,
            tolerance: backgroundProfileTolerance
        )
        else {
            return
        }

        darkCapture = capture
        darkColors = themeColors
        darkRenderedBg = renderedBg
        calibrationPassed = true
    }

    // MARK: - Calibration Test

    @Test("calibration_colorMeasurementInfrastructure")
    func calibrationColorMeasurement() async throws {
        try await Self.ensureCalibrated()

        let capture = try #require(
            Self.darkCapture,
            "Calibration must produce a cached capture"
        )
        let colors = try #require(
            Self.darkColors,
            "Calibration must produce cached theme colors"
        )
        let renderedBg = try #require(
            Self.darkRenderedBg,
            "Calibration must sample rendered background"
        )

        let analyzer = try VisualCapture.loadImage(from: capture)
        #expect(
            analyzer.pointWidth > 0 && analyzer.pointHeight > 0,
            "Captured image must have non-zero dimensions"
        )

        let bgColor = PixelColor.from(rgbColor: colors.background)

        #expect(
            ColorExtractor.matches(
                renderedBg,
                expected: bgColor,
                tolerance: backgroundProfileTolerance
            ),
            """
            Color calibration: background at top-center \
            expected \(bgColor), sampled \(renderedBg) \
            (tolerance: \(backgroundProfileTolerance))
            """
        )

        #expect(Self.calibrationPassed, "Calibration must pass all checks")
    }

    // MARK: - AC-004a: Background Color

    /// automated-ui-testing AC-004a: Background color matches
    /// ThemeColors.background for Solarized Dark.
    @Test("test_visualCompliance_AC004a_backgroundSolarizedDark")
    func backgroundDark() async throws {
        let (analyzer, colors, _) = try await prepareDark()
        let expected = PixelColor.from(rgbColor: colors.background)
        let samplePoint = CGPoint(
            x: analyzer.pointWidth / 2,
            y: 10
        )
        let sampled = analyzer.sampleColor(at: samplePoint)
        assertVisualColor(
            sampled: sampled,
            expected: expected,
            tolerance: backgroundProfileTolerance,
            prdRef: "automated-ui-testing AC-004a",
            aspect: "background Solarized Dark"
        )
    }

    /// automated-ui-testing AC-004a: Background color matches
    /// ThemeColors.background for Solarized Light.
    @Test("test_visualCompliance_AC004a_backgroundSolarizedLight")
    func backgroundLight() async throws {
        let (analyzer, colors, _) = try await prepareLight()
        let expected = PixelColor.from(rgbColor: colors.background)
        let samplePoint = CGPoint(
            x: analyzer.pointWidth / 2,
            y: 10
        )
        let sampled = analyzer.sampleColor(at: samplePoint)
        assertVisualColor(
            sampled: sampled,
            expected: expected,
            tolerance: backgroundProfileTolerance,
            prdRef: "automated-ui-testing AC-004a",
            aspect: "background Solarized Light"
        )
    }

    // MARK: - AC-004b: Heading Text Color

    /// automated-ui-testing AC-004b: Heading text color matches
    /// ThemeColors.headingColor for Solarized Dark.
    @Test("test_visualCompliance_AC004b_headingColorSolarizedDark")
    func headingColorDark() async throws {
        let (analyzer, colors, renderedBg) = try await prepareDark()
        let expected = PixelColor.from(rgbColor: colors.headingColor)
        let sampled = try #require(
            visualFindHeadingColor(
                analyzer: analyzer,
                renderedBg: renderedBg
            ),
            "Must find heading text in first content region"
        )
        assertVisualColor(
            sampled: sampled,
            expected: expected,
            tolerance: visualTextTolerance,
            prdRef: "automated-ui-testing AC-004b",
            aspect: "headingColor Solarized Dark"
        )
    }

    /// automated-ui-testing AC-004b: Heading text color matches
    /// ThemeColors.headingColor for Solarized Light.
    @Test("test_visualCompliance_AC004b_headingColorSolarizedLight")
    func headingColorLight() async throws {
        let (analyzer, colors, renderedBg) = try await prepareLight()
        let expected = PixelColor.from(rgbColor: colors.headingColor)
        let sampled = try #require(
            visualFindHeadingColor(
                analyzer: analyzer,
                renderedBg: renderedBg
            ),
            "Must find heading text in first content region"
        )
        assertVisualColor(
            sampled: sampled,
            expected: expected,
            tolerance: visualTextTolerance,
            prdRef: "automated-ui-testing AC-004b",
            aspect: "headingColor Solarized Light"
        )
    }

    // MARK: - AC-004c: Body Text Color

    /// automated-ui-testing AC-004c: Body text color matches
    /// ThemeColors.foreground for Solarized Dark.
    @Test("test_visualCompliance_AC004c_bodyColorSolarizedDark")
    func bodyColorDark() async throws {
        let (analyzer, colors, renderedBg) = try await prepareDark()
        let expected = PixelColor.from(rgbColor: colors.foreground)
        let sampled = try #require(
            visualFindBodyTextColor(
                analyzer: analyzer,
                renderedBg: renderedBg,
                colors: colors
            ),
            "Must find body text in paragraph region"
        )
        assertVisualColor(
            sampled: sampled,
            expected: expected,
            tolerance: visualTextTolerance,
            prdRef: "automated-ui-testing AC-004c",
            aspect: "bodyColor Solarized Dark"
        )
    }

    /// automated-ui-testing AC-004c: Body text color matches
    /// ThemeColors.foreground for Solarized Light.
    @Test("test_visualCompliance_AC004c_bodyColorSolarizedLight")
    func bodyColorLight() async throws {
        let (analyzer, colors, renderedBg) = try await prepareLight()
        let expected = PixelColor.from(rgbColor: colors.foreground)
        let sampled = try #require(
            visualFindBodyTextColor(
                analyzer: analyzer,
                renderedBg: renderedBg,
                colors: colors
            ),
            "Must find body text in paragraph region"
        )
        assertVisualColor(
            sampled: sampled,
            expected: expected,
            tolerance: visualTextTolerance,
            prdRef: "automated-ui-testing AC-004c",
            aspect: "bodyColor Solarized Light"
        )
    }

    // MARK: - AC-004a: Code Block Background

    /// automated-ui-testing AC-004a: Code block background matches
    /// ThemeColors.codeBackground for Solarized Dark.
    @Test("test_visualCompliance_AC004a_codeBackgroundSolarizedDark")
    func codeBackgroundDark() async throws {
        let (analyzer, colors, renderedBg) = try await prepareDark()
        let expected = PixelColor.from(rgbColor: colors.codeBackground)
        let srgbBg = PixelColor.from(rgbColor: colors.background)
        let region = try #require(
            findCodeBlockRegion(
                in: analyzer,
                codeBg: expected,
                srgbBg: srgbBg,
                renderedBg: renderedBg
            ),
            "Must find code block background region"
        )
        let sampled = sampleCodeBackground(
            analyzer: analyzer, region: region, renderedBg: renderedBg
        )
        assertVisualColor(
            sampled: sampled,
            expected: expected,
            tolerance: backgroundProfileTolerance,
            prdRef: "automated-ui-testing AC-004a",
            aspect: "codeBackground Solarized Dark"
        )
    }

    /// automated-ui-testing AC-004a: Code block background matches
    /// ThemeColors.codeBackground for Solarized Light.
    @Test("test_visualCompliance_AC004a_codeBackgroundSolarizedLight")
    func codeBackgroundLight() async throws {
        let (analyzer, colors, renderedBg) = try await prepareLight()
        let expected = PixelColor.from(rgbColor: colors.codeBackground)
        let srgbBg = PixelColor.from(rgbColor: colors.background)
        let region = try #require(
            findCodeBlockRegion(
                in: analyzer,
                codeBg: expected,
                srgbBg: srgbBg,
                renderedBg: renderedBg
            ),
            "Must find code block background region"
        )
        let sampled = sampleCodeBackground(
            analyzer: analyzer, region: region, renderedBg: renderedBg
        )
        assertVisualColor(
            sampled: sampled,
            expected: expected,
            tolerance: backgroundProfileTolerance,
            prdRef: "automated-ui-testing AC-004a",
            aspect: "codeBackground Solarized Light"
        )
    }

    // MARK: - Cleanup

    @Test("zzz_cleanup")
    func cleanup() async {
        await VisualHarness.shutdown()
    }

    // MARK: - Private Helpers

    func prepareDark() async throws -> (
        ImageAnalyzer, ThemeColorsResult, PixelColor
    ) {
        try await Self.ensureCalibrated()
        try #require(
            Self.calibrationPassed,
            "Calibration must pass before running compliance tests"
        )

        let capture = try #require(Self.darkCapture)
        let colors = try #require(Self.darkColors)
        let renderedBg = try #require(Self.darkRenderedBg)
        return try (
            VisualCapture.loadImage(from: capture),
            colors,
            renderedBg
        )
    }

    func prepareLight() async throws -> (
        ImageAnalyzer, ThemeColorsResult, PixelColor
    ) {
        try await Self.ensureCalibrated()
        try #require(
            Self.calibrationPassed,
            "Calibration must pass before running compliance tests"
        )

        if let capture = Self.lightCapture,
           let colors = Self.lightColors,
           let renderedBg = Self.lightRenderedBg
        {
            return try (
                VisualCapture.loadImage(from: capture),
                colors,
                renderedBg
            )
        }

        let client = try await VisualHarness.ensureRunning()
        _ = try await client.setTheme("solarizedLight")

        try await Task.sleep(for: .milliseconds(300))

        let colorsResp = try await client.getThemeColors()
        let colors = try VisualCapture.extractColors(
            from: colorsResp
        )

        let captureResp = try await client.captureWindow()
        let capture = try VisualCapture.extractResult(
            from: captureResp
        )

        let analyzer = try VisualCapture.loadImage(from: capture)
        let renderedBg = visualSampleBackground(from: analyzer)

        Self.lightCapture = capture
        Self.lightColors = colors
        Self.lightRenderedBg = renderedBg

        return (analyzer, colors, renderedBg)
    }

    /// Samples the code block background color from the right side of
    /// the code block region where code text has ended and only the
    /// NSAttributedString `.backgroundColor` (code bg) remains.
    ///
    /// Samples at 80% of the content width within the vertical middle
    /// of the code block, averaging a small area to reduce noise.
    private func sampleCodeBackground(
        analyzer: ImageAnalyzer,
        region: CGRect,
        renderedBg: PixelColor
    ) -> PixelColor {
        let bounds = analyzer.contentBounds(
            background: renderedBg,
            tolerance: visualColorTolerance
        )
        let sampleX = bounds.minX + bounds.width * 0.8
        let sampleY = region.midY
        let sampleRect = CGRect(
            x: sampleX - 5,
            y: sampleY - 5,
            width: 10,
            height: 10
        )
        return analyzer.averageColor(in: sampleRect)
    }
}
