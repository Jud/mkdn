# Test Template: Spatial Assertion

Use this template to generate Swift Testing test files for spatial compliance issues detected by vision evaluation. These tests use `SpatialMeasurement` and `ImageAnalyzer` from the existing test infrastructure.

## Template Variables

| Variable | Source | Example |
|----------|--------|---------|
| `{evaluationId}` | evaluation.json `evaluationId` | `eval-2026-02-09-180000` |
| `{issueId}` | issue `issueId` | `ISS-001` |
| `{prdReference}` | issue `prdReference` | `spatial-design-language FR-3` |
| `{prdCamelCase}` | PRD name in camelCase | `spatialDesignLanguage` |
| `{FR}` | functional requirement ID | `FR3` |
| `{aspect}` | specific measurement aspect in camelCase | `h1SpaceAbove` |
| `{specificationExcerpt}` | issue `specificationExcerpt` | `H1 headings have 48pt space above` |
| `{observation}` | issue `observation` | `Space above H1 appears to be ~24pt` |
| `{fixture}` | fixture filename | `canonical.md` |
| `{theme}` | theme name | `solarizedDark` |
| `{expectedValue}` | expected measurement value | `48` |
| `{tolerancePt}` | measurement tolerance in points | `2` |
| `{date}` | generation date | `2026-02-09` |

## Generated Test Pattern

```swift
import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import mkdnLib

/// Vision-detected spatial compliance test.
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

        // Measure the spatial property under test.
        // The specific measurement logic depends on the aspect:
        //
        // For document margins: measure distance from window edge to
        //   first content pixel using spatialContentBounds or
        //   ImageAnalyzer.contentBounds.
        //
        // For heading spacing: use measureVerticalGaps to find
        //   inter-element gaps, then identify the gap corresponding
        //   to the heading position.
        //
        // For component padding: find the code block or blockquote
        //   region, then measure from the region edge to the first
        //   text pixel inside it.
        //
        // For block spacing: measure gaps between consecutive same-type
        //   blocks using measureVerticalGaps.

        // --- INSERT MEASUREMENT LOGIC HERE ---
        // let measured: CGFloat = ...
        // let expected: CGFloat = {expectedValue}
        // let tolerance: CGFloat = {tolerancePt}
        // let passed = abs(measured - expected) <= tolerance

        // #expect(
        //     passed,
        //     "{prdReference}: {aspect} expected \(expected)pt, measured \(measured)pt (tolerance: \(tolerance)pt)"
        // )

        // JSONResultReporter.record(TestResult(
        //     name: "{prdReference}: {aspect} (vision-detected)",
        //     status: passed ? .pass : .fail,
        //     prdReference: "{prdReference}",
        //     expected: "\(expected)",
        //     actual: "\(measured)",
        //     imagePaths: [capture.imagePath],
        //     duration: 0,
        //     message: passed ? nil : "{prdReference}: {aspect} expected \(expected)pt, measured \(measured)pt"
        // ))
    }
}
```

## Measurement Techniques Reference

### Document Margin (Left/Right)
```swift
let bg = analyzer.sampleColor(at: CGPoint(x: analyzer.pointWidth / 2, y: 10))
let bounds = spatialContentBounds(in: analyzer, background: bg, tolerance: 10)
let leftMargin = bounds.minX
let rightMargin = analyzer.pointWidth - bounds.maxX
```

### Heading Spacing (Above/Below)
```swift
let bg = visualSampleBackground(from: analyzer)
let gaps = measureVerticalGaps(in: analyzer, atX: bounds.minX + 50, bgColor: bg, tolerance: 10)
// gaps[N] corresponds to the Nth inter-element gap from top to bottom.
// Map gap indices to heading positions based on fixture structure.
```

### Block-to-Block Spacing
```swift
let bg = visualSampleBackground(from: analyzer)
let gaps = measureVerticalGaps(in: analyzer, atX: bounds.minX + 50, bgColor: bg, tolerance: 10)
// Filter for gaps between same-type elements (e.g., paragraph-to-paragraph).
// Check consistency: all such gaps should be within tolerance of each other.
```

### Component Padding (Code Block Internal)
```swift
let codeRegion = findCodeBlockRegion(in: analyzer, codeBg: codeBg, srgbBg: srgbBg, renderedBg: renderedBg)
// Measure from code region edge to first text pixel inside the region.
```

## Fixture-to-Measurement Mapping

| Fixture | Measurable Aspects |
|---------|-------------------|
| `canonical.md` | Document margins, heading spacing (H1-H3), block spacing, list indentation |
| `geometry-calibration.md` | Document margins, heading spacing, block spacing (designed for precise measurement) |
| `theme-tokens.md` | Code block padding, code block spacing |
| `mermaid-focus.md` | Diagram container spacing, block spacing around diagrams |
