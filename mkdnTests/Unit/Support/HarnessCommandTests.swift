import Foundation
import Testing

@testable import mkdnLib

// MARK: - Command Tests

@Suite("HarnessCommand")
struct HarnessCommandTests {
    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = .sortedKeys
        return enc
    }()

    private let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()

    @Test("loadFile command round-trips through JSON")
    func loadFileRoundTrip() throws {
        let command = HarnessCommand.loadFile(path: "/tmp/test.md")
        let data = try encoder.encode(command)
        let decoded = try decoder.decode(HarnessCommand.self, from: data)
        guard case let .loadFile(path) = decoded else {
            Issue.record("Expected .loadFile, got \(decoded)")
            return
        }
        #expect(path == "/tmp/test.md")
    }

    @Test("switchMode command round-trips through JSON")
    func switchModeRoundTrip() throws {
        let command = HarnessCommand.switchMode(mode: "previewOnly")
        let data = try encoder.encode(command)
        let decoded = try decoder.decode(HarnessCommand.self, from: data)
        guard case let .switchMode(mode) = decoded else {
            Issue.record("Expected .switchMode, got \(decoded)")
            return
        }
        #expect(mode == "previewOnly")
    }

    @Test("cycleTheme command round-trips through JSON")
    func cycleThemeRoundTrip() throws {
        let command = HarnessCommand.cycleTheme
        let data = try encoder.encode(command)
        let decoded = try decoder.decode(HarnessCommand.self, from: data)
        guard case .cycleTheme = decoded else {
            Issue.record("Expected .cycleTheme, got \(decoded)")
            return
        }
    }

    @Test("setTheme command round-trips through JSON")
    func setThemeRoundTrip() throws {
        let command = HarnessCommand.setTheme(theme: "solarizedDark")
        let data = try encoder.encode(command)
        let decoded = try decoder.decode(HarnessCommand.self, from: data)
        guard case let .setTheme(theme) = decoded else {
            Issue.record("Expected .setTheme, got \(decoded)")
            return
        }
        #expect(theme == "solarizedDark")
    }

    @Test("reloadFile command round-trips through JSON")
    func reloadFileRoundTrip() throws {
        let command = HarnessCommand.reloadFile
        let data = try encoder.encode(command)
        let decoded = try decoder.decode(HarnessCommand.self, from: data)
        guard case .reloadFile = decoded else {
            Issue.record("Expected .reloadFile, got \(decoded)")
            return
        }
    }

    @Test("captureWindow command with output path round-trips through JSON")
    func captureWindowWithPathRoundTrip() throws {
        let command = HarnessCommand.captureWindow(outputPath: "/tmp/capture.png")
        let data = try encoder.encode(command)
        let decoded = try decoder.decode(HarnessCommand.self, from: data)
        guard case let .captureWindow(outputPath) = decoded else {
            Issue.record("Expected .captureWindow, got \(decoded)")
            return
        }
        #expect(outputPath == "/tmp/capture.png")
    }

    @Test("captureWindow command with nil output path round-trips through JSON")
    func captureWindowNilPathRoundTrip() throws {
        let command = HarnessCommand.captureWindow(outputPath: nil)
        let data = try encoder.encode(command)
        let decoded = try decoder.decode(HarnessCommand.self, from: data)
        guard case let .captureWindow(outputPath) = decoded else {
            Issue.record("Expected .captureWindow, got \(decoded)")
            return
        }
        #expect(outputPath == nil)
    }

    @Test("captureRegion command round-trips through JSON")
    func captureRegionRoundTrip() throws {
        let region = CaptureRegion(x: 10, y: 20, width: 100, height: 200)
        let command = HarnessCommand.captureRegion(region: region, outputPath: "/tmp/region.png")
        let data = try encoder.encode(command)
        let decoded = try decoder.decode(HarnessCommand.self, from: data)
        guard case let .captureRegion(decodedRegion, outputPath) = decoded else {
            Issue.record("Expected .captureRegion, got \(decoded)")
            return
        }
        #expect(decodedRegion == region)
        #expect(outputPath == "/tmp/region.png")
    }

    @Test("startFrameCapture command round-trips through JSON")
    func startFrameCaptureRoundTrip() throws {
        let command = HarnessCommand.startFrameCapture(fps: 60, duration: 5.0, outputDir: "/tmp/frames")
        let data = try encoder.encode(command)
        let decoded = try decoder.decode(HarnessCommand.self, from: data)
        guard case let .startFrameCapture(fps, duration, outputDir) = decoded else {
            Issue.record("Expected .startFrameCapture, got \(decoded)")
            return
        }
        #expect(fps == 60)
        #expect(duration == 5.0)
        #expect(outputDir == "/tmp/frames")
    }

    @Test("stopFrameCapture command round-trips through JSON")
    func stopFrameCaptureRoundTrip() throws {
        let command = HarnessCommand.stopFrameCapture
        let data = try encoder.encode(command)
        let decoded = try decoder.decode(HarnessCommand.self, from: data)
        guard case .stopFrameCapture = decoded else {
            Issue.record("Expected .stopFrameCapture, got \(decoded)")
            return
        }
    }

    @Test("getWindowInfo command round-trips through JSON")
    func getWindowInfoRoundTrip() throws {
        let command = HarnessCommand.getWindowInfo
        let data = try encoder.encode(command)
        let decoded = try decoder.decode(HarnessCommand.self, from: data)
        guard case .getWindowInfo = decoded else {
            Issue.record("Expected .getWindowInfo, got \(decoded)")
            return
        }
    }

    @Test("getThemeColors command round-trips through JSON")
    func getThemeColorsRoundTrip() throws {
        let command = HarnessCommand.getThemeColors
        let data = try encoder.encode(command)
        let decoded = try decoder.decode(HarnessCommand.self, from: data)
        guard case .getThemeColors = decoded else {
            Issue.record("Expected .getThemeColors, got \(decoded)")
            return
        }
    }

    @Test("setReduceMotion command round-trips through JSON")
    func setReduceMotionRoundTrip() throws {
        let command = HarnessCommand.setReduceMotion(enabled: true)
        let data = try encoder.encode(command)
        let decoded = try decoder.decode(HarnessCommand.self, from: data)
        guard case let .setReduceMotion(enabled) = decoded else {
            Issue.record("Expected .setReduceMotion, got \(decoded)")
            return
        }
        #expect(enabled == true)
    }

    @Test("ping command round-trips through JSON")
    func pingRoundTrip() throws {
        let command = HarnessCommand.ping
        let data = try encoder.encode(command)
        let decoded = try decoder.decode(HarnessCommand.self, from: data)
        guard case .ping = decoded else {
            Issue.record("Expected .ping, got \(decoded)")
            return
        }
    }

    @Test("quit command round-trips through JSON")
    func quitRoundTrip() throws {
        let command = HarnessCommand.quit
        let data = try encoder.encode(command)
        let decoded = try decoder.decode(HarnessCommand.self, from: data)
        guard case .quit = decoded else {
            Issue.record("Expected .quit, got \(decoded)")
            return
        }
    }

    @Test("Command encodes to single-line JSON suitable for line-delimited protocol")
    func commandSingleLineJSON() throws {
        let command = HarnessCommand.loadFile(path: "/tmp/test.md")
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = []
        let data = try jsonEncoder.encode(command)
        let jsonString = try #require(String(data: data, encoding: .utf8))
        #expect(!jsonString.contains("\n"))
    }
}
