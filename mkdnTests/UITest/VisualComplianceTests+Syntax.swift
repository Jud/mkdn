import CoreGraphics
import Foundation
import Testing

@testable import mkdnLib

/// Syntax highlighting token color compliance tests.
///
/// Extension of `VisualComplianceTests` covering AC-004d: verification
/// that code block syntax highlighting produces correct token colors
/// for both Solarized themes.
extension VisualComplianceTests {
    // MARK: - AC-004d: Syntax Token Colors

    /// automated-ui-testing AC-004d: Syntax highlighting produces
    /// correct token colors for Solarized Dark.
    ///
    /// Verifies that keyword (green), string (cyan), and type (yellow)
    /// colors from the Solarized accent palette are present in the
    /// code block region of canonical.md.
    @Test("test_visualCompliance_AC004d_syntaxTokensSolarizedDark")
    func syntaxTokensDark() throws {
        try requireCalibration()
        let (analyzer, colors) = try prepareDark()
        try verifySyntaxTokens(
            analyzer: analyzer,
            colors: colors,
            theme: "Solarized Dark"
        )
    }

    /// automated-ui-testing AC-004d: Syntax highlighting produces
    /// correct token colors for Solarized Light.
    @Test("test_visualCompliance_AC004d_syntaxTokensSolarizedLight")
    func syntaxTokensLight() async throws {
        try requireCalibration()
        let (analyzer, colors) = try await prepareLight()
        try verifySyntaxTokens(
            analyzer: analyzer,
            colors: colors,
            theme: "Solarized Light"
        )
    }

    // MARK: - Private

    private func verifySyntaxTokens(
        analyzer: ImageAnalyzer,
        colors: ThemeColorsResult,
        theme: String
    ) throws {
        let codeBg = PixelColor.from(rgbColor: colors.codeBackground)
        let codeRegion = try #require(
            analyzer.findRegion(
                matching: codeBg,
                tolerance: visualColorTolerance
            ),
            "Must find code block region for syntax verification"
        )

        let found = countSyntaxTokenMatches(
            analyzer: analyzer,
            region: codeRegion,
            theme: theme
        )

        let passed = found >= 2

        #expect(
            passed,
            """
            automated-ui-testing AC-004d: \(theme) \
            expected at least 2 of 3 syntax colors, \
            found \(found)
            """
        )

        recordSyntaxResult(
            passed: passed,
            found: found,
            theme: theme
        )
    }

    private func countSyntaxTokenMatches(
        analyzer: ImageAnalyzer,
        region: CGRect,
        theme: String
    ) -> Int {
        let tokenChecks: [(String, PixelColor)] = [
            ("keyword", VisualPRD.syntaxKeyword),
            ("string", VisualPRD.syntaxString),
            ("type", VisualPRD.syntaxType),
        ]

        var found = 0

        for (name, expected) in tokenChecks {
            if containsSyntaxColor(
                expected,
                in: analyzer,
                region: region,
                tolerance: visualSyntaxTolerance
            ) {
                found += 1
            } else {
                Issue.record(
                    """
                    automated-ui-testing AC-004d: \(theme) \
                    syntax \(name) color \(expected) not found \
                    in code block region
                    """
                )
            }
        }

        return found
    }

    private func recordSyntaxResult(
        passed: Bool,
        found: Int,
        theme: String
    ) {
        let msg = "automated-ui-testing AC-004d: \(theme) expected at least 2 of 3 syntax colors, found \(found)"

        JSONResultReporter.record(TestResult(
            name: "automated-ui-testing AC-004d: syntaxTokens \(theme)",
            status: passed ? .pass : .fail,
            prdReference: "automated-ui-testing AC-004d",
            expected: ">= 2 of 3 syntax colors",
            actual: "\(found) of 3 found",
            imagePaths: [],
            duration: 0,
            message: passed ? nil : msg
        ))
    }
}
