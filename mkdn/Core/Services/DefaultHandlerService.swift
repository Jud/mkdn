import AppKit
import UniformTypeIdentifiers

/// Encapsulates Launch Services interaction for registering mkdn as the
/// system default handler for Markdown files.
@MainActor
public enum DefaultHandlerService {
    private static let markdownType = UTType("net.daringfireball.markdown")
        ?? UTType(filenameExtension: "md") ?? .plainText

    /// Register mkdn as the system default handler for Markdown files.
    /// Returns `true` after calling the system API. The registration is
    /// a no-op in sandboxed environments but does not crash.
    @discardableResult
    public static func registerAsDefault() -> Bool {
        let appURL = Bundle.main.bundleURL
        NSWorkspace.shared.setDefaultApplication(
            at: appURL,
            toOpen: markdownType
        )
        return true
    }

    /// Check whether mkdn is currently the default handler for Markdown files.
    public static func isDefault() -> Bool {
        let appURL = Bundle.main.bundleURL
        guard let defaultApp = NSWorkspace.shared.urlForApplication(
            toOpen: markdownType
        )
        else {
            return false
        }
        return defaultApp.path == appURL.path
    }
}
