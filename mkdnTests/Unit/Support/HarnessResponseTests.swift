import Foundation
import Testing
@testable import mkdnLib

@Suite("HarnessResponse")
struct HarnessResponseTests {
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

    // MARK: - Basic Responses

    @Test("Success response with no data round-trips through JSON")
    func okResponseRoundTrip() throws {
        let response = HarnessResponse.ok(message: "File loaded")
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(HarnessResponse.self, from: data)
        #expect(decoded.status == "ok")
        #expect(decoded.message == "File loaded")
        #expect(decoded.data == nil)
    }

    @Test("Error response round-trips through JSON")
    func errorResponseRoundTrip() throws {
        let response = HarnessResponse.error("File not found")
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(HarnessResponse.self, from: data)
        #expect(decoded.status == "error")
        #expect(decoded.message == "File not found")
        #expect(decoded.data == nil)
    }

    @Test("Pong response round-trips through JSON")
    func pongResponseRoundTrip() throws {
        let response = HarnessResponse.ok(data: .pong)
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(HarnessResponse.self, from: data)
        #expect(decoded.status == "ok")
        guard case .pong = decoded.data else {
            Issue.record("Expected .pong data, got \(String(describing: decoded.data))")
            return
        }
    }

    // MARK: - Capture Result

    @Test("Response with capture data round-trips through JSON")
    func captureResponseRoundTrip() throws {
        let captureResult = CaptureResult(
            imagePath: "/tmp/capture-001.png",
            width: 2_560,
            height: 1_600,
            scaleFactor: 2.0,
            timestamp: Date(timeIntervalSince1970: 1_738_000_000),
            theme: "solarizedDark",
            viewMode: "previewOnly"
        )
        let response = HarnessResponse.ok(data: .capture(captureResult))
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(HarnessResponse.self, from: data)

        #expect(decoded.status == "ok")
        guard case let .capture(result) = decoded.data else {
            Issue.record("Expected .capture data, got \(String(describing: decoded.data))")
            return
        }
        #expect(result.imagePath == "/tmp/capture-001.png")
        #expect(result.width == 2_560)
        #expect(result.height == 1_600)
        #expect(result.scaleFactor == 2.0)
        #expect(result.theme == "solarizedDark")
        #expect(result.viewMode == "previewOnly")
    }

    // MARK: - Frame Capture Result

    @Test("Response with frame capture data round-trips through JSON")
    func frameCaptureResponseRoundTrip() throws {
        let frameResult = FrameCaptureResult(
            frameDir: "/tmp/frames",
            frameCount: 150,
            fps: 30,
            duration: 5.0,
            framePaths: ["/tmp/frames/frame_0001.png", "/tmp/frames/frame_0002.png"]
        )
        let response = HarnessResponse.ok(data: .frameCapture(frameResult))
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(HarnessResponse.self, from: data)

        guard case let .frameCapture(result) = decoded.data else {
            Issue.record("Expected .frameCapture data, got \(String(describing: decoded.data))")
            return
        }
        #expect(result.frameDir == "/tmp/frames")
        #expect(result.frameCount == 150)
        #expect(result.fps == 30)
        #expect(result.duration == 5.0)
        #expect(result.framePaths.count == 2)
    }

    // MARK: - Window Info Result

    @Test("Response with window info data round-trips through JSON")
    func windowInfoResponseRoundTrip() throws {
        let windowInfo = WindowInfoResult(
            width: 1_280,
            height: 800,
            x: 100,
            y: 200,
            scaleFactor: 2.0,
            theme: "solarizedLight",
            viewMode: "sideBySide",
            currentFilePath: "/Users/test/doc.md"
        )
        let response = HarnessResponse.ok(data: .windowInfo(windowInfo))
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(HarnessResponse.self, from: data)

        guard case let .windowInfo(result) = decoded.data else {
            Issue.record("Expected .windowInfo data, got \(String(describing: decoded.data))")
            return
        }
        #expect(result.width == 1_280)
        #expect(result.height == 800)
        #expect(result.scaleFactor == 2.0)
        #expect(result.theme == "solarizedLight")
        #expect(result.viewMode == "sideBySide")
        #expect(result.currentFilePath == "/Users/test/doc.md")
    }

    @Test("Response with nil currentFilePath round-trips through JSON")
    func windowInfoNilFilePathRoundTrip() throws {
        let windowInfo = WindowInfoResult(
            width: 1_280,
            height: 800,
            x: 0,
            y: 0,
            scaleFactor: 2.0,
            theme: "solarizedDark",
            viewMode: "previewOnly",
            currentFilePath: nil
        )
        let response = HarnessResponse.ok(data: .windowInfo(windowInfo))
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(HarnessResponse.self, from: data)

        guard case let .windowInfo(result) = decoded.data else {
            Issue.record("Expected .windowInfo data")
            return
        }
        #expect(result.currentFilePath == nil)
    }

