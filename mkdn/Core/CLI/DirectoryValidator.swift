import Foundation

public enum DirectoryValidator {
    /// Resolve a raw path string to a validated directory URL.
    /// Performs: tilde expansion, path resolution, symlink resolution,
    /// directory existence check, and readability check.
    /// Throws CLIError on any failure.
    public static func validate(path: String) throws -> URL {
        let resolved = FileValidator.resolvePath(path)
        try validateIsDirectory(url: resolved)
        try validateReadability(url: resolved)
        return resolved
    }

    static func validateIsDirectory(url: URL) throws {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            throw CLIError.directoryNotFound(resolvedPath: url.path)
        }
        guard isDir.boolValue else {
            throw CLIError.directoryNotFound(resolvedPath: url.path)
        }
    }

    static func validateReadability(url: URL) throws {
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw CLIError.directoryNotReadable(
                resolvedPath: url.path,
                reason: "permission denied"
            )
        }
    }
}
