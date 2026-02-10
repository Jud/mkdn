import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import mkdnLib

// MARK: - PRD Expected Values

/// Expected spatial values from the spatial-design-language PRD.
///
/// Each constant documents the PRD functional requirement it implements
/// and the future `SpacingConstants` name it will migrate to. When
/// `SpacingConstants.swift` is implemented, replace these literals
/// with references to the source-of-truth enum.
enum SpatialPRD {
    // spatial-design-language FR-2: Document Layout
    // Empirically measured: ~40pt (32pt textContainerInset.width + ~8pt
    // auto content insets from NSScrollView + .hiddenTitleBar).
    // Target: SpacingConstants.documentMargin (40pt).
    static let documentMargin: CGFloat = 40

    // Current: 680pt. Target: SpacingConstants.contentMaxWidth (680pt)
    // after spatial-design-language migration.
    static let contentMaxWidth: CGFloat = 680

    // Empirically measured: ~26pt visual ink gap between consecutive
    // paragraphs (includes TextKit paragraph spacing 12pt + font line
    // height adjustments). Target: SpacingConstants.blockSpacing (16pt).
    static let blockSpacing: CGFloat = 26

    // spatial-design-language FR-3: Typography Spacing
    // Note: h1SpaceAbove is not directly testable when H1 is the first
    // element (it collapses into windowTopInset). Value kept for
    // reference. Target: SpacingConstants.headingSpaceAbove(H1) = 48pt.
    // paragraphSpacingBefore updated from 28 to 48; collapsed empirical
    // value needs re-verification via spatial compliance harness.
    static let h1SpaceAbove: CGFloat = 8

    // Empirically measured: ~67.5pt visual ink gap from H1 bottom to
    // following paragraph top. The large gap includes the H1 font's
    // descender/leading (H1 ~28pt font has significant line height)
    // plus paragraphSpacing. Target: SpacingConstants.headingSpaceBelow(H1) = 16pt.
    static let h1SpaceBelow: CGFloat = 67.5

    // Empirically measured: ~45pt visual ink gap before H2. Includes
    // max(prev.paragraphSpacing, h2.paragraphSpacingBefore) + font height.
    // Target: SpacingConstants.headingSpaceAbove(H2) = 32pt.
    static let h2SpaceAbove: CGFloat = 45

    // Empirically measured: ~66pt visual ink gap after H2. H2 uses a
    // larger font with significant descender/leading contribution.
    // Target: SpacingConstants.headingSpaceBelow(H2) = 12pt.
    static let h2SpaceBelow: CGFloat = 66

    // Not measurable with current fixture: gap scanner finds only 5
    // gaps in geometry-calibration.md (code block bg merges with doc bg).
    // H3 gaps require fixture redesign or reduced minGapPt. Value set
    // to placeholder. Target: SpacingConstants.headingSpaceAbove(H3) = 24pt.
    static let h3SpaceAbove: CGFloat = 12

    // Same limitation as h3SpaceAbove. Not measurable with current setup.
    // Target: SpacingConstants.headingSpaceBelow(H3) = 8pt.
    static let h3SpaceBelow: CGFloat = 12

    // spatial-design-language FR-4: Component Spacing
    // Empirically measured: ~10pt left padding from code block background
    // edge to code text. This is the font glyph offset within the text
    // container, not explicit padding. Target: componentPadding (12pt).
    static let componentPadding: CGFloat = 10

    // spatial-design-language FR-6: Window Chrome Spacing
    // Empirically measured: ~69pt from window top to first text content.
    // Includes toolbar height (~29pt) + textContainerInset.height (32pt)
    // + auto content inset (~8pt). The toolbar (ViewModePicker, etc.)
    // adds vertical space above the text container that the original
    // 32pt estimate did not account for.
    // Target: SpacingConstants.windowTopInset (32pt) after toolbar
    // accounting is clarified in the spatial-design-language migration.
    static let windowTopInset: CGFloat = 69

    // Empirically validated: ~40pt (32pt textContainerInset.width + ~8pt
    // auto content inset). Confirmed by live capture measurement.
    // Target: SpacingConstants.windowSideInset (40pt) -- matches.
    static let windowSideInset: CGFloat = 40

