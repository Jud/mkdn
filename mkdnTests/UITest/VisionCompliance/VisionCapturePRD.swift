import CryptoKit
import Foundation
import Testing

@testable import mkdnLib

// MARK: - PRD Namespace

/// Namespace marker for vision capture test utilities.
enum VisionCapturePRD {}

// MARK: - Shared Harness

enum VisionCaptureHarness {
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

enum VisionCaptureConfig {
    static let fixtures = [
        "geometry-calibration.md",
        "theme-tokens.md",
        "canonical.md",
        "mermaid-focus.md",
    ]

    static let themes = [
        "solarizedDark",
        "solarizedLight",
    ]

    static let viewMode = "previewOnly"
}

// MARK: - Fixture Paths

func visionCaptureFixturePath(_ name: String) -> String {
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

func visionCaptureProjectRoot() -> URL {
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

func visionCaptureOutputDir() -> String {
    visionCaptureProjectRoot()
        .appendingPathComponent(".rp1/work/verification/captures")
        .path
}

// MARK: - Capture ID

func visionCaptureStem(_ fixture: String) -> String {
    let url = URL(fileURLWithPath: fixture)
    return url.deletingPathExtension().lastPathComponent
}

func visionCaptureId(fixture: String, theme: String) -> String {
    "\(visionCaptureStem(fixture))-\(theme)-\(VisionCaptureConfig.viewMode)"
}

// MARK: - SHA-256 Hash

func visionCaptureImageHash(atPath path: String) throws -> String {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let digest = SHA256.hash(data: data)
    let hexString = digest.map { String(format: "%02x", $0) }.joined()
    return "sha256:\(hexString)"
}

// MARK: - Capture Extraction

enum VisionCaptureExtract {
    static func extractResult(
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
}

// MARK: - Manifest Types

struct CaptureManifestEntry: Codable {
    let id: String
    let imagePath: String
    let fixture: String
    let theme: String
    let viewMode: String
    let width: Int
    let height: Int
    let scaleFactor: Double
    let imageHash: String
}

struct CaptureManifest: Codable {
    let captureTimestamp: String
    let captures: [CaptureManifestEntry]
}

// MARK: - Manifest Writing

func visionCaptureWriteManifest(
    entries: [CaptureManifestEntry],
    to directory: String
) throws {
    let formatter = ISO8601DateFormatter()
    let manifest = CaptureManifest(
        captureTimestamp: formatter.string(from: Date()),
        captures: entries
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(manifest)

    let manifestURL = URL(fileURLWithPath: directory)
        .appendingPathComponent("manifest.json")
    try data.write(to: manifestURL)
}
