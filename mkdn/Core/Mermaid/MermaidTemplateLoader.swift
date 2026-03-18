import Foundation

/// Shared utility for loading and preparing Mermaid HTML templates.
///
/// Extracts template loading, string escaping, and re-render script
/// generation so that both macOS `MermaidWebView` and iOS
/// `MermaidWebViewiOS` share the same logic without duplication.
enum MermaidTemplateLoader {
    /// Safe accessor for the mkdnLib resource bundle.
    ///
    /// SPM's generated `Bundle.module` calls `fatalError` when the bundle
    /// isn't found.  This happens when the binary is launched via a symlink
    /// (e.g. Homebrew's `/opt/homebrew/bin/mkdn` → `.app/Contents/MacOS/mkdn`)
    /// because `Bundle.main` doesn't detect the `.app` structure from the
    /// symlink path.  This accessor follows symlinks and returns `nil`
    /// instead of crashing.
    private static let resourceBundle: Bundle? = {
        let bundleName = "mkdn_mkdnLib.bundle"

        // 1. Bundle.main.resourceURL — works when launched directly from .app
        if let url = Bundle.main.resourceURL,
           let bundle = Bundle(url: url.appendingPathComponent(bundleName))
        {
            return bundle
        }

        // 2. Alongside main bundle — SPM build output / dev builds
        if let bundle = Bundle(
            url: Bundle.main.bundleURL.appendingPathComponent(bundleName)
        ) {
            return bundle
        }

        // 3. Resolve symlinks and navigate from .app/Contents/MacOS/mkdn
        //    up to .app/Contents/Resources/
        let execURL = (Bundle.main.executableURL
            ?? URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0]))
            .resolvingSymlinksInPath()

        let resourcesURL = execURL
            .deletingLastPathComponent()   // MacOS/
            .deletingLastPathComponent()   // Contents/
            .appendingPathComponent("Resources")
            .appendingPathComponent(bundleName)
        if let bundle = Bundle(url: resourcesURL) {
            return bundle
        }

        // 4. Dev build: bundle next to the executable
        if let bundle = Bundle(
            url: execURL.deletingLastPathComponent()
                .appendingPathComponent(bundleName)
        ) {
            return bundle
        }

        // 5. Fall back to SPM's generated Bundle.module (has hardcoded
        //    build path — always works in dev/test, never reached in
        //    release because the checks above cover .app and symlink cases).
        return Bundle.module
    }()
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
        guard let templateURL = resourceBundle?.url(
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

    /// Shared temp directory containing a symlink to the bundled `mermaid.min.js`.
    ///
    /// Created once per process. Each diagram gets its own HTML file in this
    /// directory so that the relative `<script src="mermaid.min.js">` in the
    /// template resolves correctly.
    private nonisolated(unsafe) static var sharedTempDirectory: URL?

    /// Writes the substituted Mermaid HTML template to a temporary file
    /// in a directory alongside `mermaid.min.js`, so that both the HTML
    /// and the script are accessible via `loadFileURL(_:allowingReadAccessTo:)`.
    ///
    /// - Parameters:
    ///   - code: The raw Mermaid diagram source code.
    ///   - theme: The application theme to apply via Mermaid.js themeVariables.
    /// - Returns: A ``TemplateFileResult`` with the temp file and directory
    ///   URLs, or `nil` if the template could not be loaded or written.
    static func writeTemplateFile(code: String, theme: AppTheme) -> TemplateFileResult? {
        guard let html = loadTemplate(code: code, theme: theme) else {
            return nil
        }

        guard let tempDir = ensureSharedTempDirectory() else {
            return nil
        }

        let tempFileURL = tempDir
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
            bundleDirectoryURL: tempDir
        )
    }

    /// Creates (if needed) a shared temp directory with a copy of
    /// the bundled `mermaid.min.js`.
    ///
    /// A hard copy is used instead of a symlink because WebKit resolves
    /// symlinks before checking `allowingReadAccessTo:`, so a symlink
    /// pointing outside the allowed directory is denied.
    private static func ensureSharedTempDirectory() -> URL? {
        if let existing = sharedTempDirectory,
           FileManager.default.fileExists(atPath: existing.path)
        {
            return existing
        }

        guard let mermaidJSURL = resourceBundle?.url(
            forResource: "mermaid.min",
            withExtension: "js"
        )
        else {
            return nil
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mkdn-mermaid")

        do {
            try FileManager.default.createDirectory(
                at: tempDir,
                withIntermediateDirectories: true
            )

            let destURL = tempDir.appendingPathComponent("mermaid.min.js")
            if FileManager.default.fileExists(atPath: destURL.path) {
                try? FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: mermaidJSURL, to: destURL)

            sharedTempDirectory = tempDir
            return tempDir
        } catch {
            return nil
        }
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
