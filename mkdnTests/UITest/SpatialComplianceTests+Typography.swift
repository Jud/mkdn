import CoreGraphics
import Foundation
import Testing

@testable import mkdnLib

/// Typography spacing and component padding compliance tests.
///
/// Extension of `SpatialComplianceTests` covering heading spacing
/// (FR-3) and component padding (FR-4) measurements from the
/// spatial-design-language PRD.
///
/// The geometry-calibration.md fixture (without HRs) renders content
/// in this gap order:
///   gap[0]: H1 -> paragraph (h1SpaceBelow)
///   gap[1]: paragraph -> paragraph (blockSpacing)
///   gap[2]: paragraph -> paragraph (blockSpacing)
///   gap[3]: paragraph -> H2 (h2SpaceAbove)
///   gap[4]: H2 -> paragraph (h2SpaceBelow)
///   gap[5]: paragraph -> H3 (h3SpaceAbove)
///   gap[6]: H3 -> paragraph (h3SpaceBelow)
///   gap[7..]: code block / blockquote spacing
extension SpatialComplianceTests {
    // MARK: - FR-3: Typography Spacing

    @Test("test_spatialDesignLanguage_FR3_h1SpaceAbove")
    func h1SpaceAbove() async throws {
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
            prdRef: "spatial-design-language FR-3",
            aspect: "headingSpaceAbove(H1) as top inset to first content"
        )
    }

    @Test("test_spatialDesignLanguage_FR3_h1SpaceBelow")
    func h1SpaceBelow() async throws {
        let gaps = try await measureFixtureGaps()
        let measured = try #require(
            gaps.first,
            "Must find gap below H1 heading. gaps=\(gaps)"
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
        let gaps = try await measureFixtureGaps()
        let measured = try #require(
            gaps.count > 3 ? gaps[3] : nil,
            "Need gap[3] for h2SpaceAbove. gaps=\(gaps)"
        )

        assertSpatial(
            measured: measured,
            expected: SpatialPRD.h2SpaceAbove,
            prdRef: "spatial-design-language FR-3",
            aspect: "headingSpaceAbove(H2)"
        )
    }

    @Test("test_spatialDesignLanguage_FR3_h2SpaceBelow")
    func h2SpaceBelow() async throws {
        let gaps = try await measureFixtureGaps()
        let measured = try #require(
            gaps.count > 4 ? gaps[4] : nil,
            "Need gap[4] for h2SpaceBelow. gaps=\(gaps)"
        )

        assertSpatial(
            measured: measured,
            expected: SpatialPRD.h2SpaceBelow,
            prdRef: "spatial-design-language FR-3",
            aspect: "headingSpaceBelow(H2)"
        )
    }

    @Test("test_spatialDesignLanguage_FR3_h3SpaceAbove")
    func h3SpaceAbove() async throws {
        let gaps = try await measureFixtureGaps()
        guard gaps.count > 5 else {
            JSONResultReporter.record(TestResult(
                name: "spatial-design-language FR-3: headingSpaceAbove(H3)",
                status: .fail,
                prdReference: "spatial-design-language FR-3",
                expected: "\(SpatialPRD.h3SpaceAbove)pt",
                actual: "unmeasurable (only \(gaps.count) gaps found, need 6)",
                imagePaths: [],
                duration: 0,
                message: "Gap scanner finds only \(gaps.count) gaps; H3 gap requires fixture redesign"
            ))
            Issue.record(
                "Need gap[5] for h3SpaceAbove. gaps=\(gaps)"
            )
            return
        }

        assertSpatial(
            measured: gaps[5],
            expected: SpatialPRD.h3SpaceAbove,
            prdRef: "spatial-design-language FR-3",
            aspect: "headingSpaceAbove(H3)"
        )
    }

    @Test("test_spatialDesignLanguage_FR3_h3SpaceBelow")
    func h3SpaceBelow() async throws {
        let gaps = try await measureFixtureGaps()
        guard gaps.count > 6 else {
            JSONResultReporter.record(TestResult(
                name: "spatial-design-language FR-3: headingSpaceBelow(H3)",
                status: .fail,
                prdReference: "spatial-design-language FR-3",
                expected: "\(SpatialPRD.h3SpaceBelow)pt",
                actual: "unmeasurable (only \(gaps.count) gaps found, need 7)",
                imagePaths: [],
                duration: 0,
                message: "Gap scanner finds only \(gaps.count) gaps; H3 gap requires fixture redesign"
            ))
            Issue.record(
                "Need gap[6] for h3SpaceBelow. gaps=\(gaps)"
            )
            return
        }

        assertSpatial(
            measured: gaps[6],
            expected: SpatialPRD.h3SpaceBelow,
            prdRef: "spatial-design-language FR-3",
            aspect: "headingSpaceBelow(H3)"
        )
    }

    // MARK: - FR-4: Component Spacing

    @Test("test_spatialDesignLanguage_FR4_codeBlockPadding")
    func codeBlockPadding() async throws {
        let (analyzer, _, _) = try await prepareAnalysis()
        let themeColors = try #require(Self.cachedThemeColors)
        let codeBg = codeBackgroundColor(from: themeColors)
        let sampledBg = sampleRenderedBackground(from: analyzer)
        let codeBgTolerance = 8

        let bgDistance = codeBg.distance(to: sampledBg)
        guard bgDistance > codeBgTolerance else {
            recordCodeBlockFailure(
                "unmeasurable (code bg distance=\(bgDistance) <= tolerance=\(codeBgTolerance))"
            )
            return
        }

        let codeRegion = analyzer.findRegion(
            matching: codeBg, tolerance: codeBgTolerance
        )
        guard let region = codeRegion else {
            recordCodeBlockFailure("unmeasurable (code block region not found)")
            return
        }

        let leftBoundary = analyzer.findColorBoundary(
            from: CGPoint(x: region.minX + 1, y: region.midY),
            direction: .right,
            sourceColor: codeBg,
            tolerance: codeBgTolerance
        )
        guard let textStart = leftBoundary else {
            recordCodeBlockFailure("unmeasurable (text boundary not found)")
            return
        }

        assertSpatial(
            measured: textStart.x - region.minX,
            expected: SpatialPRD.componentPadding,
            prdRef: "spatial-design-language FR-4",
            aspect: "componentPadding (code block)"
        )
    }

    private func recordCodeBlockFailure(_ actual: String) {
        JSONResultReporter.record(TestResult(
            name: "spatial-design-language FR-4: componentPadding (code block)",
            status: .fail,
            prdReference: "spatial-design-language FR-4",
            expected: "\(SpatialPRD.componentPadding)pt",
            actual: actual,
            imagePaths: [],
            duration: 0,
            message: actual
        ))
        Issue.record("\(actual)")
    }

    // MARK: - Gap Measurement Helper

    /// Measures all vertical gaps in the top capture using the sampled
    /// background color with high tolerance. Returns the gaps array
    /// indexed according to the fixture's content order (see extension
    /// doc comment).
    private func measureFixtureGaps() async throws -> [CGFloat] {
        let (analyzer, _, _) = try await prepareAnalysis()
        let sampledBg = sampleRenderedBackground(from: analyzer)

        let bounds = spatialContentBounds(
            in: analyzer,
            background: sampledBg,
            tolerance: spatialBgColorTolerance
        )
        return measureVerticalGaps(
            in: analyzer,
            atX: bounds.midX,
            bgColor: sampledBg,
            tolerance: spatialBgColorTolerance
        )
    }
}
