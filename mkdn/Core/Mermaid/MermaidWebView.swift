import AppKit
import SwiftUI
@preconcurrency import WebKit

// MARK: - NoFocusRingWKWebView

/// `WKWebView` subclass that suppresses focus rings on itself and all
/// lazily-created internal subviews.
///
/// WebKit creates internal subview hierarchies on demand (e.g. during first
/// paint or interaction). An extension-based override cannot reliably catch
/// these. This subclass intercepts new subviews via `didAddSubview` and
/// re-suppresses after `viewDidMoveToWindow` when WebKit may rebuild its
/// internal view tree.
final class NoFocusRingWKWebView: WKWebView {
    override var focusRingType: NSFocusRingType {
        get { .none }
        set {}
    }

    override func drawFocusRingMask() {}

    override var focusRingMaskBounds: NSRect { .zero }

    override func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)
        Self.suppressFocusRings(in: subview)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        Self.suppressFocusRings(in: self)
    }

    static func suppressFocusRings(in view: NSView) {
        view.focusRingType = .none
        for child in view.subviews {
            suppressFocusRings(in: child)
        }
    }
}

// MARK: - MermaidContainerView

/// Custom `NSView` that gates `hitTest(_:)` based on focus state.
///
/// When `allowsInteraction` is `false` (unfocused), all hit-testing returns
/// `nil`, letting scroll, click, and gesture events pass through to the parent
/// responder chain (the document `ScrollView`). When `true`, the contained
/// `WKWebView` receives events normally, providing native pinch-to-zoom and
/// two-finger pan.
final class MermaidContainerView: NSView {
    var allowsInteraction = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard allowsInteraction else { return nil }
        return super.hitTest(point)
    }

    override func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)
        NoFocusRingWKWebView.suppressFocusRings(in: subview)
    }
}

// MARK: - MermaidWebView

/// `NSViewRepresentable` that wraps a `WKWebView` inside a
/// `MermaidContainerView` for rendering a single Mermaid diagram.
///
/// The view loads an HTML template containing standard Mermaid.js, performs
/// token substitution with the diagram source and theme variables, and
/// communicates render results back to SwiftUI via `WKScriptMessageHandler`.
struct MermaidWebView: NSViewRepresentable {
    let code: String
    let theme: AppTheme
    @Binding var isFocused: Bool
    @Binding var renderedHeight: CGFloat
    @Binding var renderedAspectRatio: CGFloat
    @Binding var renderState: MermaidRenderState

    /// All diagram `WKWebView` instances share a single web content process.
    private static let sharedProcessPool = WKProcessPool()

    // MARK: - NSViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> MermaidContainerView {
        let container = MermaidContainerView()
        container.allowsInteraction = isFocused

