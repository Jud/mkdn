import CryptoKit
import Foundation
import Testing

@testable import mkdnLib

// MARK: - PRD Namespace

/// Namespace marker for orb vision capture test utilities.
enum OrbVisionCapturePRD {}

// MARK: - Shared Harness

enum OrbVisionHarness {
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

enum OrbVisionConfig {
    static let fixtures = [
        "orb-crossfade.md",
    ]

    static let themes = [
        "solarizedDark",
        "solarizedLight",
    ]

    static let viewMode = "previewOnly"
    static let captureFPS = 30

    /// Duration for crossfade capture: 0.35s crossfade + margin.
    static let crossfadeDuration: TimeInterval = 2.0

    /// Duration for auto-reload capture: ~5s breathing cycle + reload + margin.
    static let autoReloadDuration: TimeInterval = 8.0
}

// MARK: - Fixture Paths

func orbVisionFixturePath(_ name: String) -> String {
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

func orbVisionProjectRoot() -> URL {
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

func orbVisionOutputDir() -> String {
    orbVisionProjectRoot()
        .appendingPathComponent(".rp1/work/verification/captures/orb")
        .path
}

// MARK: - Capture ID

func orbVisionStem(_ fixture: String) -> String {
    let url = URL(fileURLWithPath: fixture)
    return url.deletingPathExtension().lastPathComponent
}

func orbVisionCaptureId(
    fixture: String,
    theme: String,
    scenario: String
) -> String {
    "\(orbVisionStem(fixture))-\(theme)-\(scenario)-\(OrbVisionConfig.viewMode)"
}

// MARK: - SHA-256 Hash

func orbVisionImageHash(atPath path: String) throws -> String {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let digest = SHA256.hash(data: data)
    let hexString = digest.map { String(format: "%02x", $0) }.joined()
    return "sha256:\(hexString)"
}

// MARK: - Frame Capture Extraction

func orbVisionExtractFrameCapture(
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

struct OrbFrameSequenceEntry: Codable {
    let id: String
    let fixture: String
    let theme: String
    let scenario: String
    let viewMode: String
    let frameDir: String
    let frameCount: Int
    let fps: Int
    let duration: Double
    let framePaths: [String]
    let frameHashes: [String]
}

struct OrbCaptureManifest: Codable {
    let captureTimestamp: String
    let sequences: [OrbFrameSequenceEntry]
}

// MARK: - Manifest Writing

func orbVisionWriteManifest(
    entries: [OrbFrameSequenceEntry],
    to directory: String
) throws {
    let formatter = ISO8601DateFormatter()
    let manifest = OrbCaptureManifest(
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

// MARK: - Temporary Fixture Copy

/// Copies a fixture file to a temporary location so the test can
/// write to it on disk without modifying the source fixture.
func orbVisionCreateWorkingCopy(
    of fixturePath: String
) throws -> String {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("mkdn-orb-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: tempDir,
        withIntermediateDirectories: true
    )
    let sourceURL = URL(fileURLWithPath: fixturePath)
    let destURL = tempDir.appendingPathComponent(sourceURL.lastPathComponent)
    try FileManager.default.copyItem(at: sourceURL, to: destURL)
    return destURL.path
}

/// Appends content to a file on disk to trigger the FileWatcher.
func orbVisionTriggerFileChange(at path: String) throws {
    let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
    handle.seekToEndOfFile()
    let appendedContent = "\n\n<!-- file change trigger: \(Date()) -->\n"
    handle.write(Data(appendedContent.utf8))
    try handle.close()
}
