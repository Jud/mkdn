import Foundation

/// Shared utility for loading and preparing Mermaid HTML templates.
///
/// Extracts template loading, string escaping, and re-render script
/// generation so that both macOS `MermaidWebView` and iOS
/// `MermaidWebViewiOS` share the same logic without duplication.
enum MermaidTemplateLoader {
    /// Result of writing a substituted template to a temporary file.
    struct TemplateFileResult {
        /// URL of the temporary HTML file containing the substituted template.
        let tempFileURL: URL

        /// URL of the bundle resource directory containing `mermaid.min.js`.
        let bundleDirectoryURL: URL
    }

    /// Loads the Mermaid HTML template from bundle resources and performs
    /// token substitution with the diagram source code and theme variables.
    ///
    /// - Parameters:
    ///   - code: The raw Mermaid diagram source code.
    ///   - theme: The application theme to apply via Mermaid.js themeVariables.
    /// - Returns: The fully substituted HTML string, or `nil` if the template
    ///   resource could not be found or read.
    static func loadTemplate(code: String, theme: AppTheme) -> String? {
        guard let templateURL = Bundle.module.url(
            forResource: "mermaid-template",
            withExtension: "html"
        ),
            let templateString = try? String(contentsOf: templateURL, encoding: .utf8)
        else {
            return nil
        }

        let htmlEscaped = htmlEscape(code)
        let jsEscaped = jsEscape(code)
        let themeJSON = MermaidThemeMapper.themeVariablesJSON(for: theme)

        return templateString
            .replacingOccurrences(of: "__MERMAID_CODE_JS__", with: jsEscaped)
            .replacingOccurrences(of: "__MERMAID_CODE__", with: htmlEscaped)
            .replacingOccurrences(of: "__THEME_VARIABLES__", with: themeJSON)
    }

    /// Writes the substituted Mermaid HTML template to a temporary file
    /// and returns both the temp file URL and the bundle resource directory.
    ///
    /// Use `loadFileURL(_:allowingReadAccessTo:)` with the returned URLs
    /// so that WebKit gains filesystem read access to the bundled
    /// `mermaid.min.js`.
    ///
    /// - Parameters:
    ///   - code: The raw Mermaid diagram source code.
    ///   - theme: The application theme to apply via Mermaid.js themeVariables.
    /// - Returns: A ``TemplateFileResult`` with the temp file and bundle
    ///   directory URLs, or `nil` if the template could not be loaded or written.
    static func writeTemplateFile(code: String, theme: AppTheme) -> TemplateFileResult? {
        guard let html = loadTemplate(code: code, theme: theme) else {
            return nil
        }

        guard let bundleDirectoryURL = Bundle.module
            .url(forResource: "mermaid-template", withExtension: "html")?
            .deletingLastPathComponent()
        else {
            return nil
        }

        let tempFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")

        guard let data = html.data(using: .utf8) else {
            return nil
        }

        do {
            try data.write(to: tempFileURL, options: .atomic)
        } catch {
            return nil
        }

        return TemplateFileResult(
            tempFileURL: tempFileURL,
            bundleDirectoryURL: bundleDirectoryURL
        )
    }

    /// Removes a previously written temporary template file.
    ///
    /// Safe to call with any URL; failures are silently ignored.
    static func cleanUpTemplateFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Escapes a string for safe embedding in HTML content.
    static func htmlEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// Escapes a string for safe embedding in JavaScript template literals.
    static func jsEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
    }

    /// Generates a JavaScript snippet that calls `reRenderWithTheme()`
    /// with the given theme's variables JSON.
    ///
    /// - Parameter theme: The application theme to apply.
    /// - Returns: A JavaScript string suitable for `evaluateJavaScript(_:)`.
    static func reRenderScript(theme: AppTheme) -> String {
        let themeJSON = MermaidThemeMapper.themeVariablesJSON(for: theme)
        return "reRenderWithTheme(\(themeJSON));"
    }
}
