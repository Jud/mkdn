import Foundation

public enum CLIError: LocalizedError {
    case unsupportedExtension(path: String, ext: String)
    case fileNotFound(resolvedPath: String)
    case fileNotReadable(resolvedPath: String, reason: String)
    case directoryNotFound(resolvedPath: String)
    case directoryNotReadable(resolvedPath: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedExtension(path, ext):
            let extText = ext.isEmpty ? "no extension" : ".\(ext)"
            return "unsupported file type '\(extText)' for '\(path)'. Accepted: markdown, source code, and text files"
        case let .fileNotFound(resolvedPath):
            return "file not found: \(resolvedPath)"
        case let .fileNotReadable(resolvedPath, reason):
            return "cannot read file: \(resolvedPath) (\(reason))"
        case let .directoryNotFound(resolvedPath):
            return "directory not found: \(resolvedPath)"
        case let .directoryNotReadable(resolvedPath, reason):
            return "cannot read directory: \(resolvedPath) (\(reason))"
        }
    }

    public var exitCode: Int32 {
        switch self {
        case .unsupportedExtension, .fileNotFound, .directoryNotFound:
            1
        case .fileNotReadable, .directoryNotReadable:
            2
        }
    }
}
