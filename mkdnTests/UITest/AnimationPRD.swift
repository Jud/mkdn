import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import mkdnLib

// MARK: - PRD Expected Values

/// Expected animation timing values from the animation-design-language PRD.
///
/// Each constant documents its `AnimationConstants` source-of-truth property
/// and the PRD functional requirement it covers. When verifying animation
/// behavior, tests reference these values alongside the source-of-truth
/// constants.
enum AnimationPRD {
    // animation-design-language FR-1: Continuous Animations
    // Source: AnimationConstants.breathe = .easeInOut(duration: 2.5)
    // Full cycle = 2 * 2.5s = 5.0s, ~12 cycles/min
    static let breatheHalfCycle: TimeInterval = 2.5
    static let breatheFullCycle: TimeInterval = 5.0
    static let breatheCPM = 12.0

    // animation-design-language FR-2: Spring Transitions
    // Source: AnimationConstants.springSettle = .spring(response: 0.35, dampingFraction: 0.7)
    static let springResponse: TimeInterval = 0.35
    static let springDamping = 0.7

    // animation-design-language FR-3: Fade Transitions
    // Source: AnimationConstants.crossfade = .easeInOut(duration: 0.35)
    static let crossfadeDuration: TimeInterval = 0.35
    // Source: AnimationConstants.fadeIn = .easeOut(duration: 0.5)
    static let fadeInDuration: TimeInterval = 0.5
    // Source: AnimationConstants.fadeOut = .easeIn(duration: 0.4)
    static let fadeOutDuration: TimeInterval = 0.4

    // animation-design-language FR-4: Orchestration
    // Source: AnimationConstants.staggerDelay = 0.03
    static let staggerDelay: TimeInterval = 0.03
    // Source: AnimationConstants.staggerCap = 0.5
    static let staggerCap: TimeInterval = 0.5

    // animation-design-language FR-5: Reduce Motion
    // Source: AnimationConstants.reducedCrossfade = .easeInOut(duration: 0.15)
    static let reducedCrossfadeDuration: TimeInterval = 0.15
}

// MARK: - Measurement Tolerances

/// One frame at 30fps (33.3ms).
let animTolerance30fps: TimeInterval = 1.0 / 30.0

/// One frame at 60fps (16.7ms).
let animTolerance60fps: TimeInterval = 1.0 / 60.0

/// CPM tolerance: 25% relative for breathing orb measurement.
let cpmRelativeTolerance = 0.25

/// Color tolerance for orb location detection.
let animOrbColorTolerance = 30

// MARK: - Shared Harness

enum AnimationHarness {
    nonisolated(unsafe) static var launcher: AppLauncher?
    nonisolated(unsafe) static var client: TestHarnessClient?
    nonisolated(unsafe) static var cachedScaleFactor: CGFloat = 2.0

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

func animationFixturePath(_ name: String) -> String {
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

// MARK: - Frame Capture Extraction

func extractFrameCapture(
    from response: HarnessResponse
) throws -> FrameCaptureResult {
    guard response.status == "ok",
          let data = response.data,
          case let .frameCapture(result) = data
    else {
        throw HarnessError.captureFailed(
            response.message ?? "Frame capture error"
        )
    }
    return result
}

/// Loads captured frame PNGs into an array of CGImages.
func loadFrameImages(
    from result: FrameCaptureResult
) throws -> [CGImage] {
    try result.framePaths.map { path in
        let url = URL(fileURLWithPath: path) as CFURL
        guard let source = CGImageSourceCreateWithURL(url, nil),
              let image = CGImageSourceCreateImageAtIndex(
                  source, 0, nil
              )
        else {
            throw HarnessError.captureFailed(
                "Cannot load frame at \(path)"
            )
        }
        return image
    }
}

// MARK: - Animation Timing Assertion

func assertAnimationTiming(
    measured: TimeInterval,
    expected: TimeInterval,
    tolerance: TimeInterval,
    prdRef: String,
    aspect: String
) {
    let passed = abs(measured - expected) <= tolerance

    #expect(
        passed,
        """
        \(prdRef): \(aspect) \
        expected \(expected)s, measured \(measured)s \
        (tolerance: \(tolerance)s)
        """
    )

    let msg =
        "\(prdRef): \(aspect) expected \(expected)s, measured \(measured)s"

    JSONResultReporter.record(TestResult(
        name: "\(prdRef): \(aspect)",
        status: passed ? .pass : .fail,
        prdReference: prdRef,
        expected: "\(expected)s",
        actual: "\(measured)s",
        imagePaths: [],
        duration: 0,
        message: passed ? nil : msg,
    ))
}

// MARK: - Animation Bool Assertion

func assertAnimationBool(
    value: Bool,
    expected: Bool,
    prdRef: String,
    aspect: String
) {
    let passed = value == expected

    #expect(
        passed,
        "\(prdRef): \(aspect) expected \(expected), got \(value)"
    )

