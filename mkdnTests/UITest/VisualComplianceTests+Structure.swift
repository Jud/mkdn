import CoreGraphics
import Foundation
import Testing

@testable import mkdnLib

// MARK: - Code Block Structural Tests

extension VisualComplianceTests {
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

        let result = measureEdgeConsistency(
            analyzer: analyzer,
            region: region,
            codeBg: expected,
            renderedBg: renderedBg
        )

        withKnownIssue(
            """
            NSAttributedString .backgroundColor follows text line \
            fragments, not a cohesive rectangular block. Fix: integrate \
            CodeBlockView rounded-rect styling into NSTextView rendering \
            path (syntax-highlighting NFR-5).
            """
        ) {
            #expect(
                result.isContainer,
                """
                Code block must render as a structural container \
                with uniform edges. Right edge variance: \
                \(result.rightEdgeVariance)pt. \
                Expected < 4pt for a proper container block.
                """
            )
        }

        recordStructuralResult(result)
    }
}

// MARK: - Edge Measurement

struct EdgeConsistencyResult {
    let leftEdges: [CGFloat]
    let rightEdges: [CGFloat]
    let hasEnoughSamples: Bool
    let rightEdgeConsistent: Bool
    var isContainer: Bool { hasEnoughSamples && rightEdgeConsistent }

    var rightEdgeVariance: CGFloat {
        guard let maxR = rightEdges.max(),
              let minR = rightEdges.min()
        else { return -1 }
        return maxR - minR
    }
}

/// Scans the code block region at multiple y-positions to measure
/// whether the left and right edges of the code background are
/// uniform (container) or varying (text-line-level).
func measureEdgeConsistency(
    analyzer: ImageAnalyzer,
    region: CGRect,
    codeBg: PixelColor,
    renderedBg: PixelColor
) -> EdgeConsistencyResult {
    let scale = analyzer.scaleFactor
    let scanYPositions = stride(
        from: region.minY + 5,
        to: region.maxY - 5,
        by: 8
    )

    var leftEdges: [CGFloat] = []
    var rightEdges: [CGFloat] = []

    for scanY in scanYPositions {
        let left = scanForEdge(
            analyzer: analyzer,
            region: region,
            scanY: scanY,
            codeBg: codeBg,
            renderedBg: renderedBg,
            fromLeft: true
        )
        let right = scanForEdge(
            analyzer: analyzer,
            region: region,
            scanY: scanY,
            codeBg: codeBg,
            renderedBg: renderedBg,
            fromLeft: false
        )
        if let left { leftEdges.append(left) }
        if let right { rightEdges.append(right) }
    }

    let hasEnough = leftEdges.count >= 3 && rightEdges.count >= 3
    var rightConsistent = false
    if hasEnough,
       let maxR = rightEdges.max(),
       let minR = rightEdges.min()
    {
        rightConsistent = (maxR - minR) < 4
    }

    return EdgeConsistencyResult(
        leftEdges: leftEdges,
        rightEdges: rightEdges,
        hasEnoughSamples: hasEnough,
        rightEdgeConsistent: rightConsistent
    )
}

// MARK: - Pixel Scanning

private func scanForEdge(
    analyzer: ImageAnalyzer,
    region: CGRect,
    scanY: CGFloat,
    codeBg: PixelColor,
    renderedBg: PixelColor,
    fromLeft: Bool
) -> CGFloat? {
    let scale = analyzer.scaleFactor
    let startPx = fromLeft
        ? Int(region.minX * scale) - 20
        : Int(region.maxX * scale) + 20
    let endPx = fromLeft
        ? Int(region.maxX * scale) + 20
        : Int(region.minX * scale) - 20
    let step = fromLeft ? 1 : -1

    for px in stride(from: startPx, through: endPx, by: step) {
        let ptX = CGFloat(px) / scale
        let color = analyzer.sampleColor(
            at: CGPoint(x: ptX, y: scanY)
        )
        if ColorExtractor.matches(
            color, expected: renderedBg, tolerance: 20
        ) {
            continue
        }
        if ColorExtractor.matches(
            color, expected: codeBg, tolerance: 20
        ) {
            return ptX
        }
        break
    }
    return nil
}

// MARK: - JSON Recording

private func recordStructuralResult(
    _ result: EdgeConsistencyResult
) {
    let variance = result.rightEdgeVariance
    JSONResultReporter.record(TestResult(
        name: "visual: codeBlock structural container",
        status: result.isContainer ? .pass : .fail,
        prdReference: "syntax-highlighting NFR-5",
        expected: "uniform rectangular container with rounded corners",
        actual: result.isContainer
            ? "container detected"
            : "text-line-level background (right edge variance: \(variance)pt)",
        imagePaths: [],
        duration: 0,
        message: result.isContainer
            ? nil
            : """
            Code blocks use NSAttributedString .backgroundColor \
            (text-line-level) instead of a contained rectangular \
            block. CodeBlockView with rounded corners/border is \
            dead code since NSTextView migration.
            """
    ))
}
