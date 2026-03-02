#if os(macOS)
    import AppKit
    import SwiftUI

    extension TestHarnessHandler {
        // MARK: - Capture Command Dispatch

        static func processCapture(
            _ command: HarnessCommand
        ) async -> HarnessResponse {
            switch command {
            case let .captureWindow(outputPath):
                handleCaptureWindow(outputPath)
            case let .captureRegion(region, outputPath):
                handleCaptureRegion(region, outputPath)
            case let .startFrameCapture(fps, duration, outputDir):
                await handleStartFrameCapture(fps, duration, outputDir)
            case .stopFrameCapture:
                handleStopFrameCapture()
            case let .beginFrameCapture(fps, outputDir):
                await handleBeginFrameCapture(fps, outputDir)
            case .endFrameCapture:
                await handleEndFrameCapture()
            default:
                .error("Unknown capture command")
            }
        }

        // MARK: - Capture Commands

        private static func handleCaptureWindow(
            _ outputPath: String?
        ) -> HarnessResponse {
            guard let window = findMainWindow() else {
                return .error("No visible window found")
            }
            guard let settings = appSettings,
                  let docState = documentState
            else {
                return .error("App state not available")
            }
            do {
                let result = try CaptureService.captureWindow(
                    window,
                    outputPath: outputPath,
                    appSettings: settings,
                    documentState: docState
                )
                return .ok(data: .capture(result))
            } catch {
                return .error("Capture failed: \(error.localizedDescription)")
            }
        }

        private static func handleCaptureRegion(
            _ region: CaptureRegion,
            _ outputPath: String?
        ) -> HarnessResponse {
            guard let window = findMainWindow() else {
                return .error("No visible window found")
            }
            guard let settings = appSettings,
                  let docState = documentState
            else {
                return .error("App state not available")
            }
            let rect = CGRect(
                x: region.x,
                y: region.y,
                width: region.width,
                height: region.height
            )
            do {
                let result = try CaptureService.captureRegion(
                    window,
                    region: rect,
                    outputPath: outputPath,
                    appSettings: settings,
                    documentState: docState
                )
                return .ok(data: .capture(result))
            } catch {
                return .error("Capture failed: \(error.localizedDescription)")
            }
        }

        private static func handleStartFrameCapture(
            _ fps: Int,
            _ duration: Double,
            _ outputDir: String?
        ) async -> HarnessResponse {
            guard let window = findMainWindow() else {
                return .error("No visible window found")
            }
            do {
                let result = try await CaptureService.startFrameCapture(
                    window,
                    fps: fps,
                    duration: duration,
                    outputDir: outputDir
                )
                return .ok(data: .frameCapture(result))
            } catch {
                return .error(
                    "Frame capture failed: \(error.localizedDescription)"
                )
            }
        }

        private static func handleStopFrameCapture() -> HarnessResponse {
            guard CaptureService.activeFrameSession != nil else {
                return .ok(message: "No active frame capture session")
            }
            CaptureService.activeFrameSession = nil
            return .ok(message: "Frame capture stopped")
        }

        private static func handleBeginFrameCapture(
            _ fps: Int, _ outputDir: String?
        ) async -> HarnessResponse {
            guard let window = findMainWindow() else { return .error("No visible window found") }
            do {
                try await CaptureService.beginFrameCapture(window, fps: fps, outputDir: outputDir)
                return .ok(message: "Frame capture started at \(fps) fps")
            } catch { return .error("Begin frame capture failed: \(error.localizedDescription)") }
        }

        private static func handleEndFrameCapture() async -> HarnessResponse {
            do {
                return try await .ok(data: .frameCapture(CaptureService.endFrameCapture()))
            } catch { return .error("End frame capture failed: \(error.localizedDescription)") }
        }
    }
#endif