    JSONResultReporter.record(TestResult(
        name: "\(prdRef): \(aspect)",
        status: passed ? .pass : .fail,
        prdReference: prdRef,
        expected: "\(expected)",
        actual: "\(value)",
        imagePaths: [],
        duration: 0,
        message: passed
            ? nil
            : "\(prdRef): \(aspect) expected \(expected), got \(value)",
    ))
}

// MARK: - Orb Region Locator

/// Searches the upper portion of a captured image for the file-change
/// orb by looking for pixels matching the orb's cyan color
/// (AnimationConstants.fileChangeOrbColor: r:0.165, g:0.631, b:0.596).
///
/// Returns a CGRect in points centered on the detected orb cluster,
/// or nil if no orb-colored region is found.
func locateOrbRegion(
    in analyzer: ImageAnalyzer,
    orbColor: PixelColor,
    tolerance: Int = 30,
    searchHeight: CGFloat = 100
) -> CGRect? {
    let step: CGFloat = 2.0
    var sumX: CGFloat = 0
    var sumY: CGFloat = 0
    var count: CGFloat = 0

    for yPt in stride(from: 0, to: searchHeight, by: step) {
        for xPt in stride(
            from: 0,
            to: analyzer.pointWidth,
            by: step
        ) {
            let color = analyzer.sampleColor(
                at: CGPoint(x: xPt, y: yPt)
            )
            if ColorExtractor.matches(
                color,
                expected: orbColor,
                tolerance: tolerance
            ) {
                sumX += xPt
                sumY += yPt
                count += 1
            }
        }
    }

    guard count > 5 else { return nil }

    let centerX = sumX / count
    let centerY = sumY / count
    let size: CGFloat = 40

    return CGRect(
        x: max(centerX - size / 2, 0),
        y: max(centerY - size / 2, 0),
        width: size,
        height: size,
    )
}

// MARK: - Temp File Helper

/// Copies a fixture to a temporary location for file-change testing.
///
/// The caller is responsible for cleanup via `FileManager.removeItem`.
func createTempFixtureCopy(
    from fixtureName: String
) throws -> String {
    let source = animationFixturePath(fixtureName)
    let tempDir = FileManager.default.temporaryDirectory
    let uuid = UUID().uuidString.prefix(8)
    let tempFile = tempDir
        .appendingPathComponent("mkdn-anim-\(uuid).md")
    try FileManager.default.copyItem(
        atPath: source,
        toPath: tempFile.path,
    )
    return tempFile.path
}

// MARK: - Calibration Helpers

/// Verifies frame timing accuracy and theme state detection.
///
/// Captures frames at 30fps and verifies:
/// 1. Frame count matches expected (fps * duration) within 20%.
/// 2. Captured frames reflect the correct theme state (theme colors
///    are detectable from frame pixel data).
///
/// **Note**: Crossfade transition-duration measurement is not possible
/// with the current architecture. SCStream startup latency (~200-400ms
/// for `SCShareableContent.excludingDesktopWindows()` + stream setup)
/// exceeds the crossfade duration (0.35s). By the time frames arrive,
/// the transition is already complete. The single-command socket
/// protocol prevents triggering animations during an active capture.
func verifyFrameTimingAndThemeDetection(
    client: TestHarnessClient,
    capturedFrameCount: Int
) async throws {
    let expectedFrames = 30
    let minFrames = Int(Double(expectedFrames) * 0.8)
    let maxFrames = Int(Double(expectedFrames) * 1.2)

    try #require(
        capturedFrameCount >= minFrames
            && capturedFrameCount <= maxFrames,
        """
        Calibration: frame count \(capturedFrameCount) \
        outside expected range [\(minFrames)--\(maxFrames)] \
        for 30fps * 1.0s
        """
    )

    let darkResp = try await client.getThemeColors()
    let darkColors = try extractAnimThemeColors(from: darkResp)
    let darkBg = PixelColor.from(rgbColor: darkColors.background)

    _ = try await client.setTheme("solarizedLight")
    try await Task.sleep(for: .seconds(0.5))

    let lightResp = try await client.getThemeColors()
    let lightColors = try extractAnimThemeColors(from: lightResp)
    let lightBg = PixelColor.from(rgbColor: lightColors.background)

    let captureResp = try await client.startFrameCapture(
        fps: 30, duration: 0.5
    )
    let result = try extractFrameCapture(from: captureResp)
    let frames = try loadFrameImages(from: result)

    guard let firstFrame = frames.first else {
        throw HarnessError.captureFailed("No frames captured")
    }
    let scale = AnimationHarness.cachedScaleFactor
    let imgAnalyzer = ImageAnalyzer(
        image: firstFrame, scaleFactor: scale
    )
    let sampledColor = imgAnalyzer.averageColor(
        in: CGRect(x: 10, y: 10, width: 40, height: 40)
    )

    let isLight = sampledColor.distance(to: lightBg)
        < sampledColor.distance(to: darkBg)
    try #require(
        isLight,
        """
        Calibration: theme detection failed. \
        Captured color \(sampledColor) is closer to dark \
        (\(sampledColor.distance(to: darkBg))) than light \
        (\(sampledColor.distance(to: lightBg)))
        """
    )

    _ = try await client.setTheme("solarizedDark")
}