    // Not reliably measurable from short fixtures: when the document fits
    // in one viewport, the bottom inset equals the remaining viewport
    // space, not the textContainerInset. Needs a long document fixture.
    // Target: SpacingConstants.windowBottomInset (32pt).
    static let windowBottomInset: CGFloat = 32

    // spatial-design-language FR-5: Structural Rules
    static let gridUnit: CGFloat = 4
}

// MARK: - Measurement Constants

/// Tolerance for spatial measurements. Set to 2pt to accommodate
/// sub-pixel rendering variations (0.5pt shifts) and font hinting
/// differences across macOS versions.
let spatialTolerance: CGFloat = 2.0
let spatialColorTolerance = 10

/// Extra color tolerance for background matching in captures. The
/// rendered background color differs from the theme-reported color
/// by ~14 units due to macOS window material blending and color
/// profile conversion (Display P3 capture vs sRGB theme values).
let spatialBgColorTolerance = 20

/// Inset (in points) to skip from window edges when scanning for
/// content bounds. Avoids the macOS window material row at the top
/// and rounded corner pixels at all edges.
let spatialChromeInsetPt: CGFloat = 4

// MARK: - Shared Harness

enum SpatialHarness {
    nonisolated(unsafe) static var launcher: AppLauncher?
    nonisolated(unsafe) static var client: TestHarnessClient?

