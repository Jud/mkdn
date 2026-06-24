// swiftlint:disable file_length
#if os(macOS)
    import AppKit
    import SwiftUI

    @MainActor
    enum TestHarnessHandler { // swiftlint:disable:this type_body_length
        weak static var appSettings: AppSettings?
        weak static var documentState: DocumentState?
        private static var nextSyntheticMouseEventNumber = 1

        // MARK: - Command Dispatch

        // swiftlint:disable:next cyclomatic_complexity function_body_length
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
            case .recreateView:
                await handleRecreateView()
            case let .addComment(substring, body):
                await handleAddComment(substring: substring, body: body)
            case let .pasteComment(substring, text):
                await handlePasteComment(substring: substring, text: text)
            case .toggleCommentSidebar:
                handleToggleCommentSidebar()
            case .toggleMinimap:
                handleToggleMinimap()
            case .jumpFirstComment:
                handleJumpComment(index: 0)
            case let .jumpCommentAt(index):
                handleJumpComment(index: index)
            case let .diagnoseCommentClick(index):
                await handleDiagnoseCommentClick(index: index)
            case .captureWindow, .captureRegion,
                 .startFrameCapture, .stopFrameCapture,
                 .beginFrameCapture, .endFrameCapture:
                await processCapture(command)
            case .getWindowInfo:
                handleGetWindowInfo()
            case .getOpenTimings:
                .ok(data: .openTimings(OpenTimeline.shared.result()))
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
            case let .moveWindow(x, y):
                handleMoveWindow(x, y)
            case let .clickAt(x, y, clickCount):
                await handleClickAt(x: x, y: y, clickCount: clickCount ?? 1)
            case let .dragAt(fromX, fromY, toX, toY):
                await handleDragAt(fromX: fromX, fromY: fromY, toX: toX, toY: toY)
            case let .pressButton(title, index):
                handlePressButton(title: title, index: index ?? 0)
            case let .axTree(maxDepth):
                handleAXTree(maxDepth: maxDepth ?? 25)
            case let .axPress(query, action, index):
                handleAXPress(query: query, action: action, index: index ?? 0)
            case .axRotors:
                handleAXRotors()
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

        /// Forces a cold recreation of the markdown preview's NSView so a
        /// first-paint rendering bug can be reproduced without relaunching. The
        /// rebuild only fires `signalRenderComplete` when a markdown preview is
        /// mounted, so we only await the render then (a source/plain/welcome view
        /// has no preview to recreate and would otherwise time out).
        private static func handleRecreateView() async -> HarnessResponse {
            guard let docState = documentState else {
                return .error("No document state available")
            }
            let hasMarkdownPreview = docState.currentFileURL != nil
                && docState.fileKind == .markdown
            let signal = RenderCompletionSignal.shared
            if hasMarkdownPreview { signal.prepareForRender() }
            docState.rebuildDocumentView()
            if hasMarkdownPreview {
                try? await signal.awaitPreparedRender(timeout: .seconds(5))
                return .ok(message: "Document view recreated")
            }
            return .ok(message: "No markdown preview to recreate")
        }

        private static func handleToggleCommentSidebar() -> HarnessResponse {
            guard let docState = documentState else {
                return .error("No document state available")
            }
            docState.toggleCommentSidebar()
            return .ok(message: "Comment sidebar: \(docState.isCommentSidebarVisible ? "open" : "closed")")
        }

        private static func handleToggleMinimap() -> HarnessResponse {
            guard let docState = documentState else {
                return .error("No document state available")
            }
            docState.toggleMinimap()
            return .ok(message: "Minimap: \(docState.isMinimapVisible ? "shown" : "hidden")")
        }

        /// The text view and the resolved comment at `index` in document order, or
        /// nil. keyWindow is nil under the harness, so search the main window
        /// directly rather than via the keyWindow-based MkdnCommands.findTextView().
        private static func resolvedComment(
            at index: Int
        ) -> (textView: CodeBlockBackgroundTextView,
              target: (id: String, entry: CommentSidecar.Entry, range: NSRange))? {
            guard let window = findMainWindow(),
                  let content = window.contentView,
                  let textView = MkdnCommands.findTextView(in: content)
            else { return nil }
            let active = textView.resolvedComments?.active ?? []
            guard active.indices.contains(index) else { return nil }
            return (textView, active[index])
        }

        private static func handleJumpComment(index: Int) -> HarnessResponse {
            guard let (textView, target) = resolvedComment(at: index) else {
                return .error("No resolved comment at index \(index)")
            }
            textView.revealComment(id: target.id, range: target.range)
            return .ok(message: "Jumped to: \(target.entry.quote)")
        }

        /// Scroll the comment at `index` into view, hit-test the center of its span,
        /// and (when it's clickable) open its popover — the full main-document
        /// click path, for verifying comment clickability without a synthetic event.
        private static func handleDiagnoseCommentClick(index: Int) async -> HarnessResponse {
            guard let (textView, target) = resolvedComment(at: index) else {
                return .error("No resolved comment at index \(index)")
            }
            textView.revealComment(id: target.id, range: target.range)
            // Let the smooth scroll settle before hit-testing (derived from the
            // scroll duration so it can't drift out of sync).
            try? await Task.sleep(for: .seconds(AnimationConstants.scrollToHeadingDuration + 0.1))

            guard let rect = textView.boundingRect(forCharacterRange: target.range) else {
                return .error("No bounding rect for \(target.entry.quote)")
            }
            let mid = CGPoint(x: rect.midX, y: rect.midY)
            let hits = textView.commentHits(at: mid)
            guard !hits.isEmpty else {
                return .error("\(target.entry.quote) is not clickable at its center")
            }
            textView.toggleComments(hits)
            return .ok(message: "Opened \(hits.map(\.entry.id)) for: \(target.entry.quote)")
        }

        private static func handleAddComment(
            substring: String, body: String
        ) async -> HarnessResponse {
            guard let docState = documentState else {
                return .error("No document state available")
            }
            // Capture a content-anchored selector for the substring against a fresh
            // render of the body, mirroring the live authoring path.
            let theme = appSettings?.theme ?? .solarizedDark
            let body0 = CommentDocument.parse(docState.markdownContent).body
            let blocks = MarkdownRenderer.render(text: body0, theme: theme)
            let result = MarkdownTextStorageBuilder.build(blocks: blocks, theme: theme)
            let rendered = result.attributedString.string as NSString // swiftlint:disable:this legacy_objc_type
            let builderRange = rendered.range(of: substring)
            guard builderRange.location != NSNotFound else {
                return .error("Substring not found in rendered text: \(substring)")
            }
            let tape = AnchorTape.build(from: result.attributedString)
            guard let selector = CommentSelectorCapture.capture(builderRange: builderRange, in: tape) else {
                return .error("Could not capture selector for: \(substring)")
            }
            let signal = RenderCompletionSignal.shared
            signal.prepareForRender()
            docState.addComment(selector, body: body)
            try? await signal.awaitPreparedRender(timeout: .seconds(5))
            return .ok(message: "Comment added over: \(substring)")
        }

        private static func handlePasteComment(
            substring: String, text: String
        ) async -> HarnessResponse {
            guard let docState = documentState else {
                return .error("No document state available")
            }
            guard let textView = MkdnCommands.findTextView() else {
                return .error("No text view available")
            }
            let rendered = textView.textStorage?.string ?? ""
            guard let found = rendered.range(of: substring) else {
                return .error("Substring not found in rendered text: \(substring)")
            }
            textView.setSelectedRange(NSRange(found, in: rendered))
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)

            let countBefore = CommentDocument.parse(docState.markdownContent).entries.count
            let signal = RenderCompletionSignal.shared
            signal.prepareForRender()
            textView.paste(nil)
            let countAfter = CommentDocument.parse(docState.markdownContent).entries.count
            guard countAfter == countBefore + 1 else {
                signal.cancelPrepare()
                return .error("Paste did not create a comment over: \(substring)")
            }
            do {
                try await signal.awaitPreparedRender(timeout: .seconds(5))
            } catch {
                return .error("Render timeout after paste over: \(substring)")
            }
            return .ok(message: "Pasted comment over: \(substring), entries: \(countAfter)")
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

        /// Move the window's top-left to a point measured from the top-left of the
        /// display that holds the menu bar (the global-origin screen). Lets a
        /// capture run pin the window to a Retina display for 2x screenshots.
        private static func handleMoveWindow(
            _ x: Double,
            _ y: Double
        ) -> HarnessResponse {
            guard let window = findMainWindow() else {
                return .error("No visible window found")
            }
            let screen = NSScreen.screens.first(where: { $0.frame.origin == .zero })
                ?? NSScreen.main
                ?? NSScreen.screens.first
            guard let screen else {
                return .error("No screen found")
            }
            let topLeft = NSPoint(
                x: screen.frame.minX + x,
                y: screen.frame.maxY - y
            )
            window.setFrameTopLeftPoint(topLeft)
            let scale = window.screen?.backingScaleFactor ?? 0
            return .ok(
                message: "Window moved to \(window.frame.origin) (scale \(scale))"
            )
        }

        /// Synthesize a left click at content-local coordinates (top-left
        /// origin). Table overlays are driven through their imperative
        /// selection driver (SwiftUI gestures never recognize synthetic
        /// NSEvents); everything else gets mouseDown + mouseUp through
        /// AppKit's real event path. `clickCount > 1` reaches the table
        /// driver as a double/triple click (word/cell selection).
        private static func handleClickAt(
            x: Double, y: Double, clickCount: Int
        ) async -> HarnessResponse {
            guard let window = findMainWindow(), let content = window.contentView else {
                return .error("No visible window found")
            }

            await activateForSyntheticMouse(window)

            // Flip top-left content coords to bottom-left, then to window coords.
            let contentPoint = NSPoint(x: x, y: content.bounds.height - y)
            let windowPoint = content.convert(contentPoint, to: nil)
            let clicks = max(clickCount, 1)
            let tableWindowPoint = trueWindowPoint(x: x, y: y, in: content)
            if let textView = MkdnCommands.findTextView(in: content),
               textView.harnessTableDrag?(tableWindowPoint, tableWindowPoint, clicks) == true
            {
                return .ok(message: "Clicked table (\(x), \(y)) ×\(clicks)")
            }

            let hitName = content.hitTest(contentPoint)
                .map { hit in String(describing: type(of: hit)) } ?? "none"
            let sent = await sendSyntheticClicks(
                count: clicks, at: windowPoint, in: window
            )
            guard sent else { return .error("Could not synthesize click events") }
            return .ok(message: "Clicked (\(x), \(y)) ×\(clicks) → hit: \(hitName)")
        }

        /// Send `count` mouseDown/mouseUp pairs with escalating click counts —
        /// the stream a real multi-click produces.
        private static func sendSyntheticClicks(
            count: Int, at windowPoint: NSPoint, in window: NSWindow
        ) async -> Bool {
            let eventNumber = nextSyntheticMouseEventNumber
            nextSyntheticMouseEventNumber += 1

            func mouseEvent(_ type: NSEvent.EventType, click: Int) -> NSEvent? {
                NSEvent.mouseEvent(
                    with: type,
                    location: windowPoint,
                    modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber,
                    context: nil,
                    eventNumber: eventNumber,
                    clickCount: click,
                    pressure: type == .leftMouseDown ? 1 : 0
                )
            }
            for click in 1 ... count {
                guard let down = mouseEvent(.leftMouseDown, click: click),
                      let up = mouseEvent(.leftMouseUp, click: click)
                else { return false }
                NSApp.sendEvent(down)
                try? await Task.sleep(for: .milliseconds(50))
                NSApp.sendEvent(up)
                if click < count {
                    try? await Task.sleep(for: .milliseconds(50))
                }
            }
            return true
        }

        /// Synthesize a left mouse drag at content-local coordinates. Table
        /// overlays are driven through their imperative selection driver (the
        /// same code path the SwiftUI drag gesture runs — synthetic NSEvents
        /// never reach SwiftUI gesture recognition); other targets get a
        /// mouseDown / mouseDragged / mouseUp stream through AppKit.
        private static func handleDragAt(
            fromX: Double, fromY: Double, toX: Double, toY: Double
        ) async -> HarnessResponse {
            guard let window = findMainWindow(), let content = window.contentView else {
                return .error("No visible window found")
            }

            await activateForSyntheticMouse(window)

            func windowPoint(_ x: Double, _ y: Double) -> NSPoint {
                // Flip top-left content coords to bottom-left, then to window coords.
                content.convert(NSPoint(x: x, y: content.bounds.height - y), to: nil)
            }
            if let textView = MkdnCommands.findTextView(in: content),
               textView.harnessTableDrag?(
                   trueWindowPoint(x: fromX, y: fromY, in: content),
                   trueWindowPoint(x: toX, y: toY, in: content),
                   1
               ) == true
            {
                return .ok(message: "Dragged table (\(fromX), \(fromY)) → (\(toX), \(toY))")
            }
            let sent = await sendSyntheticDrag(
                from: (x: fromX, y: fromY),
                to: (x: toX, y: toY),
                windowPoint: windowPoint,
                in: window
            )
            guard sent else { return .error("Could not synthesize drag events") }
            return .ok(message: "Dragged (\(fromX), \(fromY)) → (\(toX), \(toY))")
        }

        /// Send a mouseDown / interpolated mouseDragged / mouseUp stream
        /// through AppKit's event path.
        private static func sendSyntheticDrag(
            from: (x: Double, y: Double),
            to: (x: Double, y: Double),
            windowPoint: (Double, Double) -> NSPoint,
            in window: NSWindow
        ) async -> Bool {
            let eventNumber = nextSyntheticMouseEventNumber
            nextSyntheticMouseEventNumber += 1

            func mouseEvent(_ type: NSEvent.EventType, at location: NSPoint) -> NSEvent? {
                NSEvent.mouseEvent(
                    with: type,
                    location: location,
                    modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber,
                    context: nil,
                    eventNumber: eventNumber,
                    clickCount: 1,
                    pressure: type == .leftMouseUp ? 0 : 1
                )
            }
            guard let down = mouseEvent(.leftMouseDown, at: windowPoint(from.x, from.y)),
                  let up = mouseEvent(.leftMouseUp, at: windowPoint(to.x, to.y))
            else { return false }
            NSApp.sendEvent(down)
            let steps = 12
            for step in 1 ... steps {
                let progress = Double(step) / Double(steps)
                let x = from.x + (to.x - from.x) * progress
                let y = from.y + (to.y - from.y) * progress
                try? await Task.sleep(for: .milliseconds(8))
                if let dragged = mouseEvent(.leftMouseDragged, at: windowPoint(x, y)) {
                    NSApp.sendEvent(dragged)
                }
            }
            NSApp.sendEvent(up)
            return true
        }

        /// Geometrically correct window coordinates for top-left content
        /// coords. (The legacy NSEvent paths flip unconditionally, which
        /// double-flips on the flipped contentView — harmless there because
        /// their consumers convert back through the same view, but conversions
        /// into overlay views need the true point.)
        private static func trueWindowPoint(
            x: Double, y: Double, in content: NSView
        ) -> NSPoint {
            let local = content.isFlipped
                ? NSPoint(x: x, y: y)
                : NSPoint(x: x, y: content.bounds.height - y)
            return content.convert(local, to: nil)
        }

        /// Bring the app and window frontmost so synthetic mouse events land.
        private static func activateForSyntheticMouse(_ window: NSWindow) async {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            for _ in 0 ..< 5 where !NSApp.isActive || !window.isKeyWindow {
                try? await Task.sleep(for: .milliseconds(20))
                NSApp.activate()
                window.makeKeyAndOrderFront(nil)
            }
        }

        // MARK: - Accessibility Commands

        /// Mark this process as hosting an assistive client. SwiftUI builds
        /// its accessibility bridge lazily, only after an assistive technology
        /// (VoiceOver) sets AXEnhancedUserInterface on the app; without it,
        /// NSHostingView reports no accessibility children and pressButton /
        /// axTree see an empty tree.
        static func activateAccessibility() {
            let selector = NSSelectorFromString("accessibilitySetValue:forAttribute:")
            guard NSApp.responds(to: selector),
                  let implementation = NSApp.method(for: selector)
            else { return }
            // The ObjC calling convention requires reference types here.
            // swiftlint:disable legacy_objc_type
            typealias SetAttribute = @convention(c) (AnyObject, Selector, AnyObject, NSString) -> Void
            let setAttribute = unsafeBitCast(implementation, to: SetAttribute.self)
            setAttribute(NSApp, selector, NSNumber(value: true), "AXEnhancedUserInterface" as NSString)
            // swiftlint:enable legacy_objc_type
        }

        private static func handleAXPress(
            query: String,
            action: String?,
            index: Int
        ) -> HarnessResponse {
            guard index >= 0 else {
                return .error("Element index must be non-negative")
            }
            var visited = Set<ObjectIdentifier>()
            var matches: [AnyObject] = []
            for window in NSApp.windows where window.isVisible {
                guard let content = window.contentView else { continue }
                collectAccessibilityElements(
                    named: query, from: content, visited: &visited, into: &matches
                )
            }
            guard matches.indices.contains(index) else {
                return .error(
                    "No accessibility element matched \"\(query)\" at index \(index); "
                        + "\(matches.count) matched"
                )
            }
            let element = matches[index]
            if let action {
                return performCustomAction(named: action, on: element, query: query)
            }
            if performAccessibilityPress(on: element) {
                return .ok(message: "Pressed \"\(query)\" index \(index) (\(matches.count) matched)")
            }
            return .error(
                "Element \"\(query)\" does not support press. "
                    + "Custom actions: \(customActionNames(of: element))"
            )
        }

        private static func performCustomAction(
            named action: String,
            on element: AnyObject,
            query: String
        ) -> HarnessResponse {
            guard let custom = accessibilityCustomActions(of: element)
                .first(where: { $0.name == action })
            else {
                return .error(
                    "Element \"\(query)\" has no action \"\(action)\". "
                        + "Available: \(customActionNames(of: element))"
                )
            }
            if let handler = custom.handler {
                _ = handler()
            } else if let target = custom.target, let selector = custom.selector {
                _ = target.perform(selector)
            } else {
                return .error("Custom action \"\(action)\" has no handler")
            }
            return .ok(message: "Performed \"\(action)\" on \"\(query)\"")
        }

        private static func collectAccessibilityElements(
            named name: String,
            from element: AnyObject,
            visited: inout Set<ObjectIdentifier>,
            into matches: inout [AnyObject]
        ) {
            guard visited.insert(ObjectIdentifier(element)).inserted else { return }
            if accessibilityNames(of: element).contains(name) {
                matches.append(element)
            }
            for child in accessibilityChildren(of: element) {
                collectAccessibilityElements(
                    named: name, from: child, visited: &visited, into: &matches
                )
            }
        }

        private static func accessibilityCustomActions(
            of element: AnyObject
        ) -> [NSAccessibilityCustomAction] {
            guard let value = performObjectSelector("accessibilityCustomActions", on: element)
            else { return [] }
            return value as? [NSAccessibilityCustomAction] ?? []
        }

        private static func customActionNames(of element: AnyObject) -> String {
            let names = accessibilityCustomActions(of: element).map(\.name)
            return names.isEmpty ? "<none>" : names.joined(separator: ", ")
        }

        private static func handleAXRotors() -> HarnessResponse {
            guard let window = findMainWindow(),
                  let content = window.contentView,
                  let textView = MkdnCommands.findTextView(in: content)
            else { return .error("No markdown text view found") }
            let results = textView.accessibilityCustomRotors().map { rotor in
                AXRotorResult(name: rotorName(rotor), items: rotorItems(rotor))
            }
            return .ok(data: .axRotors(results))
        }

        private static func rotorName(_ rotor: NSAccessibilityCustomRotor) -> String {
            switch rotor.type {
            case .heading: "Headings"
            case .link: "Links"
            default: rotor.label
            }
        }

        /// Walk a rotor's items the way VoiceOver does: repeated `.next`
        /// searches from the previous result. Capped defensively — a delegate
        /// bug that fails to advance would otherwise loop forever.
        private static func rotorItems(_ rotor: NSAccessibilityCustomRotor) -> [String] {
            guard let delegate = rotor.itemSearchDelegate else { return [] }
            var items: [String] = []
            var current: NSAccessibilityCustomRotor.ItemResult?
            while items.count < 500 {
                let parameters = NSAccessibilityCustomRotor.SearchParameters()
                parameters.currentItem = current
                parameters.searchDirection = .next
                guard let result = delegate.rotor(rotor, resultFor: parameters) else { break }
                items.append(result.customLabel ?? "<unlabeled>")
                current = result
            }
            return items
        }

        private static func handleAXTree(maxDepth: Int) -> HarnessResponse {
            var windows: [AXNodeResult] = []
            for window in NSApp.windows where window.isVisible {
                guard let content = window.contentView else { continue }
                var visited = Set<ObjectIdentifier>()
                windows.append(
                    axNode(for: content, in: window, depth: maxDepth, visited: &visited)
                )
            }
            guard !windows.isEmpty else {
                return .error("No visible window found")
            }
            return .ok(data: .axTree(AXTreeResult(windows: windows)))
        }

        private static func axNode(
            for element: AnyObject,
            in window: NSWindow,
            depth: Int,
            visited: inout Set<ObjectIdentifier>
        ) -> AXNodeResult {
            let children: [AXNodeResult]
            if depth > 0 {
                children = accessibilityChildren(of: element).compactMap { child in
                    guard visited.insert(ObjectIdentifier(child)).inserted else { return nil }
                    return axNode(for: child, in: window, depth: depth - 1, visited: &visited)
                }
            } else {
                children = []
            }
            return AXNodeResult(
                role: accessibilityRole(of: element)?.rawValue,
                title: accessibilityString("accessibilityTitle", of: element),
                label: accessibilityString("accessibilityLabel", of: element),
                identifier: accessibilityString("accessibilityIdentifier", of: element),
                value: accessibilityString("accessibilityValue", of: element, maxLength: 200),
                frame: accessibilityContentFrame(of: element, in: window),
                children: children
            )
        }

        private static func accessibilityString(
            _ selectorName: String,
            of element: AnyObject,
            maxLength: Int? = nil
        ) -> String? {
            guard let value = performObjectSelector(selectorName, on: element) else { return nil }
            let string: String
            if let text = value as? String {
                string = text
                // AX values arrive as AnyObject; NSNumber is the bridged form
                // of every numeric value.
            } else if let number = value as? NSNumber { // swiftlint:disable:this legacy_objc_type
                string = number.stringValue
            } else {
                return nil
            }
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if let maxLength, trimmed.count > maxLength {
                return String(trimmed.prefix(maxLength)) + "…"
            }
            return trimmed
        }

        /// The element's accessibility frame converted from screen coordinates
        /// to window content coordinates (top-left origin), matching `clickAt`.
        /// Called via method IMP because SwiftUI's bridged AX elements do not
        /// conform to NSAccessibilityProtocol (and perform() can't return a
        /// struct).
        private static func accessibilityContentFrame(
            of element: AnyObject,
            in window: NSWindow
        ) -> CaptureRegion? {
            let selector = NSSelectorFromString("accessibilityFrame")
            guard element.responds(to: selector),
                  let implementation = element.method(for: selector),
                  let content = window.contentView
            else { return nil }
            typealias FrameFunction = @convention(c) (AnyObject, Selector) -> NSRect
            let frame = unsafeBitCast(implementation, to: FrameFunction.self)
            let screenRect = frame(element, selector)
            guard screenRect != .zero else { return nil }
            let windowRect = window.convertFromScreen(screenRect)
            let local = content.convert(windowRect, from: nil)
            return CaptureRegion(
                x: local.origin.x,
                y: content.isFlipped ? local.origin.y : content.bounds.height - local.maxY,
                width: local.width,
                height: local.height
            )
        }

        private struct AccessibilityButton {
            let element: AnyObject
            let names: [String]

            var displayName: String {
                names.first ?? "<untitled>"
            }
        }

        private static func handlePressButton(title: String, index: Int) -> HarnessResponse {
            guard index >= 0 else {
                return .error("Button index must be non-negative")
            }

            var visited = Set<ObjectIdentifier>()
            var buttons: [AccessibilityButton] = []
            for window in NSApp.windows where window.isVisible {
                guard let content = window.contentView else { continue }
                collectAccessibilityButtons(
                    from: content,
                    visited: &visited,
                    buttons: &buttons
                )
            }

            let matches = buttons.filter { button in
                button.names.contains(title)
            }
            guard matches.indices.contains(index) else {
                let available = availableButtonTitles(from: buttons)
                if matches.isEmpty {
                    return .error(
                        "No accessibility button matched \"\(title)\". "
                            + "Available buttons: \(available)"
                    )
                }
                return .error(
                    "Button \"\(title)\" index \(index) is out of range; "
                        + "\(matches.count) matched. Available buttons: \(available)"
                )
            }

            let button = matches[index]
            guard performAccessibilityPress(on: button.element) else {
                return .error(
                    "Matched button \"\(button.displayName)\" but accessibilityPerformPress() failed"
                )
            }
            return .ok(
                message: "Pressed button \"\(button.displayName)\" index \(index) "
                    + "(\(matches.count) matched)"
            )
        }

        private static func collectAccessibilityButtons(
            from element: AnyObject,
            visited: inout Set<ObjectIdentifier>,
            buttons: inout [AccessibilityButton]
        ) {
            let identifier = ObjectIdentifier(element)
            guard visited.insert(identifier).inserted else { return }

            if accessibilityRole(of: element) == .button {
                buttons.append(
                    AccessibilityButton(
                        element: element,
                        names: accessibilityNames(of: element)
                    )
                )
            }

            for child in accessibilityChildren(of: element) {
                collectAccessibilityButtons(
                    from: child,
                    visited: &visited,
                    buttons: &buttons
                )
            }
        }

        private static func accessibilityRole(of element: AnyObject) -> NSAccessibility.Role? {
            guard let value = performObjectSelector(
                "accessibilityRole",
                on: element
            ) else { return nil }
            if let role = value as? NSAccessibility.Role {
                return role
            }
            if let rawValue = value as? String {
                return NSAccessibility.Role(rawValue: rawValue)
            }
            return nil
        }

        private static func accessibilityNames(of element: AnyObject) -> [String] {
            [
                "accessibilityTitle",
                "accessibilityLabel",
                "accessibilityIdentifier",
                "accessibilityValue",
                "accessibilityHelp",
            ].compactMap { selectorName -> String? in
                guard let value = performObjectSelector(selectorName, on: element) else {
                    return nil
                }
                if let string = value as? String {
                    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? nil : trimmed
                }
                return nil
            }
        }

        /// First non-empty children list among the three child selectors.
        /// Concatenating them would duplicate children: NSTextView vends fresh
        /// proxy objects on every call, defeating identity-based dedup.
        private static func accessibilityChildren(of element: AnyObject) -> [AnyObject] {
            for selectorName in [
                "accessibilityChildren",
                "accessibilityVisibleChildren",
                "accessibilityChildrenInNavigationOrder",
            ] {
                guard let value = performObjectSelector(selectorName, on: element) else {
                    continue
                }
                let children: [AnyObject]
                if let typed = value as? [AnyObject] {
                    children = typed
                } else if let untyped = value as? [Any] {
                    children = untyped.compactMap { $0 as AnyObject }
                } else {
                    continue
                }
                if !children.isEmpty { return children }
            }
            return []
        }

        private static func performObjectSelector(
            _ selectorName: String,
            on element: AnyObject
        ) -> AnyObject? {
            let selector = NSSelectorFromString(selectorName)
            guard element.responds(to: selector) else { return nil }
            return element.perform(selector)?.takeUnretainedValue()
        }

        private static func performAccessibilityPress(on element: AnyObject) -> Bool {
            let selector = NSSelectorFromString("accessibilityPerformPress")
            guard element.responds(to: selector),
                  let implementation = element.method(for: selector)
            else { return false }
            typealias PressFunction = @convention(c) (AnyObject, Selector) -> Bool
            let press = unsafeBitCast(implementation, to: PressFunction.self)
            return press(element, selector)
        }

        private static func availableButtonTitles(
            from buttons: [AccessibilityButton]
        ) -> String {
            var seen = Set<String>()
            let titles = buttons.compactMap { button -> String? in
                let title = button.displayName
                guard seen.insert(title).inserted else { return nil }
                return title
            }
            return titles.isEmpty ? "<none>" : titles.joined(separator: ", ")
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
