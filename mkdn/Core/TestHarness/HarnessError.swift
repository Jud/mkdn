import Foundation

/// Errors that can occur in the test harness infrastructure.
public enum HarnessError: LocalizedError, Sendable {
    /// Render did not complete within the expected timeout.
    case renderTimeout

    /// The socket connection could not be established.
    case connectionFailed(String)

    /// A command received an unexpected response.
    case unexpectedResponse(String)

    /// The server received an unrecognized command.
    case unknownCommand(String)

    /// The capture operation failed.
    case captureFailed(String)

    /// The requested file could not be loaded.
    case fileLoadFailed(String)

    public var errorDescription: String? {
        switch self {
        case .renderTimeout:
            "Render did not complete within the expected timeout."
        case let .connectionFailed(detail):
            "Socket connection failed: \(detail)"
        case let .unexpectedResponse(detail):
            "Unexpected response from harness: \(detail)"
        case let .unknownCommand(cmd):
            "Unknown harness command: \(cmd)"
        case let .captureFailed(detail):
            "Window capture failed: \(detail)"
        case let .fileLoadFailed(detail):
            "File load failed: \(detail)"
        }
    }
}
