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
    nonisolated(unsafe) static var cachedCapture: CaptureResult?
    nonisolated(unsafe) static var cachedThemeColors: ThemeColorsResult?

    // MARK: - Calibration

    @Test("calibration_measurementInfrastructure")
    func calibrationMeasurementInfrastructure() async throws {
        let client = try await SpatialHarness.ensureRunning()
        try await client.setTheme("solarizedDark")

        let loadResp = try await client.loadFile(
            path: spatialFixturePath("geometry-calibration.md")
        )
        #expect(loadResp.status == "ok", "File load must succeed")

        let colorsResp = try await client.getThemeColors()
        let themeColors = try extractThemeColors(from: colorsResp)
        let bgColor = backgroundColor(from: themeColors)

        let captureResp = try await client.captureWindow()
        let capture = try extractCapture(from: captureResp)
        let analyzer = try loadAnalyzer(from: capture)

        #expect(
            analyzer.pointWidth > 0,
            "Captured image must have non-zero width"
        )
        #expect(
            analyzer.pointHeight > 0,
            "Captured image must have non-zero height"
        )

        let cornerColor = analyzer.sampleColor(
            at: CGPoint(x: 10, y: 10)
        )
        #expect(
            cornerColor.distance(to: bgColor) < 30,
            "Corner should approximate the theme background"
        )

        let bounds = analyzer.contentBounds(
            background: bgColor,
            tolerance: spatialColorTolerance
        )
        #expect(bounds != .zero, "Content bounds must be detectable")
        #expect(bounds.minX > 0, "Left margin must be positive")
        #expect(bounds.minY > 0, "Top margin must be positive")

        let gaps = measureVerticalGaps(
            in: analyzer,
            atX: bounds.midX,
            bgColor: bgColor
        )
        #expect(
            gaps.count >= 2,
            "Calibration fixture must produce at least 2 gaps, found \(gaps.count)"
        )

        Self.cachedCapture = capture
        Self.cachedThemeColors = themeColors
        Self.calibrationPassed = true
    }

    // MARK: - FR-2: Document Layout

    @Test("test_spatialDesignLanguage_FR2_documentMarginLeft")
    func documentMarginLeft() async throws {
        try requireCalibration()
        let (analyzer, bgColor, _) = try await prepareAnalysis()

        let bounds = analyzer.contentBounds(
            background: bgColor,
            tolerance: spatialColorTolerance
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
        try requireCalibration()
        let (analyzer, bgColor, _) = try await prepareAnalysis()

        let bounds = analyzer.contentBounds(
            background: bgColor,
            tolerance: spatialColorTolerance
        )
        let rightMargin = analyzer.pointWidth - bounds.maxX

        assertSpatial(
            measured: rightMargin,
            expected: SpatialPRD.documentMargin,
            prdRef: "spatial-design-language FR-2",
            aspect: "documentMargin right"
        )
    }

    @Test("test_spatialDesignLanguage_FR2_blockSpacing")
    func blockSpacing() async throws {
        try requireCalibration()
        let (analyzer, bgColor, _) = try await prepareAnalysis()

        let bounds = analyzer.contentBounds(
            background: bgColor,
            tolerance: spatialColorTolerance
        )
        let gaps = measureVerticalGaps(
            in: analyzer,
            atX: bounds.midX,
            bgColor: bgColor
        )

        let blockGaps = gaps.filter { $0 > 4 && $0 < 80 }
        let measured = try #require(
            blockGaps.min(),
            "Must find at least one block-spacing gap"
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
        try requireCalibration()
        let (analyzer, bgColor, _) = try await prepareAnalysis()

        let bounds = analyzer.contentBounds(
            background: bgColor,
            tolerance: spatialColorTolerance
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
        try requireCalibration()
        let (analyzer, bgColor, _) = try await prepareAnalysis()

        let bounds = analyzer.contentBounds(
            background: bgColor,
            tolerance: spatialColorTolerance
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
        try requireCalibration()
        let (analyzer, bgColor, _) = try await prepareAnalysis()

        let bounds = analyzer.contentBounds(
            background: bgColor,
            tolerance: spatialColorTolerance
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
        try requireCalibration()
        let (analyzer, bgColor, _) = try await prepareAnalysis()

        let bounds = analyzer.contentBounds(
            background: bgColor,
            tolerance: spatialColorTolerance
        )
        let bottomInset = analyzer.pointHeight - bounds.maxY

        assertSpatial(
            measured: bottomInset,
            expected: SpatialPRD.windowBottomInset,
            prdRef: "spatial-design-language FR-6",
            aspect: "windowBottomInset"
        )
    }

    // MARK: - FR-5: Structural Rules

    @Test("test_spatialDesignLanguage_FR5_gridAlignment")
    func gridAlignment() async throws {
        try requireCalibration()
        let (analyzer, bgColor, _) = try await prepareAnalysis()

        let bounds = analyzer.contentBounds(
            background: bgColor,
            tolerance: spatialColorTolerance
        )
        let grid = SpatialPRD.gridUnit
        let values: [(String, CGFloat)] = [
            ("windowTopInset", bounds.minY),
            ("windowSideInset", bounds.minX),
            ("windowBottomInset", analyzer.pointHeight - bounds.maxY),
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

    // MARK: - Private Helpers

    func requireCalibration() throws {
        try #require(
            Self.calibrationPassed,
            "Calibration must pass before running compliance tests"
        )
    }

    func prepareAnalysis() async throws -> (
        ImageAnalyzer,
        PixelColor,
        ThemeColorsResult
    ) {
        let client = try await SpatialHarness.ensureRunning()

        if Self.cachedCapture == nil {
            try await client.setTheme("solarizedDark")
            try await client.loadFile(
                path: spatialFixturePath("geometry-calibration.md")
            )
            let colorsResp = try await client.getThemeColors()
            Self.cachedThemeColors = try extractThemeColors(
                from: colorsResp
            )
            let captureResp = try await client.captureWindow()
            Self.cachedCapture = try extractCapture(from: captureResp)
        }

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
