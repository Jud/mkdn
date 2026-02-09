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

    // MARK: - Code Block Structural Tests

    /// Verifies that code blocks render as a contained rectangular region
    /// with rounded corners, not just text-line-level `.backgroundColor`.
    ///
    /// The current NSAttributedString rendering path sets `.backgroundColor`
    /// on individual text runs, which produces a background that follows
    /// text line fragments rather than forming a cohesive rectangular block.
    /// The CodeBlockView SwiftUI view (currently unused in the NSTextView
    /// path) has proper rounded rectangle + border styling.
    ///
    /// This test checks that the code block background forms a full-width
    /// rectangular region whose left and right edges extend uniformly to
    /// the same x-positions across all lines.
    @Test("test_visualCompliance_codeBlockStructuralContainer")
    func codeBlockStructuralContainer() async throws {
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
            "Must find code block region for structural test"
        )

        // Check that the code block background spans the full width of the
        // region on multiple scan lines. If it's only text-line backgrounds,
        // the background will start/stop at different x-positions per line
        // (because text lines have varying lengths).
        let scale = analyzer.scaleFactor
        let scanYPositions = stride(
            from: region.minY + 5,
            to: region.maxY - 5,
            by: 8
        )

        var leftEdges: [CGFloat] = []
        var rightEdges: [CGFloat] = []

        for scanY in scanYPositions {
            // Scan from the left edge of the capture to find where code bg starts
            var leftEdge: CGFloat?
            for px in stride(from: Int(region.minX * scale) - 20, through: Int(region.maxX * scale) + 20, by: 1) {
                let ptX = CGFloat(px) / scale
                let color = analyzer.sampleColor(at: CGPoint(x: ptX, y: scanY))
                if ColorExtractor.matches(color, expected: renderedBg, tolerance: 20) {
                    continue
                }
                // Check if this is code background (not just text foreground)
                if ColorExtractor.matches(color, expected: expected, tolerance: 20) {
                    leftEdge = ptX
                    break
                }
                break // Hit text or other content before finding code bg
            }

            // Scan from the right
            var rightEdge: CGFloat?
            for px in stride(from: Int(region.maxX * scale) + 20, through: Int(region.minX * scale) - 20, by: -1) {
                let ptX = CGFloat(px) / scale
                let color = analyzer.sampleColor(at: CGPoint(x: ptX, y: scanY))
                if ColorExtractor.matches(color, expected: renderedBg, tolerance: 20) {
                    continue
                }
                if ColorExtractor.matches(color, expected: expected, tolerance: 20) {
                    rightEdge = ptX
                    break
                }
                break
            }

            if let left = leftEdge { leftEdges.append(left) }
            if let right = rightEdge { rightEdges.append(right) }
        }

        // A proper contained block should have uniform left and right edges.
        // Text-line backgrounds will vary because each line of code has
        // different length, so the background stops at different x positions.
        let hasEnoughSamples = leftEdges.count >= 3 && rightEdges.count >= 3

        var rightEdgeConsistent = false
        if hasEnoughSamples, let maxRight = rightEdges.max(), let minRight = rightEdges.min() {
            // If right edges are within 4pt of each other, it's a container.
            // Text-line backgrounds will vary by 50+ points.
            rightEdgeConsistent = (maxRight - minRight) < 4
        }

        let isStructuralContainer = hasEnoughSamples && rightEdgeConsistent
        #expect(
            isStructuralContainer,
            """
            Code block must render as a structural container with uniform edges. \
            Right edge variance: \(rightEdges.max().map { $0 - (rightEdges.min() ?? 0) } ?? -1)pt. \
            Expected < 4pt for a proper container block. \
            Current NSAttributedString .backgroundColor follows text line fragments, \
            not a cohesive rectangular block (CodeBlockView dead code: NFR-5).
            """
        )

        JSONResultReporter.record(TestResult(
            name: "visual: codeBlock structural container",
            status: isStructuralContainer ? .pass : .fail,
            prdReference: "syntax-highlighting NFR-5",
            expected: "uniform rectangular container with rounded corners",
            actual: isStructuralContainer
                ? "container detected"
                :
                "text-line-level background (right edge variance: \(rightEdges.max().map { $0 - (rightEdges.min() ?? 0) } ?? -1)pt)",
            imagePaths: [],
            duration: 0,
            message: isStructuralContainer
                ? nil
                :
                "Code blocks use NSAttributedString .backgroundColor (text-line-level) instead of a contained rectangular block. CodeBlockView with rounded corners/border is dead code since NSTextView migration."
        ))
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
