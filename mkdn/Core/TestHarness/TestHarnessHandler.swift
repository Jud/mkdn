import AppKit
import SwiftUI

@MainActor
enum TestHarnessHandler {
    weak static var appSettings: AppSettings?
    weak static var documentState: DocumentState?
    weak static var directoryState: DirectoryState?

    // MARK: - Command Dispatch

    static func process(_ command: HarnessCommand) async -> HarnessResponse {
        switch command {
        case let .loadFile(path):
            await handleLoadFile(path)
        case let .switchMode(mode):
            await handleSwitchMode(mode)
        case .cycleTheme:
            await handleCycleTheme()
        case let .setTheme(theme):
            await handleSetTheme(theme)
        case .reloadFile:
            await handleReloadFile()
        case .captureWindow, .captureRegion,
             .startFrameCapture, .stopFrameCapture,
             .beginFrameCapture, .endFrameCapture:
            await processCapture(command)
        case .getWindowInfo:
            handleGetWindowInfo()
        case .getThemeColors:
            handleGetThemeColors()
        case let .setReduceMotion(enabled):
            handleSetReduceMotion(enabled)
        case let .scrollTo(yOffset):
            await handleScrollTo(yOffset)
        case let .simulateScroll(deltaY, duration):
            await handleSimulateScroll(deltaY, duration)
        case let .scrollSidebar(yOffset):
            await handleScrollSidebar(yOffset)
        case let .startQuickCapture(fps, outputDir):
            handleStartQuickCapture(fps, outputDir)
        case .stopQuickCapture:
            handleStopQuickCapture()
        case let .setSidebarWidth(width):
            handleSetSidebarWidth(width)
        case .toggleSidebar:
            handleToggleSidebar()
        case let .resizeWindow(width, height):
            handleResizeWindow(width, height)
        case .ping:
            .ok(data: .pong)
        case .quit:
            handleQuit()
        }
    }

