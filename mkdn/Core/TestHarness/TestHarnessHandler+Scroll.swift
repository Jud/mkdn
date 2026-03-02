#if os(macOS)
    import AppKit
    import SwiftUI

    extension TestHarnessHandler {
        // MARK: - Scroll Command Dispatch

        static func processScroll(
            _ command: HarnessCommand
        ) async -> HarnessResponse {
            switch command {
            case let .scrollTo(yOffset):
                await handleScrollTo(yOffset)
            case let .simulateScroll(deltaY, duration):
                await handleSimulateScroll(deltaY, duration)
            case let .scrollSidebar(yOffset):
                await handleScrollSidebar(yOffset)
            default:
                .error("Unknown scroll command")
            }
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

        static func findSidebarScrollView(in view: NSView?) -> NSScrollView? {
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

        static func findScrollView(in view: NSView?) -> NSScrollView? {
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
    }
#endif
