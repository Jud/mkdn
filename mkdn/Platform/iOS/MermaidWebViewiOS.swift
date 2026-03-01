#if os(iOS)
    import SwiftUI
    @preconcurrency import WebKit

    /// `UIViewRepresentable` that wraps a `WKWebView` for rendering a single
    /// Mermaid diagram on iOS.
    ///
    /// Uses ``MermaidTemplateLoader`` for shared template preparation and
    /// ``MermaidThemeMapper`` for theme integration. Simpler than the macOS
    /// `MermaidWebView`: no click-to-focus model, no focus ring suppression,
    /// no cursor management, no `allowsMagnification`.
    struct MermaidWebViewiOS: UIViewRepresentable {
        let code: String
        let theme: AppTheme
        @Binding var renderedHeight: CGFloat
        @Binding var renderState: MermaidRenderState

        /// All diagram `WKWebView` instances share a single web content process.
        private static let sharedProcessPool = WKProcessPool()

        // MARK: - UIViewRepresentable

        func makeCoordinator() -> Coordinator {
            Coordinator(parent: self)
        }

        func makeUIView(context: Context) -> WKWebView {
            let configuration = WKWebViewConfiguration()
            configuration.processPool = Self.sharedProcessPool

            let contentController = WKUserContentController()
            contentController.add(context.coordinator, name: "sizeReport")
            contentController.add(context.coordinator, name: "renderComplete")
            contentController.add(context.coordinator, name: "renderError")
            configuration.userContentController = contentController

            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.navigationDelegate = context.coordinator
            webView.isOpaque = false
            webView.backgroundColor = .clear
            webView.scrollView.isScrollEnabled = false

            context.coordinator.webView = webView
            context.coordinator.currentTheme = theme

            loadTemplate(into: webView, coordinator: context.coordinator)

            return webView
        }

        func updateUIView(_: WKWebView, context: Context) {
            let coordinator = context.coordinator
            coordinator.parent = self

            if coordinator.currentTheme != theme {
                coordinator.currentTheme = theme
                reRenderWithTheme(coordinator: coordinator)
            }
        }

        static func dismantleUIView(_: WKWebView, coordinator: Coordinator) {
            coordinator.removeMessageHandlers()
        }

        // MARK: - Template Loading

        private func loadTemplate(into webView: WKWebView, coordinator: Coordinator) {
            guard let html = MermaidTemplateLoader.loadTemplate(code: code, theme: theme) else {
                coordinator.parent.renderState = .error(
                    MermaidError.templateNotFound.localizedDescription
                )
                return
            }
            let baseURL = Bundle.module
                .url(forResource: "mermaid-template", withExtension: "html")?
                .deletingLastPathComponent()
            webView.loadHTMLString(html, baseURL: baseURL)
        }

        private func reRenderWithTheme(coordinator: Coordinator) {
            guard let webView = coordinator.webView else { return }
            let script = MermaidTemplateLoader.reRenderScript(theme: theme)
            webView.evaluateJavaScript(script) { _, error in
                if let error {
                    coordinator.parent.renderState = .error(
                        MermaidError.renderFailed(error.localizedDescription).localizedDescription
                    )
                }
            }
        }

        // MARK: - Coordinator

        @MainActor
        final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
            var parent: MermaidWebViewiOS
            var webView: WKWebView?
            var currentTheme: AppTheme
            private var hasCompletedInitialNavigation = false

            init(parent: MermaidWebViewiOS) {
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
#endif
