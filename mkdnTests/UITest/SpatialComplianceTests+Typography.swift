import CoreGraphics
import Foundation
import Testing

@testable import mkdnLib

/// Typography spacing and component padding compliance tests.
///
/// Extension of `SpatialComplianceTests` covering heading spacing
/// (FR-3) and component padding (FR-4) measurements from the
/// spatial-design-language PRD.
extension SpatialComplianceTests {
    // MARK: - FR-3: Typography Spacing

    @Test("test_spatialDesignLanguage_FR3_h1SpaceAbove")
    func h1SpaceAbove() async throws {
        try requireCalibration()
        let (analyzer, bgColor, _) = try await prepareAnalysis()

        let bounds = analyzer.contentBounds(
            background: bgColor,
            tolerance: spatialColorTolerance
        )

        // The H1 heading is the first content element in the calibration
        // fixture. Its "space above" is the distance from the window top
        // edge to the first rendered content, which should equal the
        // window top inset when the heading is the document's first block.
        assertSpatial(
            measured: bounds.minY,
            expected: SpatialPRD.windowTopInset,
            prdRef: "spatial-design-language FR-3",
            aspect: "headingSpaceAbove(H1) as top inset to first content"
        )
    }

    @Test("test_spatialDesignLanguage_FR3_h1SpaceBelow")
    func h1SpaceBelow() async throws {
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
        let measured = try #require(
            gaps.first,
            "Must find gap below H1 heading"
        )

        assertSpatial(
            measured: measured,
            expected: SpatialPRD.h1SpaceBelow,
            prdRef: "spatial-design-language FR-3",
            aspect: "headingSpaceBelow(H1)"
        )
    }

    @Test("test_spatialDesignLanguage_FR3_h2SpaceAbove")
    func h2SpaceAbove() async throws {
        try requireCalibration()
        let (analyzer, bgColor, _) = try await prepareAnalysis()
        let gapIndex = resolveGapIndex(
            analyzer: analyzer,
            bgColor: bgColor,
            index: 4,
            label: "H2 space above"
        )

        assertSpatial(
            measured: gapIndex,
            expected: SpatialPRD.h2SpaceAbove,
            prdRef: "spatial-design-language FR-3",
            aspect: "headingSpaceAbove(H2)"
        )
    }

    @Test("test_spatialDesignLanguage_FR3_h2SpaceBelow")
    func h2SpaceBelow() async throws {
        try requireCalibration()
        let (analyzer, bgColor, _) = try await prepareAnalysis()
        let gapIndex = resolveGapIndex(
            analyzer: analyzer,
            bgColor: bgColor,
            index: 5,
            label: "H2 space below"
        )

        assertSpatial(
            measured: gapIndex,
            expected: SpatialPRD.h2SpaceBelow,
            prdRef: "spatial-design-language FR-3",
            aspect: "headingSpaceBelow(H2)"
        )
    }

    @Test("test_spatialDesignLanguage_FR3_h3SpaceAbove")
    func h3SpaceAbove() async throws {
        try requireCalibration()
        let (analyzer, bgColor, _) = try await prepareAnalysis()
        let gapIndex = resolveGapIndex(
            analyzer: analyzer,
            bgColor: bgColor,
            index: 7,
            label: "H3 space above"
        )

        assertSpatial(
            measured: gapIndex,
            expected: SpatialPRD.h3SpaceAbove,
            prdRef: "spatial-design-language FR-3",
            aspect: "headingSpaceAbove(H3)"
        )
    }

    @Test("test_spatialDesignLanguage_FR3_h3SpaceBelow")
    func h3SpaceBelow() async throws {
        try requireCalibration()
        let (analyzer, bgColor, _) = try await prepareAnalysis()
        let gapIndex = resolveGapIndex(
            analyzer: analyzer,
            bgColor: bgColor,
            index: 8,
            label: "H3 space below"
        )

        assertSpatial(
            measured: gapIndex,
            expected: SpatialPRD.h3SpaceBelow,
            prdRef: "spatial-design-language FR-3",
            aspect: "headingSpaceBelow(H3)"
        )
    }

    // MARK: - FR-4: Component Spacing

    @Test("test_spatialDesignLanguage_FR4_codeBlockPadding")
    func codeBlockPadding() async throws {
        try requireCalibration()
        let (analyzer, _, themeColors) = try await prepareAnalysis()

        let codeBg = codeBackgroundColor(from: themeColors)
        let codeRegion = analyzer.findRegion(
            matching: codeBg,
            tolerance: spatialColorTolerance
        )
        let region = try #require(
            codeRegion,
            "Must find code block background region"
        )

        // Scan inward from the code background boundary to find where
        // actual code text begins. The distance is the internal padding.
        let leftBoundary = analyzer.findColorBoundary(
            from: CGPoint(x: region.minX + 1, y: region.midY),
            direction: .right,
            sourceColor: codeBg,
            tolerance: spatialColorTolerance
        )
        guard let textStart = leftBoundary else {
            Issue.record("Cannot find code text within code block region")
            return
        }

        let measured = textStart.x - region.minX

        assertSpatial(
            measured: measured,
            expected: SpatialPRD.componentPadding,
            prdRef: "spatial-design-language FR-4",
            aspect: "componentPadding (code block)"
        )
    }

    // MARK: - Private

    private func resolveGapIndex(
        analyzer: ImageAnalyzer,
        bgColor: PixelColor,
        index: Int,
        label: String
    ) -> CGFloat {
        let bounds = analyzer.contentBounds(
            background: bgColor,
            tolerance: spatialColorTolerance
        )
        let gaps = measureVerticalGaps(
            in: analyzer,
            atX: bounds.midX,
            bgColor: bgColor
        )
        guard gaps.count > index else {
            Issue.record(
                "Insufficient gaps (\(gaps.count)) to measure \(label)"
            )
            return 0
        }
        return gaps[index]
    }
}