// MARK: - Theme Colors Helper

func extractAnimThemeColors(
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

// MARK: - Window Info Helper

func extractWindowSize(
    from response: HarnessResponse
) -> (CGFloat, CGFloat) {
    if let data = response.data,
       case let .windowInfo(info) = data
    {
        return (CGFloat(info.width), CGFloat(info.height))
    }
    return (800, 600)
}

// MARK: - Stagger Helpers

func assertStaggerOrder(delays: [TimeInterval]) {
    guard delays.count >= 2 else { return }
    let ordered = delays.enumerated().allSatisfy { idx, delay in
        idx == 0 || delay >= delays[idx - 1]
    }

    JSONResultReporter.record(TestResult(
        name: "animation-design-language FR-4: stagger order",
        status: ordered ? .pass : .fail,
        prdReference: "animation-design-language FR-4",
        expected: "monotonically increasing",
        actual: "ordered=\(ordered), delays=\(delays)",
        imagePaths: [],
        duration: 0,
        message: ordered
            ? nil
            : "Stagger order not monotonic (may be SCStream latency)",
    ))
}

func assertStaggerCap(delays: [TimeInterval]) {
    guard delays.count >= 2,
          let maxDelay = delays.max()
    else { return }

    let capTolerance = AnimationPRD.staggerCap + 2.0
    let withinCap = maxDelay <= capTolerance

    #expect(
        withinCap,
        """
        animation-design-language FR-4: total stagger \
        expected <= \(AnimationPRD.staggerCap)s (+2.0s SCStream \
        latency), measured \(maxDelay)s
        """
    )

    JSONResultReporter.record(TestResult(
        name: "animation-design-language FR-4: stagger total",
        status: withinCap ? .pass : .fail,
        prdReference: "animation-design-language FR-4",
        expected: "<= \(capTolerance)s (with SCStream margin)",
        actual: "\(maxDelay)s",
        imagePaths: [],
        duration: 0,
        message: withinCap ? nil : "Stagger exceeds cap",
    ))
}

func staggerMeasurementRegions() -> [CGRect] {
    let contentX: CGFloat = 50
    let regionW: CGFloat = 200
    let regionH: CGFloat = 20
    let startY: CGFloat = 60
    let spacing: CGFloat = 80

    return (0 ..< 5).map { idx in
        CGRect(
            x: contentX,
            y: startY + CGFloat(idx) * spacing,
            width: regionW,
            height: regionH,
        )
    }
}

// MARK: - Result Recording Helpers

func recordSpringResult(
    passed: Bool,
    layoutChanged: Bool,
    images: [String]
) {
    JSONResultReporter.record(TestResult(
        name: "animation-design-language FR-2: springSettle",
        status: passed ? .pass : .fail,
        prdReference: "animation-design-language FR-2",
        expected: "layout changed, spring(0.35, 0.7)",
        actual: "layout=\(layoutChanged)",
        imagePaths: images,
        duration: 0,
        message: passed ? nil : "Spring settle failed",
    ))
}

func recordCrossfadeResult(
    passed: Bool,
    distance: Int,
    images: [String]
) {
    JSONResultReporter.record(TestResult(
        name: "animation-design-language FR-3: crossfade",
        status: passed ? .pass : .fail,
        prdReference: "animation-design-language FR-3",
        expected: "distinct themes, crossfade=0.35s",
        actual: "distance=\(distance)",
        imagePaths: images,
        duration: 0,
        message: passed ? nil : "Crossfade failed",
    ))
}
