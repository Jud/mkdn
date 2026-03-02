#if os(macOS)
    import AppKit
    import SwiftUI

    extension TestHarnessHandler {
        // MARK: - Quick Capture Command Dispatch

        static func processQuickCapture(
            _ command: HarnessCommand
        ) -> HarnessResponse {
            switch command {
            case let .startQuickCapture(fps, outputDir):
                handleStartQuickCapture(fps, outputDir)
            case .stopQuickCapture:
                handleStopQuickCapture()
            default:
                .error("Unknown quick capture command")
            }
        }

        // MARK: - Quick Capture State

        static var quickCaptureTimer: DispatchSourceTimer?
        nonisolated(unsafe) static var quickCaptureFrames: [String] = []
        nonisolated(unsafe) static var quickCaptureCounter = 0

        // MARK: - Quick Capture Commands

        private static func handleStartQuickCapture(
            _ fps: Int,
            _ outputDir: String
        ) -> HarnessResponse {
            guard quickCaptureTimer == nil else {
                return .error("Quick capture already in progress")
            }

            try? FileManager.default.createDirectory(
                atPath: outputDir, withIntermediateDirectories: true
            )

            quickCaptureFrames = []
            quickCaptureCounter = 0

            guard let window = findMainWindow() else {
                return .error("No visible window found")
            }
            let windowID = CGWindowID(window.windowNumber)
            let intervalMs = max(1_000 / max(fps, 1), 1)

            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(
                deadline: .now(),
                repeating: .milliseconds(intervalMs),
                leeway: .milliseconds(1)
            )
            timer.setEventHandler {
                guard let image = CGWindowListCreateImage(
                    .null,
                    .optionIncludingWindow,
                    windowID,
                    [.bestResolution]
                )
                else { return }

                quickCaptureCounter += 1
                let path = "\(outputDir)/frame_\(String(format: "%04d", quickCaptureCounter)).png"
                let rep = NSBitmapImageRep(cgImage: image)
                if let data = rep.representation(using: .png, properties: [:]) {
                    try? data.write(to: URL(fileURLWithPath: path))
                    quickCaptureFrames.append(path)
                }
            }
            quickCaptureTimer = timer
            timer.resume()

            return .ok(message: "Quick capture started at \(fps) fps -> \(outputDir)")
        }

        private static func handleStopQuickCapture() -> HarnessResponse {
            guard let timer = quickCaptureTimer else {
                return .error("No quick capture in progress")
            }
            timer.cancel()
            quickCaptureTimer = nil

            let frames = quickCaptureFrames
            quickCaptureFrames = []

            return .ok(
                data: .frameCapture(FrameCaptureResult(
                    frameDir: frames.first.map { URL(fileURLWithPath: $0).deletingLastPathComponent().path } ?? "",
                    frameCount: frames.count,
                    fps: 0,
                    duration: 0,
                    framePaths: frames
                )),
                message: "Quick capture stopped: \(frames.count) frames"
            )
        }
    }
#endif
