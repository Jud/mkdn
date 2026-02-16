import AppKit
import UniformTypeIdentifiers

/// Encapsulates Launch Services interaction for registering mkdn as the
/// system default handler for Markdown files.
@MainActor
public enum DefaultHandlerService {
    private static let markdownType = UTType("net.daringfireball.markdown")
        ?? UTType(filenameExtension: "md") ?? .plainText

    private static let knownBundleID = "com.mkdn.app"

    /// Register mkdn as the system default handler for Markdown files.
    /// Returns `true` only when the registration is verified to have taken effect.
    @discardableResult
    public static func registerAsDefault() -> Bool {
        guard let appURL = resolveAppBundleURL() else {
            return false
        }
        NSWorkspace.shared.setDefaultApplication(
            at: appURL,
            toOpen: markdownType
        )
        return isDefault()
    }

    /// Check whether mkdn is currently the default handler for Markdown files.
    public static func isDefault() -> Bool {
        guard let appURL = resolveAppBundleURL(),
              let defaultApp = NSWorkspace.shared.urlForApplication(
                  toOpen: markdownType
              )
        else {
            return false
        }
        return defaultApp.standardizedFileURL == appURL.standardizedFileURL
    }

    /// Whether a `.app` bundle is available for registration.
    /// Returns `false` when running as a bare binary with no registered bundle,
    /// which means the default-handler prompt should be suppressed entirely.
    public static var canRegisterAsDefault: Bool {
        resolveAppBundleURL() != nil
    }

    /// Resolve the `.app` bundle URL for mkdn.
    /// Returns `nil` when no valid `.app` bundle can be found (e.g. running
    /// as a bare binary via `swift run`).
    private static func resolveAppBundleURL() -> URL? {
        let mainURL = Bundle.main.bundleURL
        if mainURL.pathExtension == "app" {
            return mainURL
        }
        // Running outside a .app bundle — ask Launch Services for a registered copy.
        let bundleID = Bundle.main.bundleIdentifier ?? knownBundleID
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }
}
