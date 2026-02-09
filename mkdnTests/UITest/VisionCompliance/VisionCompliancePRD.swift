import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import mkdnLib

// MARK: - PRD Namespace

/// Namespace marker for vision compliance test utilities.
///
/// Generated tests produced by `generate-tests.sh` share this
/// harness, fixture path resolution, and extraction helpers.
enum VisionCompliancePRD {}

// MARK: - Shared Harness

/// Shared app instance for vision-detected compliance tests.
///
/// Follows the same singleton pattern as `SpatialHarness`,
/// `VisualHarness`, and `AnimationHarness`. Each generated test
/// suite uses this harness to avoid launching multiple app
/// instances.
enum VisionComplianceHarness {
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

/// Resolves the absolute path to a UI test fixture file.
///
/// Walks up from the current source file to find the project root,
/// then constructs the path into `mkdnTests/Fixtures/UITest/`.
func visionFixturePath(_ name: String) -> String {
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

// MARK: - Capture Extraction

/// Extracts a `CaptureResult` from a harness response.
///
/// Validates the response status and data payload, throwing
/// `HarnessError.captureFailed` if the response does not contain
/// capture data.
func visionExtractCapture(
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

/// Creates an `ImageAnalyzer` from a `CaptureResult`.
///
/// Loads the PNG image at the capture's `imagePath` and initializes
/// an analyzer with the capture's scale factor for point-to-pixel
/// coordinate conversion.
func visionLoadAnalyzer(
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
