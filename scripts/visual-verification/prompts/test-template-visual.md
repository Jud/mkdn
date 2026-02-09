# Test Template: Visual (Color/Theme) Assertion

Use this template to generate Swift Testing test files for color and theme compliance issues detected by vision evaluation. These tests use `ImageAnalyzer`, `ColorExtractor`, and `PixelColor` from the existing test infrastructure.

## Template Variables

| Variable | Source | Example |
|----------|--------|---------|
| `{evaluationId}` | evaluation.json `evaluationId` | `eval-2026-02-09-180000` |
| `{issueId}` | issue `issueId` | `ISS-002` |
| `{prdReference}` | issue `prdReference` | `terminal-consistent-theming FR-7` |
| `{prdCamelCase}` | PRD name in camelCase | `terminalConsistentTheming` |
| `{FR}` | functional requirement ID | `FR7` |
| `{aspect}` | specific color/visual aspect in camelCase | `codeBlockBackground` |
| `{specificationExcerpt}` | issue `specificationExcerpt` | `Code blocks have distinct background` |
| `{observation}` | issue `observation` | `Code block background matches document background` |
| `{fixture}` | fixture filename | `theme-tokens.md` |
| `{theme}` | theme name | `solarizedDark` |
| `{colorTolerance}` | color matching tolerance | `15` |
| `{date}` | generation date | `2026-02-09` |

## Generated Test Pattern

```swift
import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import mkdnLib

/// Vision-detected visual compliance test.
///
/// **Source**: LLM visual verification ({evaluationId}, {issueId})
/// **PRD**: {prdReference}
/// **Specification**: "{specificationExcerpt}"
/// **Observation**: {observation}
/// **Generated**: {date}
@Suite("VisionDetected_{prdCamelCase}_{FR}", .serialized)
struct VisionDetected_{prdCamelCase}_{FR}_{aspect} {
    @Test("{prdReference}_{aspect}_visionDetected")
    func {aspect}() async throws {
        let client = try await VisionComplianceHarness.ensureRunning()
        _ = try await client.setTheme("{theme}")

        let loadResp = try await client.loadFile(
            path: visionFixturePath("{fixture}")
        )
        try #require(loadResp.status == "ok", "File load must succeed")
        try await Task.sleep(for: .milliseconds(1_500))

        let captureResp = try await client.captureWindow()
        let capture = try visionExtractCapture(from: captureResp)
        let analyzer = try visionLoadAnalyzer(from: capture)

        // Retrieve theme colors from the running app for comparison.
        let colorsResp = try await client.getThemeColors()
        let colors = try visionExtractThemeColors(from: colorsResp)

        // Sample and compare colors.
        // The specific sampling logic depends on the aspect:
        //
        // For background colors: sample at a known safe position
        //   (document margin area, mid-height).
        //
        // For text colors: find content regions, extract dominant
        //   non-background color from the region.
        //
        // For code block colors: find the code block region, sample
        //   the background inside it.
        //
        // For syntax token colors: find specific token regions within
        //   the code block and sample their dominant colors.

        // --- INSERT COLOR SAMPLING LOGIC HERE ---
        // let sampledColor: PixelColor = ...
        // let expectedColor = PixelColor.from(rgbColor: colors.{field})
        // let tolerance = {colorTolerance}
        // let passed = ColorExtractor.matches(
        //     sampledColor,
        //     expected: expectedColor,
        //     tolerance: tolerance
        // )

        // #expect(
        //     passed,
        //     "{prdReference}: {aspect} expected \(expectedColor), sampled \(sampledColor) (tolerance: \(tolerance))"
        // )

        // JSONResultReporter.record(TestResult(
        //     name: "{prdReference}: {aspect} (vision-detected)",
        //     status: passed ? .pass : .fail,
        //     prdReference: "{prdReference}",
        //     expected: "\(expectedColor)",
        //     actual: "\(sampledColor)",
        //     imagePaths: [capture.imagePath],
        //     duration: 0,
        //     message: passed ? nil : "{prdReference}: {aspect} expected \(expectedColor), sampled \(sampledColor)"
        // ))
    }
}
```

## Color Sampling Techniques Reference

### Document Background
```swift
let renderedBg = visualSampleBackground(from: analyzer)
let expectedBg = PixelColor.from(rgbColor: colors.background)
// Use backgroundProfileTolerance (20) for Display P3 vs sRGB offset.
```

### Code Block Background
```swift
let renderedBg = visualSampleBackground(from: analyzer)
let codeRegion = findCodeBlockRegion(
    in: analyzer,
    codeBg: PixelColor.from(rgbColor: colors.codeBackground),
    srgbBg: PixelColor.from(rgbColor: colors.background),
    renderedBg: renderedBg
)
// Sample inside the code region for the code block background color.
let codeBgSampled = analyzer.sampleColor(
    at: CGPoint(x: codeRegion.midX, y: codeRegion.minY + 5)
)
```

### Heading Text Color
```swift
let renderedBg = visualSampleBackground(from: analyzer)
let headingColor = visualFindHeadingColor(analyzer: analyzer, renderedBg: renderedBg)
```

### Body Text Color
```swift
let renderedBg = visualSampleBackground(from: analyzer)
let bodyColor = visualFindBodyTextColor(analyzer: analyzer, renderedBg: renderedBg, colors: colors)
```

### Syntax Token Color
```swift
// Find the code block region first, then scan for colored text regions
// within it. Compare against theme's syntax color fields.
let expectedKeyword = PixelColor.from(rgbColor: colors.syntaxKeyword)
// Sample at known token positions within the code block.
```

## Color Comparison Notes

- Use `ColorExtractor.matches(_:expected:tolerance:)` for Chebyshev distance matching
- Standard tolerance: 10 for exact color matches
- Text tolerance: 20 for anti-aliased text (sub-pixel blending)
- Background profile tolerance: 20 for Display P3 vs sRGB conversion offset
- Syntax token tolerance: 25 for syntax highlighting (anti-aliasing + sub-pixel rendering)
- Use `estimateRenderedColor(srgb:referenceSRGB:referenceRendered:)` to compensate for color profile offset when comparing against known sRGB values
