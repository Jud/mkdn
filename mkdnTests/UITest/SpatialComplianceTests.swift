import CoreGraphics
import Foundation
import Testing

@testable import mkdnLib

/// Spatial compliance tests verifying that mkdn's rendered output matches
/// the spatial-design-language PRD specifications.
///
/// **PRD**: spatial-design-language
/// **Dependencies**: T2 (harness server), T3 (harness client),
///   T4 (test fixtures), T5 (image analysis)
///
/// Each test references its PRD functional requirement. Expected values
/// are from the spatial-design-language PRD; they will migrate to
/// `SpacingConstants` references when that file is implemented.
///
/// Calibration must pass before compliance tests run. All tests share
/// a single app instance via `SpatialHarness` for efficiency.
@Suite("SpatialCompliance", .serialized)
struct SpatialComplianceTests {
    nonisolated(unsafe) static var calibrationPassed = false
    nonisolated(unsafe) static var calibrationAttempted = false
    nonisolated(unsafe) static var cachedCapture: CaptureResult?
    nonisolated(unsafe) static var cachedThemeColors: ThemeColorsResult?

    // MARK: - Lazy Calibration

    /// Runs the calibration sequence once. Subsequent calls are no-ops.
    /// Swift Testing does not guarantee test ordering even with
    /// `.serialized`, so every test triggers this lazily via
    /// `prepareAnalysis()` rather than depending on execution order.
    static func ensureCalibrated() async throws {
        guard !calibrationAttempted else { return }
        calibrationAttempted = true

        let client = try await SpatialHarness.ensureRunning()
        _ = try await client.setTheme("solarizedDark")

        let loadResp = try await client.loadFile(
            path: spatialFixturePath("geometry-calibration.md")
        )
        guard loadResp.status == "ok" else { return }

        try await Task.sleep(for: .milliseconds(500))

        let colorsResp = try await client.getThemeColors()
        let themeColors = try extractThemeColors(from: colorsResp)

        let captureResp = try await client.captureWindow()
        let capture = try extractCapture(from: captureResp)
        let analyzer = try loadAnalyzer(from: capture)

        guard analyzer.pointWidth > 0, analyzer.pointHeight > 0 else {
            return
        }

        cachedCapture = capture
        cachedThemeColors = themeColors

        let bgColor = backgroundColor(from: themeColors)
        let bounds = spatialContentBounds(
            in: analyzer,
            background: bgColor,
            tolerance: spatialBgColorTolerance
        )
        guard bounds != .zero, bounds.minX > 0, bounds.minY > 0 else {
            return
        }

        guard bounds.height > 100 else { return }

        calibrationPassed = true
    }

    // MARK: - Calibration Test