        let configuration = WKWebViewConfiguration()
        configuration.processPool = Self.sharedProcessPool

        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "sizeReport")
        contentController.add(context.coordinator, name: "renderComplete")
        contentController.add(context.coordinator, name: "renderError")
        configuration.userContentController = contentController

        let webView = NoFocusRingWKWebView(frame: container.bounds, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isHidden = false
        webView.setValue(false, forKey: "drawsBackground")
        webView.underPageBackgroundColor = .clear
        webView.allowsMagnification = true
        webView.translatesAutoresizingMaskIntoConstraints = false

        container.wantsLayer = true
        container.clipsToBounds = true

        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        context.coordinator.webView = webView
        context.coordinator.containerView = container
        context.coordinator.currentTheme = theme

        loadTemplate(into: webView, coordinator: context.coordinator)

        return container
    }

    func updateNSView(_ container: MermaidContainerView, context: Context) {
        container.allowsInteraction = isFocused

        let coordinator = context.coordinator
        coordinator.parent = self

        if isFocused {
            coordinator.installClickOutsideMonitor()
            coordinator.installEscapeKeyMonitor()
        } else {
            coordinator.removeClickOutsideMonitor()
            coordinator.removeEscapeKeyMonitor()
        }

        if coordinator.currentTheme != theme {
            coordinator.currentTheme = theme
            reRenderWithTheme(coordinator: coordinator)
        }
    }

    static func dismantleNSView(_: MermaidContainerView, coordinator: Coordinator) {
        coordinator.removeClickOutsideMonitor()
        coordinator.removeEscapeKeyMonitor()
        coordinator.removeMessageHandlers()
    }

    // MARK: - Template Loading

    private func loadTemplate(into webView: WKWebView, coordinator: Coordinator) {
        guard let templateURL = Bundle.module.url(
            forResource: "mermaid-template",
            withExtension: "html"
        ),
            let templateString = try? String(contentsOf: templateURL, encoding: .utf8)
        else {
            coordinator.parent.renderState = .error(
                MermaidError.templateNotFound.localizedDescription
            )
            return
        }

        let htmlEscaped = Self.htmlEscape(code)
        let jsEscaped = Self.jsEscape(code)
        let themeJSON = MermaidThemeMapper.themeVariablesJSON(for: theme)

        let html = templateString
            .replacingOccurrences(of: "__MERMAID_CODE_JS__", with: jsEscaped)
            .replacingOccurrences(of: "__MERMAID_CODE__", with: htmlEscaped)
            .replacingOccurrences(of: "__THEME_VARIABLES__", with: themeJSON)

        let resourceDirectory = templateURL.deletingLastPathComponent()
        webView.loadHTMLString(html, baseURL: resourceDirectory)
    }

    private func reRenderWithTheme(coordinator: Coordinator) {
        guard let webView = coordinator.webView else { return }
        let themeJSON = MermaidThemeMapper.themeVariablesJSON(for: theme)
        let script = "reRenderWithTheme(\(themeJSON));"
        webView.evaluateJavaScript(script) { _, error in
            if let error {
                coordinator.parent.renderState = .error(
                    MermaidError.renderFailed(error.localizedDescription).localizedDescription
                )
            }
        }
    }

    // MARK: - Escaping

    static func htmlEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    static func jsEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: MermaidWebView
        var webView: WKWebView?
        weak var containerView: MermaidContainerView?
        var currentTheme: AppTheme
        private var clickOutsideMonitor: Any?
        private var escapeKeyMonitor: Any?
        private var hasCompletedInitialNavigation = false

        init(parent: MermaidWebView) {
            self.parent = parent
            currentTheme = parent.theme
            super.init()
        }

        // MARK: WKScriptMessageHandler

        nonisolated func userContentController(
            _: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            Task { @MainActor in
                self.handleMessage(message)
            }
        }

        private func handleMessage(_ message: WKScriptMessage) {
            switch message.name {
            case "sizeReport":
                guard let body = message.body as? [String: Any],
                      let width = body["width"] as? CGFloat,
                      let height = body["height"] as? CGFloat,
                      width > 0
                else {
                    return
                }
                parent.renderedHeight = max(height, 1)
                parent.renderedAspectRatio = height / width

            case "renderComplete":
                parent.renderState = .rendered

            case "renderError":
                let errorMessage: String = if let body = message.body as? [String: Any],
                                              let message = body["message"] as? String
                {
                    message
                } else {
                    "Unknown rendering error"
                }
                parent.renderState = .error(errorMessage)

            default:
                break
            }
        }

        // MARK: WKNavigationDelegate

        func webView(
            _: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @MainActor (WKNavigationActionPolicy) -> Void
        ) {
            if !hasCompletedInitialNavigation {
                hasCompletedInitialNavigation = true
                decisionHandler(.allow)
                return
            }
            if navigationAction.navigationType == .other {
                decisionHandler(.allow)
                return
            }
            decisionHandler(.cancel)
        }

        // MARK: Click-outside Monitor

        func installClickOutsideMonitor() {
            guard clickOutsideMonitor == nil else { return }
            clickOutsideMonitor = NSEvent.addLocalMonitorForEvents(
                matching: .leftMouseDown
            ) { [weak self] event in
                guard let self,
                      let containerView,
                      let window = containerView.window
                else {
                    return event
                }
                let locationInWindow = event.locationInWindow
                let locationInView = containerView.convert(locationInWindow, from: nil)
                if !containerView.bounds.contains(locationInView),
                   event.window === window
                {
                    parent.isFocused = false
                }
                return event
            }
        }

        func removeClickOutsideMonitor() {
            if let monitor = clickOutsideMonitor {
                NSEvent.removeMonitor(monitor)
                clickOutsideMonitor = nil
            }
        }

        // MARK: Escape Key Monitor

        func installEscapeKeyMonitor() {
            guard escapeKeyMonitor == nil else { return }
            escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(
                matching: .keyDown
            ) { [weak self] event in
                guard let self,
                      event.keyCode == 53
                else {
                    return event
                }
                parent.isFocused = false
                return nil
            }
        }

        func removeEscapeKeyMonitor() {
            if let monitor = escapeKeyMonitor {
                NSEvent.removeMonitor(monitor)
                escapeKeyMonitor = nil
            }
        }

        func removeMessageHandlers() {
            webView?.configuration.userContentController
                .removeScriptMessageHandler(forName: "sizeReport")
            webView?.configuration.userContentController
                .removeScriptMessageHandler(forName: "renderComplete")
            webView?.configuration.userContentController
                .removeScriptMessageHandler(forName: "renderError")
        }
    }
}
