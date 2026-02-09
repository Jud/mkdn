# Test Template: Qualitative Assessment

Use this template to generate Swift Testing test files for qualitative design findings detected by vision evaluation. Qualitative findings reference the charter design philosophy rather than specific PRD functional requirements. These tests measure proxy metrics that capture the qualitative observation as a concrete, reproducible assertion.

## When to Use This Template

Qualitative findings describe higher-order design qualities:
- Spatial rhythm and balance between elements
- Visual consistency across similar elements
- Overall composition and polish
- Theme coherence across the document

Since qualitative findings are subjective by nature, the generated test must translate the observation into a measurable proxy. Common proxy metrics:

| Qualitative Observation | Proxy Metric |
|------------------------|--------------|
| "Spacing between blocks feels uneven" | Standard deviation of inter-block gaps |
| "Heading hierarchy feels flat" | Ratio of H1 space to H2 space to H3 space |
| "Code block feels disconnected from surrounding text" | Gap above/below code block vs standard blockSpacing |
| "Colors feel inconsistent" | Color distance between similar elements |
| "Vertical rhythm is broken" | Coefficient of variation of same-type spacing |

## Template Variables

| Variable | Source | Example |
|----------|--------|---------|
| `{evaluationId}` | evaluation.json `evaluationId` | `eval-2026-02-09-180000` |
| `{findingId}` | finding `findingId` | `QF-001` |
| `{reference}` | finding `reference` | `charter:design-philosophy` |
| `{aspect}` | specific quality aspect in camelCase | `verticalRhythmConsistency` |
| `{observation}` | finding `observation` | `Spacing between code block and paragraph is larger than paragraph-to-paragraph spacing` |
| `{assessment}` | finding `assessment` | `Vertical rhythm is slightly inconsistent` |
| `{fixture}` | fixture filename | `canonical.md` |
| `{theme}` | theme name | `solarizedDark` |
| `{date}` | generation date | `2026-02-09` |

## Generated Test Pattern

```swift
import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import mkdnLib

/// Vision-detected qualitative design assessment.
///
/// **Source**: LLM visual verification ({evaluationId}, {findingId})
/// **Reference**: {reference}
/// **Observation**: {observation}
/// **Assessment**: {assessment}
/// **Generated**: {date}
@Suite("VisionDetected_qualitative_{aspect}", .serialized)
struct VisionDetected_qualitative_{aspect} {
    @Test("{reference}_{aspect}_visionDetected")
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

        // Measure the proxy metric that captures the qualitative finding.
        //
        // The specific measurement depends on the observation:
        //
        // For rhythm/consistency findings: measure all inter-block gaps,
        //   compute standard deviation or coefficient of variation,
        //   assert it is below a threshold.
        //
        // For hierarchy findings: measure spacing ratios between
        //   heading levels, assert they follow the expected progression.
        //
        // For balance findings: measure left/right margins, assert
        //   they are within tolerance of each other.
        //
        // For coherence findings: sample colors from multiple similar
        //   elements, assert they match within tolerance.

        // --- INSERT PROXY MEASUREMENT LOGIC HERE ---
        // let metric: CGFloat = ...
        // let threshold: CGFloat = ...
        // let passed = metric <= threshold  // (or appropriate comparison)

        // #expect(
        //     passed,
        //     "{reference}: {aspect} metric=\(metric), threshold=\(threshold)"
        // )

        // JSONResultReporter.record(TestResult(
        //     name: "{reference}: {aspect} (vision-detected)",
        //     status: passed ? .pass : .fail,
        //     prdReference: "{reference}",
        //     expected: "threshold: \(threshold)",
        //     actual: "metric: \(metric)",
        //     imagePaths: [capture.imagePath],
        //     duration: 0,
        //     message: passed ? nil : "{reference}: {aspect} metric \(metric) exceeds threshold \(threshold)"
        // ))
    }
}
```

## Proxy Metric Techniques Reference

### Vertical Rhythm Consistency
```swift
let bg = visualSampleBackground(from: analyzer)
let gaps = measureVerticalGaps(in: analyzer, atX: bounds.minX + 50, bgColor: bg)
// Filter for paragraph-to-paragraph gaps (exclude heading gaps).
let paragraphGaps = gaps.filter { $0 > 10 && $0 < 40 }
let mean = paragraphGaps.reduce(0, +) / CGFloat(paragraphGaps.count)
let variance = paragraphGaps.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / CGFloat(paragraphGaps.count)
let stddev = sqrt(variance)
let coefficientOfVariation = stddev / mean
// A well-rhythmed document has CV < 0.15 (15% variation).
```

### Heading Hierarchy Ratios
```swift
let bg = visualSampleBackground(from: analyzer)
let gaps = measureVerticalGaps(in: analyzer, atX: bounds.minX + 50, bgColor: bg)
// Identify heading gaps by position in the fixture.
// Assert: h1Gap > h2Gap > h3Gap (monotonically decreasing).
// Assert: h1Gap / h2Gap is between 1.2 and 2.0 (clear but not extreme hierarchy).
```

### Margin Balance
```swift
let bounds = spatialContentBounds(in: analyzer, background: bg, tolerance: 10)
let leftMargin = bounds.minX
let rightMargin = analyzer.pointWidth - bounds.maxX
let marginImbalance = abs(leftMargin - rightMargin)
// Balanced margins: imbalance < 4pt.
```

### Cross-Element Color Consistency
```swift
// Sample multiple same-type elements (e.g., all H2 headings).
// Compute max color distance between any pair.
// Consistent rendering: max distance < colorTolerance.
```

## Threshold Guidelines

| Proxy Metric | Threshold | Rationale |
|-------------|-----------|-----------|
| Spacing coefficient of variation | 0.15 (15%) | Visually perceptible rhythm break above this |
| Heading ratio (H1/H2) | 1.2 - 2.0 | Clear hierarchy without extreme separation |
| Margin imbalance | 4pt | Sub-grid-unit precision for balance |
| Same-type color distance | 10 | Standard color matching tolerance |
| Same-type spacing variance | 4pt | Two grid sub-units of variation |
