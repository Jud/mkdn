import CoreGraphics
import Foundation
import Testing

@testable import mkdnLib

/// Syntax highlighting token color compliance tests.
///
/// Extension of `VisualComplianceTests` covering AC-004d: verification
/// that code block syntax highlighting produces distinct token colors
/// for both Solarized themes.
///
/// The test uses a color-space-agnostic approach: rather than matching
/// hardcoded sRGB values (which shift unpredictably under each
/// display's ICC profile), it verifies that the code block contains
/// multiple distinct non-foreground text colors. This proves the
/// syntax highlighter is applying per-token colors without depending
/// on the sRGB-to-display-profile conversion being predictable.
extension VisualComplianceTests {
    // MARK: - AC-004d: Syntax Token Colors

    /// automated-ui-testing AC-004d: Syntax highlighting produces
    /// distinct token colors for Solarized Dark.
    @Test("test_visualCompliance_AC004d_syntaxTokensSolarizedDark")
    func syntaxTokensDark() async throws {
        let (analyzer, colors, renderedBg) = try await prepareDark()
        try verifySyntaxTokens(
            analyzer: analyzer,
            colors: colors,
            renderedBg: renderedBg,
            theme: "Solarized Dark"
        )
    }

    /// automated-ui-testing AC-004d: Syntax highlighting produces
    /// distinct token colors for Solarized Light.
    @Test("test_visualCompliance_AC004d_syntaxTokensSolarizedLight")
    func syntaxTokensLight() async throws {
        let (analyzer, colors, renderedBg) = try await prepareLight()
        try verifySyntaxTokens(
            analyzer: analyzer,
            colors: colors,
            renderedBg: renderedBg,
            theme: "Solarized Light"
        )
    }

    // MARK: - Private

    /// Verifies that the code block contains multiple distinct text
    /// colors beyond the default foreground, proving syntax
    /// highlighting is active.
    ///
    /// Approach:
    /// 1. Find the code block region via background color detection
    /// 2. Collect all distinct non-background colors in the region
    ///    (quantized to 8-value buckets to merge anti-aliasing)
    /// 3. Identify the dominant color as code foreground
    /// 4. Count how many other distinct color groups have >= 20 pixels
    ///    and are visually distinct (distance > 30) from the dominant
    /// 5. Require at least 2 such groups (keyword, string, type, etc.)
    private func verifySyntaxTokens(
        analyzer: ImageAnalyzer,
        colors: ThemeColorsResult,
        renderedBg: PixelColor,
        theme: String
    ) throws {
        let codeBg = PixelColor.from(rgbColor: colors.codeBackground)
        let srgbBg = PixelColor.from(rgbColor: colors.background)
        let codeRegion = try #require(
            findCodeBlockRegion(
                in: analyzer,
                codeBg: codeBg,
                srgbBg: srgbBg,
                renderedBg: renderedBg
            ),
            "Must find code block region for syntax verification"
        )

        let distinctCount = countDistinctSyntaxColors(
            analyzer: analyzer,
            region: codeRegion,
            renderedBg: renderedBg,
            codeBg: codeBg
        )

        let passed = distinctCount >= 2

        #expect(
            passed,
            """
            automated-ui-testing AC-004d: \(theme) \
            expected >= 2 distinct syntax colors, \
            found \(distinctCount)
            """
        )

        recordSyntaxResult(
            passed: passed,
            found: distinctCount,
            theme: theme
        )
    }

    /// Counts distinct non-foreground text color groups in a code
    /// block region.
    ///
    /// Scans the left portion of the code block (where text is dense)
    /// and collects pixel colors into quantized buckets. After
    /// identifying the dominant color (code foreground/comment), it
    /// counts additional color groups that are visually distinct.
    private func countDistinctSyntaxColors(
        analyzer: ImageAnalyzer,
        region: CGRect,
        renderedBg: PixelColor,
        codeBg: PixelColor
    ) -> Int {
        let bounds = analyzer.contentBounds(
            background: renderedBg,
            tolerance: visualColorTolerance
        )
        let scanLeft = bounds.minX + 24
        let scanRight = min(bounds.minX + 500, region.maxX)
        let scanTop = region.minY
        let scanBottom = region.maxY

        let renderedCodeBg = estimateRenderedColor(
            srgb: codeBg,
            referenceSRGB: PixelColor.from(
                red: Double(renderedBg.red) / 255.0 + 0.001,
                green: Double(renderedBg.green) / 255.0 + 0.001,
                blue: Double(renderedBg.blue) / 255.0 + 0.001
            ),
            referenceRendered: renderedBg
        )

        var buckets: [UInt32: (color: PixelColor, count: Int)] = [:]
        let step: CGFloat = 1.0

        for yPt in stride(from: scanTop, to: scanBottom, by: step) {
            for xPt in stride(from: scanLeft, to: scanRight, by: step) {
                let color = analyzer.sampleColor(
                    at: CGPoint(x: xPt, y: yPt)
                )
                let bgDist = color.distance(to: renderedBg)
                let codeBgDist = color.distance(to: renderedCodeBg)
                guard bgDist > 20, codeBgDist > 20 else { continue }

                let key = quantizeSyntaxColor(color)
                if let existing = buckets[key] {
                    buckets[key] = (existing.color, existing.count + 1)
                } else {
                    buckets[key] = (color, 1)
                }
            }
        }

        let significantBuckets = buckets.values
            .filter { $0.count >= 20 }
            .sorted { $0.count > $1.count }

        guard let dominant = significantBuckets.first else { return 0 }

        var distinctColors = 0
        for bucket in significantBuckets.dropFirst() {
            let dist = bucket.color.distance(to: dominant.color)
            if dist > 30 {
                distinctColors += 1
            }
        }

        return distinctColors
    }

    private func recordSyntaxResult(
        passed: Bool,
        found: Int,
        theme: String
    ) {
        let msg = "automated-ui-testing AC-004d: \(theme) expected >= 2 distinct syntax colors, found \(found)"

        JSONResultReporter.record(TestResult(
            name: "automated-ui-testing AC-004d: syntaxTokens \(theme)",
            status: passed ? .pass : .fail,
            prdReference: "automated-ui-testing AC-004d",
            expected: ">= 2 distinct syntax accent colors",
            actual: "\(found) distinct found",
            imagePaths: [],
            duration: 0,
            message: passed ? nil : msg
        ))
    }
}

/// Quantizes a pixel color to 8-value buckets (32 per channel)
/// for grouping anti-aliased pixels with the same base color.
private func quantizeSyntaxColor(_ color: PixelColor) -> UInt32 {
    let rBucket = UInt32(color.red / 8)
    let gBucket = UInt32(color.green / 8)
    let bBucket = UInt32(color.blue / 8)
    return (rBucket << 16) | (gBucket << 8) | bBucket
}
