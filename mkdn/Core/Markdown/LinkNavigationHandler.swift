import Foundation

/// Classifies and resolves link URLs for navigation within the Markdown viewer.
///
/// Handles three categories of links:
/// - **Local Markdown**: relative or absolute paths to `.md`/`.markdown` files,
///   opened in the same window (click) or a new window (Cmd+click).
/// - **External**: `http`, `https`, `mailto`, `tel`, and other scheme-based URLs,
///   opened in the default system handler.
/// - **Other local files**: non-Markdown local files, opened in the default app.
enum LinkNavigationHandler {
    /// The resolved destination for a clicked link.
    enum LinkDestination: Equatable {
        case localMarkdown(URL)
        case external(URL)
        case otherLocalFile(URL)
    }

    /// Classifies a link URL into its navigation destination.
    ///
    /// - Parameters:
    ///   - url: The URL from the `.link` attribute (constructed via `URL(string:)` in the visitor).
    ///   - documentURL: The currently open document's URL, used to resolve relative paths.
    /// - Returns: The classified destination with a fully resolved URL.
    static func classify(url: URL, relativeTo documentURL: URL?) -> LinkDestination {
        if let scheme = url.scheme?.lowercased() {
            switch scheme {
            case "http", "https", "mailto", "tel":
                return .external(url)
            case "file":
                return classifyLocalFile(url)
            default:
                return .external(url)
            }
        }

        let resolved = resolveRelativeURL(url, relativeTo: documentURL)
        return classifyLocalFile(resolved)
    }

    /// Resolves a schemeless URL against the document's parent directory.
    ///
    /// For anchor-only links (`#heading`) where the path is empty, returns the
    /// document URL itself. For relative paths like `other.md` or `../sibling.md`,
    /// appends to the document's directory and standardizes the result.
    static func resolveRelativeURL(_ url: URL, relativeTo documentURL: URL?) -> URL {
        let path = url.path
        guard !path.isEmpty else {
            return documentURL ?? url
        }

        guard let baseDir = documentURL?.deletingLastPathComponent() else {
            return url
        }

        return baseDir.appendingPathComponent(path).standardizedFileURL
    }

    // MARK: - Private

    private static func classifyLocalFile(_ url: URL) -> LinkDestination {
        if url.isMarkdownFile {
            return .localMarkdown(url)
        }
        return .otherLocalFile(url)
    }
}