    @Test("calibration_measurementInfrastructure")
    func calibrationMeasurementInfrastructure() async throws {
        try await Self.ensureCalibrated()

        let capture = try #require(Self.cachedCapture, "Calibration must produce a cached capture")
        _ = try #require(Self.cachedThemeColors, "Calibration must produce cached theme colors")
        let analyzer = try loadAnalyzer(from: capture)
        #expect(analyzer.pointWidth > 0, "Captured image must have non-zero width")
        #expect(analyzer.pointHeight > 0, "Captured image must have non-zero height")

        let sampledBg = sampleRenderedBackground(from: analyzer)

        let bounds = spatialContentBounds(
            in: analyzer,
            background: sampledBg,
            tolerance: spatialBgColorTolerance
        )
        let gaps = measureVerticalGaps(
            in: analyzer,
            atX: max(bounds.midX, 50),
            bgColor: sampledBg,
            tolerance: spatialBgColorTolerance
        )

        #expect(bounds != .zero, "Content bounds must be detectable. path=\(capture.imagePath)")
        #expect(bounds.minX > 0, "Left margin must be positive. bounds=\(bounds)")
        #expect(bounds.minY > 0, "Top margin must be positive. bounds=\(bounds)")
        #expect(
            gaps.count >= 2,
            "Calibration fixture must produce >= 2 gaps, found \(gaps.count). bounds=\(bounds)"
        )
        #expect(Self.calibrationPassed, "Calibration must pass all checks")
    }

    // MARK: - FR-2: Document Layout

    @Test("test_spatialDesignLanguage_FR2_documentMarginLeft")
    func documentMarginLeft() async throws {
        let (analyzer, _, _) = try await prepareAnalysis()
        let sampledBg = sampleRenderedBackground(from: analyzer)

        let bounds = spatialContentBounds(
            in: analyzer,
            background: sampledBg,
            tolerance: spatialBgColorTolerance
        )

        assertSpatial(
            measured: bounds.minX,
            expected: SpatialPRD.documentMargin,
            prdRef: "spatial-design-language FR-2",
            aspect: "documentMargin left"
        )
    }

    @Test("test_spatialDesignLanguage_FR2_documentMarginRight")
    func documentMarginRight() async throws {
        let (analyzer, _, _) = try await prepareAnalysis()
        let sampledBg = sampleRenderedBackground(from: analyzer)

        let bounds = spatialContentBounds(
            in: analyzer,
            background: sampledBg,
            tolerance: spatialBgColorTolerance
        )
        // The right margin cannot be measured from content bounds because
        // bounds.maxX reflects the widest text line, not the text container
        // edge. For a symmetric layout, the right margin equals the left.
        // Verify that the right margin is at least as wide as the left.
        let rightMargin = analyzer.pointWidth - bounds.maxX
        let passed = rightMargin >= SpatialPRD.documentMargin - spatialTolerance

        #expect(
            passed,
            """
            spatial-design-language FR-2: documentMargin right \
            expected >= \(SpatialPRD.documentMargin)pt, \
            measured \(rightMargin)pt
            """
        )

        JSONResultReporter.record(TestResult(
            name: "spatial-design-language FR-2: documentMargin right",
            status: passed ? .pass : .fail,
            prdReference: "spatial-design-language FR-2",
            expected: ">= \(SpatialPRD.documentMargin)pt",
            actual: "\(rightMargin)pt",
            imagePaths: [],
            duration: 0,
            message: passed
                ? nil
                : "documentMargin right expected >= \(SpatialPRD.documentMargin)pt, measured \(rightMargin)pt"
        ))
    }

    @Test("test_spatialDesignLanguage_FR2_blockSpacing")
    func blockSpacing() async throws {
        let (analyzer, _, _) = try await prepareAnalysis()

        let sampledBg = sampleRenderedBackground(from: analyzer)
        let bounds = spatialContentBounds(
            in: analyzer,
            background: sampledBg,
            tolerance: spatialBgColorTolerance
        )
        let gaps = measureVerticalGaps(
            in: analyzer,
            atX: bounds.midX,
            bgColor: sampledBg,
            tolerance: spatialBgColorTolerance
        )

        // The fixture has two consecutive plain paragraphs (gap[1] and
        // gap[2]); take the minimum to measure pure block spacing.
        let blockGaps = gaps.filter { $0 > 4 && $0 < 80 }
        let measured = try #require(
            blockGaps.min(),
            "Must find at least one block-spacing gap. gaps=\(gaps)"
        )

        assertSpatial(
            measured: measured,
            expected: SpatialPRD.blockSpacing,
            prdRef: "spatial-design-language FR-2",
            aspect: "blockSpacing"
        )
    }

    @Test("test_spatialDesignLanguage_FR2_contentMaxWidth")
    func contentMaxWidth() async throws {
        let (analyzer, _, _) = try await prepareAnalysis()
        let sampledBg = sampleRenderedBackground(from: analyzer)

        let bounds = spatialContentBounds(
            in: analyzer,
            background: sampledBg,
            tolerance: spatialBgColorTolerance
        )

        let passed = bounds.width
            <= SpatialPRD.contentMaxWidth + spatialTolerance

        #expect(
            passed,
            """
            spatial-design-language FR-2: contentMaxWidth \
            expected <= \(SpatialPRD.contentMaxWidth)pt, \
            measured \(bounds.width)pt
            """
        )

        JSONResultReporter.record(TestResult(
            name: "spatial-design-language FR-2: contentMaxWidth",
            status: passed ? .pass : .fail,
            prdReference: "spatial-design-language FR-2",
            expected: "<= \(SpatialPRD.contentMaxWidth)pt",
            actual: "\(bounds.width)pt",
            imagePaths: [],
            duration: 0,
            message: passed
                ? nil
                :
                "spatial-design-language FR-2: contentMaxWidth expected <= \(SpatialPRD.contentMaxWidth)pt, measured \(bounds.width)pt"
        ))
    }

    // MARK: - FR-6: Window Chrome Spacing

    @Test("test_spatialDesignLanguage_FR6_windowTopInset")
    func windowTopInset() async throws {
        let (analyzer, _, _) = try await prepareAnalysis()
        let sampledBg = sampleRenderedBackground(from: analyzer)

        let bounds = spatialContentBounds(
            in: analyzer,
            background: sampledBg,
            tolerance: spatialBgColorTolerance
        )

        assertSpatial(
            measured: bounds.minY,
            expected: SpatialPRD.windowTopInset,
            prdRef: "spatial-design-language FR-6",
            aspect: "windowTopInset"
        )
    }

    @Test("test_spatialDesignLanguage_FR6_windowSideInset")
    func windowSideInset() async throws {
        let (analyzer, _, _) = try await prepareAnalysis()
        let sampledBg = sampleRenderedBackground(from: analyzer)

        let bounds = spatialContentBounds(
            in: analyzer,
            background: sampledBg,
            tolerance: spatialBgColorTolerance
        )

        assertSpatial(
            measured: bounds.minX,
            expected: SpatialPRD.windowSideInset,
            prdRef: "spatial-design-language FR-6",
            aspect: "windowSideInset"
        )
    }

    @Test("test_spatialDesignLanguage_FR6_windowBottomInset")
    func windowBottomInset() async throws {
        // The bottom inset is only meaningful when the document extends
        // past the viewport (scrolling to bottom positions the last content
        // at textContainerInset from the window bottom). For short documents,
        // the bottom inset equals the remaining viewport space.
        //
        // With the geometry-calibration fixture (~380pt content in a 752pt
        // viewport), scrolling to bottom has no effect. Instead, verify the
        // bottom inset is at least the expected value (content doesn't
        // overflow into the inset area).
        let (analyzer, _, _) = try await prepareAnalysis()
        let sampledBg = sampleRenderedBackground(from: analyzer)

        let bounds = spatialContentBounds(
            in: analyzer,
            background: sampledBg,
            tolerance: spatialBgColorTolerance
        )
        let bottomInset = analyzer.pointHeight - bounds.maxY
        let passed = bottomInset >= SpatialPRD.windowBottomInset - spatialTolerance

        #expect(
            passed,
            """
            spatial-design-language FR-6: windowBottomInset \
            expected >= \(SpatialPRD.windowBottomInset)pt, \
            measured \(bottomInset)pt
            """
        )

        JSONResultReporter.record(TestResult(
            name: "spatial-design-language FR-6: windowBottomInset",
            status: passed ? .pass : .fail,
            prdReference: "spatial-design-language FR-6",
            expected: ">= \(SpatialPRD.windowBottomInset)pt",
            actual: "\(bottomInset)pt",
            imagePaths: [],
            duration: 0,
            message: passed ? nil : "windowBottomInset too small"
        ))
    }

    // MARK: - FR-5: Structural Rules

    @Test("test_spatialDesignLanguage_FR5_gridAlignment")
    func gridAlignment() async throws {
        let (analyzer, _, _) = try await prepareAnalysis()
        let sampledBg = sampleRenderedBackground(from: analyzer)

        let bounds = spatialContentBounds(
            in: analyzer,
            background: sampledBg,
            tolerance: spatialBgColorTolerance
        )
        let grid = SpatialPRD.gridUnit
        // Exclude windowBottomInset: not reliably measurable with short
        // fixtures (bottom inset = remaining viewport, not layout inset).
        let values: [(String, CGFloat)] = [
            ("windowTopInset", bounds.minY),
            ("windowSideInset", bounds.minX),
        ]

        var allPassed = true

        for (name, value) in values {
            let rounded = (value / grid).rounded() * grid

            let passed = abs(value - rounded) <= spatialTolerance

            #expect(
                passed,
                """
                spatial-design-language FR-5: \(name) \
                (\(value)pt) must align to \(grid)pt grid; \
                nearest grid value is \(rounded)pt
                """
            )
            if !passed { allPassed = false }
        }

        JSONResultReporter.record(TestResult(
            name: "spatial-design-language FR-5: gridAlignment",
            status: allPassed ? .pass : .fail,
            prdReference: "spatial-design-language FR-5",
            expected: "\(grid)pt grid alignment",
            actual: allPassed ? "all aligned" : "misaligned",
            imagePaths: [],
            duration: 0,
            message: allPassed
                ? nil
                : "spatial-design-language FR-5: one or more values not aligned to \(grid)pt grid"
        ))
    }

    // MARK: - Cleanup

    @Test("zzz_cleanup")
    func cleanup() async {
        await SpatialHarness.shutdown()
    }

    // MARK: - Private Helpers

    /// Samples the actual rendered background color from a safe position
    /// in the captured image, compensating for color profile differences
    /// between theme-reported sRGB values and captured pixel values
    /// (~14 unit difference on macOS due to Display P3 vs sRGB).
    func sampleRenderedBackground(from analyzer: ImageAnalyzer) -> PixelColor {
        analyzer.sampleColor(
            at: CGPoint(
                x: analyzer.pointWidth / 2,
                y: spatialChromeInsetPt + 6
            )
        )
    }

    func prepareAnalysis() async throws -> (
        ImageAnalyzer,
        PixelColor,
        ThemeColorsResult
    ) {
        try await Self.ensureCalibrated()
        try #require(
            Self.calibrationPassed,
            "Calibration must pass before running compliance tests"
        )

        let capture = try #require(Self.cachedCapture)
        let themeColors = try #require(Self.cachedThemeColors)
        let analyzer = try loadAnalyzer(from: capture)
        let bgColor = backgroundColor(from: themeColors)

        return (analyzer, bgColor, themeColors)
    }

    func assertSpatial(
        measured: CGFloat,
        expected: CGFloat,
        prdRef: String,
        aspect: String
    ) {
        let passed = abs(measured - expected) <= spatialTolerance

        #expect(
            passed,
            """
            \(prdRef): \(aspect) \
            expected \(expected)pt, measured \(measured)pt \
            (tolerance: \(spatialTolerance)pt)
            """
        )

        let failureMessage =
            "\(prdRef): \(aspect) expected \(expected)pt, measured \(measured)pt (tolerance: \(spatialTolerance)pt)"

        JSONResultReporter.record(TestResult(
            name: "\(prdRef): \(aspect)",
            status: passed ? .pass : .fail,
            prdReference: prdRef,
            expected: "\(expected)pt",
            actual: "\(measured)pt",
            imagePaths: [],
            duration: 0,
            message: passed ? nil : failureMessage
        ))
    }
}
