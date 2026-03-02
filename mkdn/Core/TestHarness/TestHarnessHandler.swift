#if os(macOS)
    import AppKit
    import SwiftUI

    @MainActor
    enum TestHarnessHandler {
        weak static var appSettings: AppSettings?
        weak static var documentState: DocumentState?

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
            case .scrollTo, .simulateScroll, .scrollSidebar:
                await processScroll(command)
            case .startQuickCapture, .stopQuickCapture:
                processQuickCapture(command)
            case .setSidebarWidth, .toggleSidebar:
                processSidebar(command)
            case let .resizeWindow(width, height):
                handleResizeWindow(width, height)
            case .ping:
                .ok(data: .pong)
            case .quit:
                handleQuit()
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

        private static func processSidebar(
            _ command: HarnessCommand
        ) -> HarnessResponse {
            switch command {
            case let .setSidebarWidth(width):
                handleSetSidebarWidth(width)
            case .toggleSidebar:
                handleToggleSidebar()
            default:
                .error("Unknown sidebar command")
            }
        }

        private static func handleSetSidebarWidth(
            _ width: Double
        ) -> HarnessResponse {
            guard let docState = documentState else {
                return .error("No document state available")
            }
            let clamped = min(
                max(CGFloat(width), DocumentState.minSidebarWidth),
                DocumentState.maxSidebarWidth
            )
            docState.sidebarWidth = clamped
            return .ok(message: "Sidebar width: \(clamped)")
        }

        private static func handleToggleSidebar() -> HarnessResponse {
            guard let docState = documentState else {
                return .error("No document state available")
            }
            docState.toggleSidebar()
            return .ok(message: "Sidebar visible: \(docState.isSidebarVisible)")
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

        static func findMainWindow() -> NSWindow? {
            NSApp.mainWindow
                ?? NSApp.keyWindow
                ?? NSApp.windows.first(where: \.isVisible)
        }

        static func rgbColor(from color: Color) -> RGBColor {
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
#endif