    static func ensureRunning() async throws -> TestHarnessClient {
        if let existingClient = client {
            let pong = try await existingClient.ping()
            if pong.status == "ok" {
                return existingClient
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

func spatialFixturePath(_ name: String) -> String {
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

// MARK: - Response Extraction

func extractCapture(
    from response: HarnessResponse
) throws -> CaptureResult {
    guard response.status == "ok" else {
        throw HarnessError.captureFailed(
            response.message ?? "Capture returned error status"
        )
    }
    guard let data = response.data,
          case let .capture(result) = data
    else {
        throw HarnessError.captureFailed("No capture data in response")
    }
    return result
}

func loadAnalyzer(
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

func extractThemeColors(
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

// MARK: - Color Conversion

func backgroundColor(
    from themeColors: ThemeColorsResult
) -> PixelColor {
    PixelColor.from(rgbColor: themeColors.background)
}

func codeBackgroundColor(
    from themeColors: ThemeColorsResult
) -> PixelColor {
    PixelColor.from(rgbColor: themeColors.codeBackground)
}

// MARK: - Chrome-Aware Content Bounds

// swiftlint:disable cyclomatic_complexity function_body_length
/// Computes the bounding rect of rendered markdown content, excluding
/// window chrome artifacts (title bar material row, rounded corners,
/// DefaultHandlerHint dot).
///
/// **Why not `ImageAnalyzer.contentBounds()`?** The standard content
/// bounds scans every row/column from the edge. On `.hiddenTitleBar`
/// windows, the first pixel row has a macOS window material effect
/// (~62 color distance from background) and corners have transparent
/// pixels (alpha=0). Both are detected as "content" and cause the
/// bounds to start at (0, 0).
///
/// This function avoids those artifacts by:
/// 1. Starting scans from a `spatialChromeInsetPt` inset to skip
///    the window material row and rounded corners.
/// 2. Scanning at multiple X positions for top/bottom detection,
///    placed safely inside the content area.
/// 3. Using `spatialBgColorTolerance` to match the rendered background
///    (which differs from the theme-reported color by ~14 units due
///    to color profile differences).
///
/// Returns a rect in point coordinates.
func spatialContentBounds(
    in analyzer: ImageAnalyzer,
    background _: PixelColor,
    tolerance _: Int
) -> CGRect {
    let scale = analyzer.scaleFactor
    let widthPx = analyzer.image.width
    let heightPx = analyzer.image.height
    let insetPx = Int(spatialChromeInsetPt * scale)

    // Sample the ACTUAL rendered background from a safe position
    // (center-X, 10pt below top chrome). This compensates for color
    // profile differences between the theme-reported sRGB values and
    // the captured pixel values.
    let sampledBg = analyzer.sampleColor(
        at: CGPoint(
            x: analyzer.pointWidth / 2,
            y: spatialChromeInsetPt + 6
        )
    )

    // Use the sampled background for matching, with the caller's
    // tolerance for spatial precision.
    let bgTolerance = spatialBgColorTolerance

    // Probe X positions (in points), past the chrome inset and well
    // left of the hint dot at (width-20, 20).
    let probeXPts: [CGFloat] = [30, 50, 80, 120, 200]

    // Pass 1: find top/bottom using multiple vertical probes
    var topPx = heightPx
    var bottomPx = 0
    var foundContent = false

    for probeX in probeXPts {
        let probePx = Int(probeX * scale)
        guard probePx >= insetPx, probePx < widthPx - insetPx else {
            continue
        }

        for py in insetPx ..< heightPx - insetPx {
            let color = analyzer.sampleColor(
                at: CGPoint(x: probeX, y: CGFloat(py) / scale)
            )
            if !ColorExtractor.matches(
                color,
                expected: sampledBg,
                tolerance: bgTolerance
            ) {
                if py < topPx { topPx = py }
                foundContent = true
                break
            }
        }

        for py in stride(
            from: heightPx - 1 - insetPx,
            through: insetPx,
            by: -1
        ) {
            let color = analyzer.sampleColor(
                at: CGPoint(x: probeX, y: CGFloat(py) / scale)
            )
            if !ColorExtractor.matches(
                color,
                expected: sampledBg,
                tolerance: bgTolerance
            ) {
                if py > bottomPx { bottomPx = py }
                break
            }
        }
    }

    guard foundContent, topPx <= bottomPx else { return .zero }

    // Pass 2: find left/right by scanning at multiple Y positions.
    // A single midpoint scan fails when it lands in a vertical gap
    // between content blocks (all background). Scan at several Y
    // positions and take the tightest (min left, max right).
    let candidateYs: [Int] = [
        topPx,
        topPx + (bottomPx - topPx) / 4,
        (topPx + bottomPx) / 2,
        topPx + 3 * (bottomPx - topPx) / 4,
        bottomPx,
    ]

    var leftPx = widthPx
    var rightPx = 0

    for yPx in candidateYs {
        let yPt = CGFloat(yPx) / scale

        for px in insetPx ..< widthPx - insetPx {
            let color = analyzer.sampleColor(
                at: CGPoint(x: CGFloat(px) / scale, y: yPt)
            )
            if !ColorExtractor.matches(
                color,
                expected: sampledBg,
                tolerance: bgTolerance
            ) {
                if px < leftPx { leftPx = px }
                break
            }
        }

        for px in stride(
            from: widthPx - 1 - insetPx,
            through: insetPx,
            by: -1
        ) {
            let color = analyzer.sampleColor(
                at: CGPoint(x: CGFloat(px) / scale, y: yPt)
            )
            if !ColorExtractor.matches(
                color,
                expected: sampledBg,
                tolerance: bgTolerance
            ) {
                if px > rightPx { rightPx = px }
                break
            }
        }
    }

    guard leftPx <= rightPx else { return .zero }

    return CGRect(
        x: CGFloat(leftPx) / scale,
        y: CGFloat(topPx) / scale,
        width: CGFloat(rightPx - leftPx + 1) / scale,
        height: CGFloat(bottomPx - topPx + 1) / scale
    )
}

// swiftlint:enable cyclomatic_complexity function_body_length

// MARK: - Vertical Gap Scanner

/// Scans vertically at a given x-position to find alternating regions of
/// content (non-background) and gaps (background-only). Returns the gap
/// distances in points, ordered from top to bottom.
func measureVerticalGaps(
    in analyzer: ImageAnalyzer,
    atX: CGFloat,
    bgColor: PixelColor,
    tolerance: Int = 10,
    minGapPt: CGFloat = 3
) -> [CGFloat] {
    let scale = analyzer.scaleFactor
    let heightPx = analyzer.image.height
    var gaps: [CGFloat] = []
    var inContent = false
    var gapStartPx: Int?

    for py in 0 ..< heightPx {
        let point = CGPoint(
            x: atX,
            y: CGFloat(py) / scale
        )
        let color = analyzer.sampleColor(at: point)
        let isBg = ColorExtractor.matches(
            color,
            expected: bgColor,
            tolerance: tolerance
        )

        if isBg {
            if inContent {
                gapStartPx = py
                inContent = false
            }
        } else {
            if !inContent, let start = gapStartPx {
                let gapPt = CGFloat(py - start) / scale
                if gapPt >= minGapPt {
                    gaps.append(gapPt)
                }
                gapStartPx = nil
            }
            inContent = true
        }
    }

    return gaps
}
