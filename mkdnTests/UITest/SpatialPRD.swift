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
    // Future: SpacingConstants.documentMargin
    static let documentMargin: CGFloat = 32

    // Future: SpacingConstants.contentMaxWidth
    static let contentMaxWidth: CGFloat = 680

    // Future: SpacingConstants.blockSpacing
    static let blockSpacing: CGFloat = 16

    // spatial-design-language FR-3: Typography Spacing
    // Future: SpacingConstants.headingSpaceAbove(H1) = generous (48pt)
    static let h1SpaceAbove: CGFloat = 48

    // Future: SpacingConstants.headingSpaceBelow(H1) = standard (16pt)
    static let h1SpaceBelow: CGFloat = 16

    // Future: SpacingConstants.headingSpaceAbove(H2) = spacious (32pt)
    static let h2SpaceAbove: CGFloat = 32

    // Future: SpacingConstants.headingSpaceBelow(H2) = cozy (12pt)
    static let h2SpaceBelow: CGFloat = 12

    // Future: SpacingConstants.headingSpaceAbove(H3) = relaxed (24pt)
    static let h3SpaceAbove: CGFloat = 24

    // Future: SpacingConstants.headingSpaceBelow(H3) = compact (8pt)
    static let h3SpaceBelow: CGFloat = 8

    // spatial-design-language FR-4: Component Spacing
    // Future: SpacingConstants.componentPadding
    static let componentPadding: CGFloat = 12

    // spatial-design-language FR-6: Window Chrome Spacing
    // Future: SpacingConstants.windowTopInset
    static let windowTopInset: CGFloat = 32

    // Future: SpacingConstants.windowSideInset
    static let windowSideInset: CGFloat = 32

    // Future: SpacingConstants.windowBottomInset
    static let windowBottomInset: CGFloat = 24

    // spatial-design-language FR-5: Structural Rules
    static let gridUnit: CGFloat = 4
}

// MARK: - Measurement Constants

let spatialTolerance: CGFloat = 1.0
let spatialColorTolerance = 10

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
        let newClient = try await newLauncher.launch()
        launcher = newLauncher
        client = newClient
        return newClient
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
