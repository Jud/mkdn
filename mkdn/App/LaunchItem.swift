import Foundation

/// Discriminates file and directory arguments for WindowGroup routing.
///
/// Conforms to Hashable and Codable as required by SwiftUI's
/// `WindowGroup(for:)` scene value mechanism.
public enum LaunchItem: Hashable, Codable, Sendable {
    case file(URL)
    case directory(URL)

    /// The underlying URL regardless of type.
    public var url: URL {
        switch self {
        case let .file(url), let .directory(url):
            url
        }
    }
}
