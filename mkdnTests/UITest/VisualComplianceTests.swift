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
/// Calibration must pass before compliance tests run. All tests share
/// a single app instance via `VisualHarness` for efficiency.
@Suite("VisualCompliance", .serialized)
struct VisualComplianceTests {
    nonisolated(unsafe) static var calibrationPassed = false
    nonisolated(unsafe) static var darkCapture: CaptureResult?
    nonisolated(unsafe) static var darkColors: ThemeColorsResult?
    nonisolated(unsafe) static var lightCapture: CaptureResult?
    nonisolated(unsafe) static var lightColors: ThemeColorsResult?

    // MARK: - Calibration

    @Test("calibration_colorMeasurementInfrastructure")
    func calibrationColorMeasurement() async throws {
        let client = try await VisualHarness.ensureRunning()
        _ = try await client.setTheme("solarizedDark")

        let loadResp = try await client.loadFile(
            path: visualFixturePath("canonical.md")
        )
        #expect(loadResp.status == "ok", "File load must succeed")

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

        #expect(
            analyzer.pointWidth > 0 && analyzer.pointHeight > 0,
            "Captured image must have non-zero dimensions"
        )

        let samplePoint = CGPoint(
            x: analyzer.pointWidth / 2,
            y: 10
        )
        let sampled = analyzer.sampleColor(at: samplePoint)
        #expect(
            ColorExtractor.matches(
                sampled,
                expected: bgColor,
                tolerance: visualColorTolerance
            ),
            """
            Color calibration: background at top-center \
            expected \(bgColor), sampled \(sampled)
            """
        )

        Self.darkCapture = capture
        Self.darkColors = themeColors
        Self.calibrationPassed = true
    }

    // MARK: - AC-004a: Background Color

    /// automated-ui-testing AC-004a: Background color matches
    /// ThemeColors.background for Solarized Dark.
    @Test("test_visualCompliance_AC004a_backgroundSolarizedDark")
    func backgroundDark() throws {
        try requireCalibration()
        let (analyzer, colors) = try prepareDark()
        let expected = PixelColor.from(rgbColor: colors.background)
        let samplePoint = CGPoint(
            x: analyzer.pointWidth / 2,
            y: 10
        )
        let sampled = analyzer.sampleColor(at: samplePoint)
        assertVisualColor(
            sampled: sampled,
            expected: expected,
            tolerance: visualColorTolerance,
            prdRef: "automated-ui-testing AC-004a",
            aspect: "background Solarized Dark"
        )
    }

    /// automated-ui-testing AC-004a: Background color matches
    /// ThemeColors.background for Solarized Light.
    @Test("test_visualCompliance_AC004a_backgroundSolarizedLight")
    func backgroundLight() async throws {
        try requireCalibration()
        let (analyzer, colors) = try await prepareLight()
        let expected = PixelColor.from(rgbColor: colors.background)
        let samplePoint = CGPoint(
            x: analyzer.pointWidth / 2,
            y: 10
        )
        let sampled = analyzer.sampleColor(at: samplePoint)
        assertVisualColor(
            sampled: sampled,
            expected: expected,
            tolerance: visualColorTolerance,
            prdRef: "automated-ui-testing AC-004a",
            aspect: "background Solarized Light"
        )
    }

    // MARK: - AC-004b: Heading Text Color

    /// automated-ui-testing AC-004b: Heading text color matches
    /// ThemeColors.headingColor for Solarized Dark.
    @Test("test_visualCompliance_AC004b_headingColorSolarizedDark")
    func headingColorDark() throws {
        try requireCalibration()
        let (analyzer, colors) = try prepareDark()
        let expected = PixelColor.from(rgbColor: colors.headingColor)
        let sampled = try #require(
            findHeadingColor(
                analyzer: analyzer,
                colors: colors
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
        try requireCalibration()
        let (analyzer, colors) = try await prepareLight()
        let expected = PixelColor.from(rgbColor: colors.headingColor)
        let sampled = try #require(
            findHeadingColor(
                analyzer: analyzer,
                colors: colors
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
    func bodyColorDark() throws {
        try requireCalibration()
        let (analyzer, colors) = try prepareDark()
        let expected = PixelColor.from(rgbColor: colors.foreground)
        let sampled = try #require(
            findBodyTextColor(
                analyzer: analyzer,
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
        try requireCalibration()
        let (analyzer, colors) = try await prepareLight()
        let expected = PixelColor.from(rgbColor: colors.foreground)
        let sampled = try #require(
            findBodyTextColor(
                analyzer: analyzer,
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
    func codeBackgroundDark() throws {
        try requireCalibration()
        let (analyzer, colors) = try prepareDark()
        let expected = PixelColor.from(rgbColor: colors.codeBackground)
        let region = try #require(
            analyzer.findRegion(
                matching: expected,
                tolerance: visualColorTolerance
            ),
            "Must find code block background region"
        )
        let sampled = analyzer.averageColor(in: region)
        assertVisualColor(
            sampled: sampled,
            expected: expected,
            tolerance: visualColorTolerance,
            prdRef: "automated-ui-testing AC-004a",
            aspect: "codeBackground Solarized Dark"
        )
    }

    /// automated-ui-testing AC-004a: Code block background matches
    /// ThemeColors.codeBackground for Solarized Light.
    @Test("test_visualCompliance_AC004a_codeBackgroundSolarizedLight")
    func codeBackgroundLight() async throws {
        try requireCalibration()
        let (analyzer, colors) = try await prepareLight()
        let expected = PixelColor.from(rgbColor: colors.codeBackground)
        let region = try #require(
            analyzer.findRegion(
                matching: expected,
                tolerance: visualColorTolerance
            ),
            "Must find code block background region"
        )
        let sampled = analyzer.averageColor(in: region)
        assertVisualColor(
            sampled: sampled,
            expected: expected,
            tolerance: visualColorTolerance,
            prdRef: "automated-ui-testing AC-004a",
            aspect: "codeBackground Solarized Light"
        )
    }

    // MARK: - Private Helpers

    func requireCalibration() throws {
        try #require(
            Self.calibrationPassed,
            "Calibration must pass before compliance tests"
        )
    }

    func prepareDark() throws -> (ImageAnalyzer, ThemeColorsResult) {
        let capture = try #require(Self.darkCapture)
        let colors = try #require(Self.darkColors)
        return try (VisualCapture.loadImage(from: capture), colors)
    }

    func prepareLight() async throws -> (
        ImageAnalyzer, ThemeColorsResult
    ) {
        if let capture = Self.lightCapture,
           let colors = Self.lightColors
        {
            return try (
                VisualCapture.loadImage(from: capture), colors
            )
        }

        let client = try await VisualHarness.ensureRunning()
        _ = try await client.setTheme("solarizedLight")

        let colorsResp = try await client.getThemeColors()
        let colors = try VisualCapture.extractColors(
            from: colorsResp
        )

        let captureResp = try await client.captureWindow()
        let capture = try VisualCapture.extractResult(
            from: captureResp
        )

        Self.lightCapture = capture
        Self.lightColors = colors

        return try (
            VisualCapture.loadImage(from: capture), colors
        )
    }

    private func findHeadingColor(
        analyzer: ImageAnalyzer,
        colors: ThemeColorsResult
    ) -> PixelColor? {
        let bgColor = PixelColor.from(rgbColor: colors.background)
        let bounds = analyzer.contentBounds(
            background: bgColor,
            tolerance: visualColorTolerance
        )
        let regions = findContentRegions(
            in: analyzer,
            atX: bounds.midX,
            bgColor: bgColor,
            tolerance: visualColorTolerance
        )
        guard let heading = regions.first else { return nil }
        return findDominantTextColor(
            in: analyzer,
            region: CGRect(
                x: bounds.minX,
                y: heading.minY,
                width: bounds.width,
                height: heading.maxY - heading.minY
            ),
            background: bgColor,
            bgTolerance: visualColorTolerance
        )
    }

    private func findBodyTextColor(
        analyzer: ImageAnalyzer,
        colors: ThemeColorsResult
    ) -> PixelColor? {
        let bgColor = PixelColor.from(rgbColor: colors.background)
        let codeBg = PixelColor.from(rgbColor: colors.codeBackground)
        let bounds = analyzer.contentBounds(
            background: bgColor,
            tolerance: visualColorTolerance
        )
        let regions = findContentRegions(
            in: analyzer,
            atX: bounds.midX,
            bgColor: bgColor,
            tolerance: visualColorTolerance
        )
        guard regions.count > 6 else { return nil }
        for idx in 6 ..< regions.count {
            let region = regions[idx]
            let centerPt = CGPoint(
                x: bounds.midX,
                y: (region.minY + region.maxY) / 2
            )
            let centerColor = analyzer.sampleColor(at: centerPt)
            if ColorExtractor.matches(
                centerColor,
                expected: codeBg,
                tolerance: visualColorTolerance
            ) { continue }
            let rect = CGRect(
                x: bounds.minX,
                y: region.minY,
                width: bounds.width,
                height: region.maxY - region.minY
            )
            if let textColor = findDominantTextColor(
                in: analyzer,
                region: rect,
                background: bgColor,
                bgTolerance: visualColorTolerance
            ) { return textColor }
        }
        return nil
    }
}
