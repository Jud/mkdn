import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import mkdnLib

// MARK: - PRD Expected Values

/// Expected visual compliance values from the automated-ui-testing PRD
/// and Solarized theme definitions.
///
/// Syntax token colors are hard-coded from the Solarized accent palette
/// because the harness protocol does not yet expose SyntaxColors.
/// When the harness gains syntax color reporting, replace these
/// literals with harness-reported values.
enum VisualPRD {
    /// keyword: green (#859900)
    static let syntaxKeyword = PixelColor.from(
        red: 0.522,
        green: 0.600,
        blue: 0.000
    )

    /// string: cyan (#2aa198)
    static let syntaxString = PixelColor.from(
        red: 0.165,
        green: 0.631,
        blue: 0.596
    )

    /// type: yellow (#b58900)
    static let syntaxType = PixelColor.from(
        red: 0.710,
        green: 0.537,
        blue: 0.000
    )
}

// MARK: - Measurement Constants

let visualColorTolerance = 10
let visualTextTolerance = 15
let visualSyntaxTolerance = 25

// MARK: - Shared Harness

enum VisualHarness {
    nonisolated(unsafe) static var launcher: AppLauncher?
    nonisolated(unsafe) static var client: TestHarnessClient?

    static func ensureRunning() async throws -> TestHarnessClient {
        if let existing = client {
            let pong = try await existing.ping()
            if pong.status == "ok" {
                return existing
            }
        }
        let newLauncher = AppLauncher()
        let newClient = try await newLauncher.launch()
        launcher = newLauncher
        client = newClient
        return newClient
    }
}

// MARK: - Fixture Paths

func visualFixturePath(_ name: String) -> String {
    var url = URL(fileURLWithPath: #filePath)
    while url.path != "/" {
        url = url.deletingLastPathComponent()
        let candidate = url
            .appendingPathComponent("mkdnTests/Fixtures/UITest")
            .appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate.path
        }
    }
    preconditionFailure("Fixture \(name) not found")
}

// MARK: - Capture Helpers

/// Namespaced helpers for extracting capture results from harness
/// responses. Avoids collision with identically-shaped free functions
/// in other test suites.
enum VisualCapture {
    static func extractResult(
        from response: HarnessResponse
    ) throws -> CaptureResult {
        guard response.status == "ok",
              let data = response.data,
              case let .capture(result) = data
        else {
            throw HarnessError.captureFailed(
                response.message ?? "Capture returned error status"
            )
        }
        return result
    }

    static func loadImage(
        from capture: CaptureResult
    ) throws -> ImageAnalyzer {
        let url = URL(fileURLWithPath: capture.imagePath) as CFURL
        guard let source = CGImageSourceCreateWithURL(url, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw HarnessError.captureFailed(
                "Cannot load image at \(capture.imagePath)"
            )
        }
        return ImageAnalyzer(
            image: image,
            scaleFactor: CGFloat(capture.scaleFactor)
        )
    }

    static func extractColors(
        from response: HarnessResponse
    ) throws -> ThemeColorsResult {
        guard response.status == "ok",
              let data = response.data,
              case let .themeColors(result) = data
        else {
            throw HarnessError.unexpectedResponse(
                "No theme colors in response"
            )
        }
        return result
    }
}

// MARK: - Content Region Scanner

/// Returns vertical ranges (in points) of content regions at the
/// given x-coordinate. Content is any non-background pixel run
/// taller than `minHeight`.
func findContentRegions(
    in analyzer: ImageAnalyzer,
    atX: CGFloat,
    bgColor: PixelColor,
    tolerance: Int = 10,
    minHeight: CGFloat = 3
) -> [(minY: CGFloat, maxY: CGFloat)] {
    let scale = analyzer.scaleFactor
    let heightPx = analyzer.image.height
    var regions: [(minY: CGFloat, maxY: CGFloat)] = []
    var regionStartPx: Int?

    for py in 0 ..< heightPx {
        let ptY = CGFloat(py) / scale
        let color = analyzer.sampleColor(at: CGPoint(x: atX, y: ptY))
        let isBg = ColorExtractor.matches(
            color,
            expected: bgColor,
            tolerance: tolerance
        )

        if !isBg {
            if regionStartPx == nil { regionStartPx = py }
        } else if let start = regionStartPx {
            let minY = CGFloat(start) / scale
            let maxY = CGFloat(py) / scale
            if maxY - minY >= minHeight {
                regions.append((minY: minY, maxY: maxY))
            }
            regionStartPx = nil
        }
    }

    if let start = regionStartPx {
        let minY = CGFloat(start) / scale
        let maxY = CGFloat(heightPx) / scale
        if maxY - minY >= minHeight {
            regions.append((minY: minY, maxY: maxY))
        }
    }

    return regions
}

// MARK: - Text Color Sampling

/// Finds the dominant non-background color in a region.
///
/// Scans at half-point intervals, excludes background-colored pixels,
/// and returns the most frequent remaining color (quantized to
/// 16-value buckets to handle anti-aliasing variation).
func findDominantTextColor(
    in analyzer: ImageAnalyzer,
    region: CGRect,
    background: PixelColor,
    bgTolerance: Int = 10
) -> PixelColor? {
    var buckets: [UInt32: (PixelColor, Int)] = [:]
    let step: CGFloat = 0.5

    for yPt in stride(from: region.minY, to: region.maxY, by: step) {
        for xPt in stride(from: region.minX, to: region.maxX, by: step) {
            let color = analyzer.sampleColor(
                at: CGPoint(x: xPt, y: yPt)
            )
            let isBackground = ColorExtractor.matches(
                color,
                expected: background,
                tolerance: bgTolerance
            )
            guard !isBackground else { continue }

            let key = quantizeColor(color)
            if let (_, count) = buckets[key] {
                buckets[key] = (color, count + 1)
            } else {
                buckets[key] = (color, 1)
            }
        }
    }

    return buckets.values.max { $0.1 < $1.1 }?.0
}

/// Checks whether a target syntax color is present in a region.
///
/// Returns `true` if any pixel within the region matches `target`
/// within `tolerance`. Scans at 1-point intervals for speed.
func containsSyntaxColor(
    _ target: PixelColor,
    in analyzer: ImageAnalyzer,
    region: CGRect,
    tolerance: Int = 25
) -> Bool {
    let step: CGFloat = 1.0
    for yPt in stride(from: region.minY, to: region.maxY, by: step) {
        for xPt in stride(from: region.minX, to: region.maxX, by: step) {
            let color = analyzer.sampleColor(
                at: CGPoint(x: xPt, y: yPt)
            )
            if ColorExtractor.matches(
                color,
                expected: target,
                tolerance: tolerance
            ) {
                return true
            }
        }
    }
    return false
}

// MARK: - Color Assertion

func assertVisualColor(
    sampled: PixelColor,
    expected: PixelColor,
    tolerance: Int,
    prdRef: String,
    aspect: String
) {
    #expect(
        ColorExtractor.matches(
            sampled,
            expected: expected,
            tolerance: tolerance
        ),
        """
        \(prdRef): \(aspect) \
        expected \(expected), sampled \(sampled) \
        (tolerance: \(tolerance))
        """
    )
}

// MARK: - Private

private func quantizeColor(_ color: PixelColor) -> UInt32 {
    let rBucket = UInt32(color.red / 16)
    let gBucket = UInt32(color.green / 16)
    let bBucket = UInt32(color.blue / 16)
    return (rBucket << 16) | (gBucket << 8) | bBucket
}