    private static func processCapture(
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

    // MARK: - File Commands

    private static func handleLoadFile(_ path: String) async -> HarnessResponse {
        guard let docState = documentState else {
            return .error("No document state available")
        }
        let url = URL(fileURLWithPath: path)
        do {
            let signal = RenderCompletionSignal.shared
            let previousContent = docState.markdownContent
            signal.prepareForRender()
            try docState.loadFile(at: url)
            let contentChanged = docState.markdownContent != previousContent
            if contentChanged {
                try await signal.awaitPreparedRender()
            } else {
                signal.cancelPrepare()
            }
            return .ok(message: "Loaded: \(path)")
        } catch is HarnessError {
            return .error("Render timeout after loading file")
        } catch {
            return .error("Load failed: \(error.localizedDescription)")
        }
    }

    private static func handleReloadFile() async -> HarnessResponse {
        guard let docState = documentState else {
            return .error("No document state available")
        }
        do {
            let signal = RenderCompletionSignal.shared
            let previousContent = docState.markdownContent
            signal.prepareForRender()
            try docState.reloadFile()
            let contentChanged = docState.markdownContent != previousContent
            if contentChanged {
                try await signal.awaitPreparedRender()
            } else {
                signal.cancelPrepare()
            }
            return .ok(message: "File reloaded")
        } catch is HarnessError {
            return .error("Render timeout after reload")
        } catch {
            return .error("Reload failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Mode Commands

    private static func handleSwitchMode(
        _ mode: String
    ) async -> HarnessResponse {
        guard let docState = documentState else {
            return .error("No document state available")
        }
        let signal = RenderCompletionSignal.shared
        signal.prepareForRender()
        switch mode {
        case "previewOnly":
            docState.switchMode(to: .previewOnly)
        case "sideBySide":
            docState.switchMode(to: .sideBySide)
        default:
            return .error("Unknown mode: \(mode). Use: previewOnly, sideBySide")
        }
        try? await signal.awaitPreparedRender(timeout: .seconds(5))
        return .ok(message: "Mode: \(mode)")
    }

    // MARK: - Theme Commands

    private static func handleCycleTheme() async -> HarnessResponse {
        guard let settings = appSettings else {
            return .error("No app settings available")
        }
        let signal = RenderCompletionSignal.shared
        let hasView = documentState?.currentFileURL != nil
        if hasView { signal.prepareForRender() }
        settings.cycleTheme()
        if hasView {
            try? await signal.awaitPreparedRender(timeout: .seconds(5))
        }
        return .ok(message: "Theme: \(settings.themeMode.rawValue)")
    }

    private static func handleSetTheme(
        _ theme: String
    ) async -> HarnessResponse {
        guard let settings = appSettings else {
            return .error("No app settings available")
        }
        let signal = RenderCompletionSignal.shared
        let hasView = documentState?.currentFileURL != nil
        if hasView { signal.prepareForRender() }
        switch theme {
        case "solarizedDark":
            settings.themeMode = .solarizedDark
        case "solarizedLight":
            settings.themeMode = .solarizedLight
        default:
            return .error(
                "Unknown theme: \(theme). Use: solarizedDark, solarizedLight"
            )
        }
        if hasView {
            try? await signal.awaitPreparedRender(timeout: .seconds(5))
        }
        return .ok(message: "Theme set: \(theme)")
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

    // MARK: - Info Commands

    private static func handleGetWindowInfo() -> HarnessResponse {
        guard let window = findMainWindow() else {
            return .error("No visible window found")
        }
        let frame = window.frame
        let result = WindowInfoResult(
            width: frame.width,
            height: frame.height,
            x: frame.origin.x,
            y: frame.origin.y,
            scaleFactor: window.backingScaleFactor,
            theme: appSettings?.theme.rawValue ?? "unknown",
            viewMode: documentState?.viewMode.rawValue ?? "unknown",
            currentFilePath: documentState?.currentFileURL?.path
        )
        return .ok(data: .windowInfo(result))
    }

    private static func handleGetThemeColors() -> HarnessResponse {
        guard let settings = appSettings else {
            return .error("No app settings available")
        }
        let colors = settings.theme.colors
        let result = ThemeColorsResult(
            themeName: settings.theme.rawValue,
            background: rgbColor(from: colors.background),
            backgroundSecondary: rgbColor(from: colors.backgroundSecondary),
            foreground: rgbColor(from: colors.foreground),
            foregroundSecondary: rgbColor(from: colors.foregroundSecondary),
            accent: rgbColor(from: colors.accent),
            headingColor: rgbColor(from: colors.headingColor),
            codeBackground: rgbColor(from: colors.codeBackground),
            codeForeground: rgbColor(from: colors.codeForeground),
            linkColor: rgbColor(from: colors.linkColor)
        )
        return .ok(data: .themeColors(result))
    }

    // MARK: - Preference Commands

    private static func handleSetReduceMotion(
        _ enabled: Bool
    ) -> HarnessResponse {
        TestHarnessMode.reduceMotion = enabled ? .forceEnabled : .forceDisabled
        return .ok(message: "Reduce motion override: \(enabled)")
    }

    // MARK: - Scroll Commands

    private static func handleScrollTo(
        _ yOffset: Double
    ) async -> HarnessResponse {
        guard let window = findMainWindow() else {
            return .error("No visible window found")
        }
        guard let scrollView = findScrollView(in: window.contentView) else {
            return .error("No scroll view found in window hierarchy")
        }
        let documentHeight = scrollView.documentView?.frame.height ?? 0
        let visibleHeight = scrollView.contentView.bounds.height
        let maxY = max(0, documentHeight - visibleHeight)
        let clampedY = min(max(0, yOffset), maxY)
        let point = NSPoint(x: 0, y: clampedY)
        scrollView.contentView.scroll(to: point)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        try? await Task.sleep(for: .milliseconds(50))
        let actualY = scrollView.contentView.bounds.origin.y
        return .ok(message: "Scrolled to y=\(actualY)")
    }

    private static func handleSimulateScroll(
        _ totalDeltaY: Double,
        _ duration: Double
    ) async -> HarnessResponse {
        guard let window = findMainWindow() else {
            return .error("No visible window found")
        }
        guard let scrollView = findScrollView(in: window.contentView) else {
            return .error("No scroll view found in window hierarchy")
        }

        let stepCount = max(Int(duration * 60), 2)
        let perStepDelta = totalDeltaY / Double(stepCount)

        // Use a continuation so we can schedule events on the main run loop
        // with proper timing via DispatchSourceTimer
        let finalY: Double = await withCheckedContinuation { continuation in
            var step = 0
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(
                deadline: .now(),
                repeating: .milliseconds(16),
                leeway: .milliseconds(1)
            )
            timer.setEventHandler {
                let progress = Double(step) / Double(stepCount)
                let factor = 2.0 * (1.0 - progress)
                let delta = perStepDelta * factor

                let currentY = scrollView.contentView.bounds.origin.y
                let newY = currentY + delta
                scrollView.contentView.scroll(to: NSPoint(x: 0, y: newY))
                scrollView.reflectScrolledClipView(scrollView.contentView)

                step += 1
                if step >= stepCount {
                    timer.cancel()
                    let y = scrollView.contentView.bounds.origin.y
                    continuation.resume(returning: y)
                }
            }
            timer.resume()
        }

        return .ok(
            message: "Simulated scroll: requested=\(totalDeltaY), " +
                "finalY=\(finalY), steps=\(stepCount)"
        )
    }

    private static func findSidebarScrollView(in view: NSView?) -> NSScrollView? {
        guard let view else { return nil }
        if let scrollView = view as? NSScrollView,
           !(scrollView.documentView is NSTextView)
        {
            return scrollView
        }
        for subview in view.subviews {
            if let found = findSidebarScrollView(in: subview) {
                return found
            }
        }
        return nil
    }

    private static func findScrollView(in view: NSView?) -> NSScrollView? {
        guard let view else { return nil }
        if let scrollView = view as? NSScrollView,
           scrollView.documentView is NSTextView
        {
            return scrollView
        }
        for subview in view.subviews {
            if let found = findScrollView(in: subview) {
                return found
            }
        }
        return nil
    }

    private static func handleScrollSidebar(
        _ yOffset: Double
    ) async -> HarnessResponse {
        guard let window = findMainWindow() else {
            return .error("No visible window found")
        }
        guard let scrollView = findSidebarScrollView(in: window.contentView) else {
            return .error("No sidebar scroll view found")
        }
        let documentHeight = scrollView.documentView?.frame.height ?? 0
        let visibleHeight = scrollView.contentView.bounds.height
        let maxY = max(0, documentHeight - visibleHeight)
        let clampedY = min(max(0, yOffset), maxY)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: clampedY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        try? await Task.sleep(for: .milliseconds(50))
        let actualY = scrollView.contentView.bounds.origin.y
        return .ok(message: "Sidebar scrolled to y=\(actualY)")
    }

    // MARK: - Quick Capture (CGWindowListCreateImage)

    private static var quickCaptureTimer: DispatchSourceTimer?
    private nonisolated(unsafe) static var quickCaptureFrames: [String] = []
    private nonisolated(unsafe) static var quickCaptureCounter = 0

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

    // MARK: - Window Commands

    private static func handleResizeWindow(
        _ width: Double,
        _ height: Double
    ) -> HarnessResponse {
        guard let window = findMainWindow() else {
            return .error("No visible window found")
        }
        let origin = window.frame.origin
        let newFrame = NSRect(
            x: origin.x,
            y: origin.y,
            width: width,
            height: height
        )
        window.setFrame(newFrame, display: true)
        let actual = window.frame
        return .ok(
            message: "Window resized to \(actual.width)x\(actual.height)"
        )
    }

    // MARK: - Sidebar Commands

    private static func handleSetSidebarWidth(
        _ width: Double
    ) -> HarnessResponse {
        guard let dirState = directoryState else {
            return .error("Not in directory mode")
        }
        let clamped = min(
            max(CGFloat(width), DirectoryState.minSidebarWidth),
            DirectoryState.maxSidebarWidth
        )
        dirState.sidebarWidth = clamped
        return .ok(message: "Sidebar width: \(clamped)")
    }

    private static func handleToggleSidebar() -> HarnessResponse {
        guard let dirState = directoryState else {
            return .error("Not in directory mode")
        }
        dirState.toggleSidebar()
        return .ok(message: "Sidebar visible: \(dirState.isSidebarVisible)")
    }

    // MARK: - Lifecycle Commands

    private static func handleQuit() -> HarnessResponse {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            TestHarnessServer.shared.stop()
            NSApp.terminate(nil)
        }
        return .ok(message: "Shutting down")
    }

    // MARK: - Helpers

    private static func findMainWindow() -> NSWindow? {
        NSApp.mainWindow
            ?? NSApp.keyWindow
            ?? NSApp.windows.first(where: \.isVisible)
    }

    private static func rgbColor(from color: Color) -> RGBColor {
        let nsColor = NSColor(color)
        guard let srgb = nsColor.usingColorSpace(.sRGB) else {
            return RGBColor(red: 0, green: 0, blue: 0)
        }
        return RGBColor(
            red: srgb.redComponent,
            green: srgb.greenComponent,
            blue: srgb.blueComponent
        )
    }
}