    // MARK: - Theme Colors Result

    @Test("Response with theme colors data round-trips through JSON")
    func themeColorsResponseRoundTrip() throws {
        let colors = ThemeColorsResult(
            themeName: "solarizedDark",
            background: RGBColor(red: 0.0, green: 0.169, blue: 0.212),
            backgroundSecondary: RGBColor(red: 0.027, green: 0.212, blue: 0.259),
            foreground: RGBColor(red: 0.514, green: 0.580, blue: 0.588),
            foregroundSecondary: RGBColor(red: 0.396, green: 0.482, blue: 0.514),
            accent: RGBColor(red: 0.149, green: 0.545, blue: 0.824),
            headingColor: RGBColor(red: 0.522, green: 0.600, blue: 0.000),
            codeBackground: RGBColor(red: 0.027, green: 0.212, blue: 0.259),
            codeForeground: RGBColor(red: 0.514, green: 0.580, blue: 0.588),
            linkColor: RGBColor(red: 0.149, green: 0.545, blue: 0.824)
        )
        let response = HarnessResponse.ok(data: .themeColors(colors))
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(HarnessResponse.self, from: data)

        guard case let .themeColors(result) = decoded.data else {
            Issue.record("Expected .themeColors data, got \(String(describing: decoded.data))")
            return
        }
        #expect(result.themeName == "solarizedDark")
        #expect(result.background.red == 0.0)
        #expect(result.background.green == 0.169)
        #expect(result.background.blue == 0.212)
    }

    // MARK: - Wire Format

    @Test("Response encodes to single-line JSON suitable for line-delimited protocol")
    func responseSingleLineJSON() throws {
        let response = HarnessResponse.ok(data: .pong, message: "alive")
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = []
        let data = try jsonEncoder.encode(response)
        let jsonString = try #require(String(data: data, encoding: .utf8))
        #expect(!jsonString.contains("\n"))
    }

    // MARK: - Value Types

    @Test("CaptureRegion preserves all coordinate values")
    func captureRegionValues() {
        let region = CaptureRegion(x: 10.5, y: 20.25, width: 100.75, height: 200.0)
        #expect(region.x == 10.5)
        #expect(region.y == 20.25)
        #expect(region.width == 100.75)
        #expect(region.height == 200.0)
    }

    @Test("CaptureRegion equality")
    func captureRegionEquality() {
        let region1 = CaptureRegion(x: 10, y: 20, width: 100, height: 200)
        let region2 = CaptureRegion(x: 10, y: 20, width: 100, height: 200)
        let region3 = CaptureRegion(x: 10, y: 20, width: 100, height: 201)
        #expect(region1 == region2)
        #expect(region1 != region3)
    }

    @Test("RGBColor preserves component values")
    func rgbColorValues() {
        let color = RGBColor(red: 0.5, green: 0.75, blue: 1.0)
        #expect(color.red == 0.5)
        #expect(color.green == 0.75)
        #expect(color.blue == 1.0)
    }

    @Test("RGBColor equality")
    func rgbColorEquality() {
        let color1 = RGBColor(red: 0.5, green: 0.75, blue: 1.0)
        let color2 = RGBColor(red: 0.5, green: 0.75, blue: 1.0)
        let color3 = RGBColor(red: 0.5, green: 0.75, blue: 0.9)
        #expect(color1 == color2)
        #expect(color1 != color3)
    }

    // MARK: - HarnessSocket

    @Test("Socket path includes PID")
    func socketPathIncludesPID() {
        let path = HarnessSocket.path(forPID: 12_345)
        #expect(path == "/tmp/mkdn-test-harness-12345.sock")
    }

    @Test("Current socket path uses process PID")
    func currentSocketPathUsesPID() {
        let expected = "/tmp/mkdn-test-harness-\(ProcessInfo.processInfo.processIdentifier).sock"
        #expect(HarnessSocket.currentPath == expected)
    }

    // MARK: - HarnessError

    @Test("HarnessError.renderTimeout has descriptive message")
    func renderTimeoutDescription() {
        let error = HarnessError.renderTimeout
        #expect(error.errorDescription?.contains("timeout") == true)
    }

    @Test("HarnessError.connectionFailed includes detail")
    func connectionFailedDescription() {
        let error = HarnessError.connectionFailed("ECONNREFUSED")
        #expect(error.errorDescription?.contains("ECONNREFUSED") == true)
    }

    @Test("HarnessError.captureFailed includes detail")
    func captureFailedDescription() {
        let error = HarnessError.captureFailed("no window")
        #expect(error.errorDescription?.contains("no window") == true)
    }
}
