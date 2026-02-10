import CryptoKit
import Foundation
import Testing

@testable import mkdnLib

// MARK: - PRD Namespace

/// Namespace marker for mermaid fade-in capture test utilities.
enum MermaidFadeInCapturePRD {}

// MARK: - Shared Harness

enum MermaidFadeInHarness {
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

enum MermaidFadeInConfig {
    static let fixtures = [
        "mermaid-fadein.md",
    ]

    static let themes = [
        "solarizedDark",
        "solarizedLight",
    ]

    static let motionModes = [
        "normal",
        "reduceMotion",
    ]

    static let viewMode = "previewOnly"
    static let captureFPS = 30
    static let captureDuration: TimeInterval = 8.0
}

// MARK: - Fixture Paths

func mermaidFadeInFixturePath(_ name: String) -> String {
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

func mermaidFadeInProjectRoot() -> URL {
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

func mermaidFadeInOutputDir() -> String {
    mermaidFadeInProjectRoot()
        .appendingPathComponent(".rp1/work/verification/captures/mermaid-fadein")
        .path
}

// MARK: - Capture ID

func mermaidFadeInStem(_ fixture: String) -> String {
    let url = URL(fileURLWithPath: fixture)
    return url.deletingPathExtension().lastPathComponent
}

func mermaidFadeInCaptureId(
    fixture: String,
    theme: String,
    motionMode: String
) -> String {
    "\(mermaidFadeInStem(fixture))-\(theme)-\(motionMode)-\(MermaidFadeInConfig.viewMode)"
}

// MARK: - SHA-256 Hash

func mermaidFadeInImageHash(atPath path: String) throws -> String {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let digest = SHA256.hash(data: data)
    let hexString = digest.map { String(format: "%02x", $0) }.joined()
    return "sha256:\(hexString)"
}

// MARK: - Frame Capture Extraction

func mermaidFadeInExtractFrameCapture(
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

// MARK: - Manifest Types

struct MermaidFadeInFrameSequenceEntry: Codable {
    let id: String
    let fixture: String
    let theme: String
    let motionMode: String
    let viewMode: String
    let frameDir: String
    let frameCount: Int
    let fps: Int
    let duration: Double
    let framePaths: [String]
    let frameHashes: [String]
}

struct MermaidFadeInCaptureManifest: Codable {
    let captureTimestamp: String
    let sequences: [MermaidFadeInFrameSequenceEntry]
}

// MARK: - Manifest Writing

func mermaidFadeInWriteManifest(
    entries: [MermaidFadeInFrameSequenceEntry],
    to directory: String
) throws {
    let formatter = ISO8601DateFormatter()
    let manifest = MermaidFadeInCaptureManifest(
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
