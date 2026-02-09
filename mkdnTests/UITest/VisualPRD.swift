import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import mkdnLib

// MARK: - Visual PRD Namespace

/// Namespace marker for visual compliance test utilities.
///
/// Previous versions held hardcoded sRGB syntax token colors.
/// Those were removed in favor of the color-space-agnostic
/// approach in `VisualComplianceTests+Syntax.swift`.
enum VisualPRD {}

// MARK: - Measurement Constants

let visualColorTolerance = 10
let visualTextTolerance = 20

/// Extra tolerance for document background color matching in captures.
/// The rendered background color differs from the theme-reported sRGB
/// values by up to 16 units due to Display P3 vs sRGB color profile
/// conversion in CGWindowListCreateImage. Empirically measured:
/// dark bg delta = 14, light bg delta = 16.
let backgroundProfileTolerance = 20

/// Inset (in points) to skip from window edges when sampling
/// background color. Avoids the macOS window material row at the top
/// and rounded corner pixels.
let visualChromeInsetPt: CGFloat = 4

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
        let newClient = try await newLauncher.launch(buildFirst: false)
        launcher = newLauncher
        client = newClient
        return newClient
    }

    static func shutdown() async {
        if let activeLauncher = launcher {
            await activeLauncher.teardown()
        }
        launcher = nil
        client = nil
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

// MARK: - Background Sampling

/// Y offset (in points) below which the document content area begins.
/// Above this is the title bar and toolbar. Empirically measured as
/// 61pt (windowTopInset from SpatialPRD). Using 65pt for safety margin.
let visualContentStartPt: CGFloat = 65

/// Samples the actual rendered background color from the document
/// content margin area, avoiding the macOS title bar / toolbar which
/// has a window material tint that differs from the content area
/// background by up to 15 units (light theme).
func visualSampleBackground(
    from analyzer: ImageAnalyzer
) -> PixelColor {
    analyzer.sampleColor(
        at: CGPoint(
            x: 15,
            y: analyzer.pointHeight / 2
        )
    )
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

// MARK: - Code Block Region Detection

/// Finds the code block region by scanning at the right margin where
/// only the code block's `.backgroundColor` attribute creates
/// non-document-background pixels.
///
/// At x = 80% of content width, heading text, paragraph text, and
/// list items have ended (they don't extend that far right). The only
/// non-document-background pixels come from the NSAttributedString
/// `.backgroundColor` attribute that fills the code block's line
/// fragments. This makes the code block the sole (or tallest) content
/// region at the right margin.
///
/// Small gaps from blank lines within the code block are merged with
/// `mergeNearbyRegions` before selecting the tallest region.
func findCodeBlockRegion(
    in analyzer: ImageAnalyzer,
    codeBg _: PixelColor,
    srgbBg _: PixelColor,
    renderedBg: PixelColor
) -> CGRect? {
    let bounds = analyzer.contentBounds(
        background: renderedBg,
        tolerance: visualColorTolerance
    )

    // Try multiple probe positions to find code block.
    // The right margin works best because only the code block's
    // .backgroundColor renders there. Fall back to left-biased probes.
    let probePositions: [CGFloat] = [
        bounds.minX + bounds.width * 0.8,
        bounds.minX + bounds.width * 0.6,
        bounds.minX + bounds.width * 0.4,
        bounds.minX + 50,
    ]

    for probeX in probePositions {
        let allRegions = findContentRegions(
            in: analyzer,
            atX: probeX,
            bgColor: renderedBg,
            tolerance: visualColorTolerance,
            minHeight: 2
        )
        let regions = allRegions.filter { region in
            region.minY >= visualContentStartPt
        }

        let merged = mergeNearbyRegions(regions, maxGap: 30)

        guard let tallest = merged.max(by: { lhs, rhs in
            (lhs.maxY - lhs.minY) < (rhs.maxY - rhs.minY)
        })
        else { continue }

        let height = tallest.maxY - tallest.minY

        // At right-margin probes, even small regions indicate code block bg.
        // At left probes, require taller region to distinguish from headings.
        let minHeight: CGFloat = probeX > bounds.minX + 200 ? 30 : 80
        guard height > minHeight else { continue }

        return CGRect(
            x: 0,
            y: tallest.minY,
            width: analyzer.pointWidth,
            height: height
        )
    }

    return nil
}

/// Merges content regions whose gap is smaller than `maxGap` points.
///
/// Regions are assumed sorted by `minY`. Adjacent regions with a gap
/// of `maxGap` or less are combined into a single region spanning
/// from the first region's `minY` to the last region's `maxY`.
func mergeNearbyRegions(
    _ regions: [(minY: CGFloat, maxY: CGFloat)],
    maxGap: CGFloat
) -> [(minY: CGFloat, maxY: CGFloat)] {
    guard !regions.isEmpty else { return [] }
    var merged: [(minY: CGFloat, maxY: CGFloat)] = []
    var currentMin = regions[0].minY
    var currentMax = regions[0].maxY

    for region in regions.dropFirst() {
        if region.minY - currentMax <= maxGap {
            currentMax = max(currentMax, region.maxY)
        } else {
            merged.append((minY: currentMin, maxY: currentMax))
            currentMin = region.minY
            currentMax = region.maxY
        }
    }
    merged.append((minY: currentMin, maxY: currentMax))
    return merged
}

/// Estimates the rendered (Display P3) pixel color from a known sRGB color
/// by applying the same per-channel offset observed between a reference
/// sRGB/rendered pair (typically the document background).
///
/// The Display P3 vs sRGB conversion in CGWindowListCreateImage shifts
/// pixel values by a per-channel offset that is roughly consistent for
/// colors in the same luminance range. This function extrapolates from
/// the known background offset.
func estimateRenderedColor(
    srgb target: PixelColor,
    referenceSRGB: PixelColor,
    referenceRendered: PixelColor
) -> PixelColor {
    let dr = Int(referenceRendered.red) - Int(referenceSRGB.red)
    let dg = Int(referenceRendered.green) - Int(referenceSRGB.green)
    let db = Int(referenceRendered.blue) - Int(referenceSRGB.blue)

    return PixelColor(
        red: UInt8(clamping: Int(target.red) + dr),
        green: UInt8(clamping: Int(target.green) + dg),
        blue: UInt8(clamping: Int(target.blue) + db)
    )
}

// MARK: - Color Assertion

func assertVisualColor(
    sampled: PixelColor,
    expected: PixelColor,
    tolerance: Int,
    prdRef: String,
    aspect: String
) {
    let passed = ColorExtractor.matches(
        sampled,
        expected: expected,
        tolerance: tolerance
    )

    #expect(
        passed,
        """
        \(prdRef): \(aspect) \
        expected \(expected), sampled \(sampled) \
        (tolerance: \(tolerance))
        """
    )

    let failureMessage = "\(prdRef): \(aspect) expected \(expected), sampled \(sampled) (tolerance: \(tolerance))"

    JSONResultReporter.record(TestResult(
        name: "\(prdRef): \(aspect)",
        status: passed ? .pass : .fail,
        prdReference: prdRef,
        expected: "\(expected)",
        actual: "\(sampled)",
        imagePaths: [],
        duration: 0,
        message: passed ? nil : failureMessage
    ))
}

// MARK: - Heading Color Detection

/// Finds the heading text color by locating the first content region
/// below the toolbar and extracting its dominant non-background color.
func visualFindHeadingColor(
    analyzer: ImageAnalyzer,
    renderedBg: PixelColor
) -> PixelColor? {
    let bounds = analyzer.contentBounds(
        background: renderedBg,
        tolerance: visualColorTolerance
    )
    let headingScanX = bounds.minX + 50
    let allRegions = findContentRegions(
        in: analyzer,
        atX: headingScanX,
        bgColor: renderedBg,
        tolerance: visualColorTolerance
    )
    let regions = allRegions.filter { region in
        region.minY >= visualContentStartPt
    }
    guard let heading = regions.first else { return nil }
    let headingWidth = min(bounds.width, 400)
    return findDominantTextColor(
        in: analyzer,
        region: CGRect(
            x: bounds.minX,
            y: heading.minY,
            width: headingWidth,
            height: heading.maxY - heading.minY
        ),
        background: renderedBg,
        bgTolerance: backgroundProfileTolerance
    )
}

// MARK: - Body Text Color Detection

/// Finds the body text color by scanning content regions and matching
/// against the expected foreground color from the theme.
func visualFindBodyTextColor(
    analyzer: ImageAnalyzer,
    renderedBg: PixelColor,
    colors: ThemeColorsResult
) -> PixelColor? {
    let expectedFg = PixelColor.from(rgbColor: colors.foreground)
    let bounds = analyzer.contentBounds(
        background: renderedBg,
        tolerance: visualColorTolerance
    )
    let bodyScanX = bounds.minX + 50
    let allRegions = findContentRegions(
        in: analyzer,
        atX: bodyScanX,
        bgColor: renderedBg,
        tolerance: visualColorTolerance
    )
    let regions = allRegions.filter { region in
        region.minY >= visualContentStartPt
    }
    for region in regions {
        let regionHeight = region.maxY - region.minY
        guard regionHeight > 8, regionHeight < 80 else { continue }
        let rect = CGRect(
            x: bounds.minX,
            y: region.minY,
            width: min(bounds.width, 600),
            height: regionHeight
        )
        guard let textColor = findDominantTextColor(
            in: analyzer,
            region: rect,
            background: renderedBg,
            bgTolerance: backgroundProfileTolerance
        )
        else { continue }
        if ColorExtractor.matches(
            textColor,
            expected: expectedFg,
            tolerance: visualTextTolerance
        ) {
            return textColor
        }
    }
    return nil
}

// MARK: - Private

private func quantizeColor(_ color: PixelColor) -> UInt32 {
    let rBucket = UInt32(color.red / 16)
    let gBucket = UInt32(color.green / 16)
    let bBucket = UInt32(color.blue / 16)
    return (rBucket << 16) | (gBucket << 8) | bBucket
}
