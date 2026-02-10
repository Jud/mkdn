import CryptoKit
import Foundation
import Testing

@testable import mkdnLib

// MARK: - PRD Namespace

/// Namespace marker for animation vision capture test utilities.
enum AnimationVisionCapturePRD {}

// MARK: - Shared Harness

enum AnimationVisionHarness {
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

// MARK: - Capture Configuration

enum AnimationVisionConfig {
    static let fixtures = [
        "anim-headings.md",
        "anim-blockquotes.md",
        "anim-code-swift.md",
        "anim-code-python.md",
        "anim-code-mixed.md",
        "anim-inline-code.md",
    ]

    static let themes = [
        "solarizedDark",
        "solarizedLight",
    ]

    static let viewMode = "previewOnly"
    static let captureFPS = 30
    static let captureDuration: TimeInterval = 3.0
}

// MARK: - Fixture Paths

func animationVisionFixturePath(_ name: String) -> String {
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

// MARK: - Output Directory

func animationVisionProjectRoot() -> URL {
    var url = URL(fileURLWithPath: #filePath)
    while url.path != "/" {
        url = url.deletingLastPathComponent()
        let marker = url.appendingPathComponent("Package.swift")
        if FileManager.default.fileExists(atPath: marker.path) {
            return url
        }
    }
    preconditionFailure("Package.swift not found")
}

func animationVisionOutputDir() -> String {
    animationVisionProjectRoot()
        .appendingPathComponent(".rp1/work/verification/captures/animation")
        .path
}

// MARK: - Capture ID

func animationVisionStem(_ fixture: String) -> String {
    let url = URL(fileURLWithPath: fixture)
    return url.deletingPathExtension().lastPathComponent
}

func animationVisionCaptureId(fixture: String, theme: String) -> String {
    "\(animationVisionStem(fixture))-\(theme)-\(AnimationVisionConfig.viewMode)"
}

// MARK: - SHA-256 Hash

func animationVisionImageHash(atPath path: String) throws -> String {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let digest = SHA256.hash(data: data)
    let hexString = digest.map { String(format: "%02x", $0) }.joined()
    return "sha256:\(hexString)"
}

// MARK: - Frame Capture Extraction

func animationVisionExtractFrameCapture(
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

// MARK: - Animation Manifest Types

struct AnimationFrameSequenceEntry: Codable {
    let id: String
    let fixture: String
    let theme: String
    let viewMode: String
    let frameDir: String
    let frameCount: Int
    let fps: Int
    let duration: Double
    let framePaths: [String]
    let frameHashes: [String]
}

struct AnimationCaptureManifest: Codable {
    let captureTimestamp: String
    let sequences: [AnimationFrameSequenceEntry]
}

// MARK: - Manifest Writing

func animationVisionWriteManifest(
    entries: [AnimationFrameSequenceEntry],
    to directory: String
) throws {
    let formatter = ISO8601DateFormatter()
    let manifest = AnimationCaptureManifest(
        captureTimestamp: formatter.string(from: Date()),
        sequences: entries
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(manifest)

    let manifestURL = URL(fileURLWithPath: directory)
        .appendingPathComponent("manifest.json")
    try data.write(to: manifestURL)
}
