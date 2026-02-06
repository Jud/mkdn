import Foundation

public enum FileValidator {
    private static let acceptedExtensions: Set<String> = ["md", "markdown"]

    /// Resolve a raw path string to a validated file URL.
    /// Performs: tilde expansion, path resolution, symlink resolution,
    /// extension validation, existence check, and readability check.
    /// Throws CLIError on any failure.
    public static func validate(path: String) throws -> URL {
        let resolved = resolvePath(path)
        try validateExtension(url: resolved, originalPath: path)
        try validateExistence(url: resolved)
        try validateReadability(url: resolved)
        return resolved
    }

    /// Expand tilde, resolve relative paths against cwd, resolve symlinks.
    static func resolvePath(_ path: String) -> URL {
        let expanded = NSString(string: path).expandingTildeInPath
        let url: URL
        if expanded.hasPrefix("/") {
            url = URL(fileURLWithPath: expanded)
        } else {
            let cwd = FileManager.default.currentDirectoryPath
            url = URL(fileURLWithPath: cwd)
                .appendingPathComponent(expanded)
        }
        return url.standardized.resolvingSymlinksInPath()
    }

    /// Check that the file has a .md or .markdown extension (case-insensitive).
    static func validateExtension(url: URL, originalPath: String) throws {
        let ext = url.pathExtension.lowercased()
        guard acceptedExtensions.contains(ext) else {
            throw CLIError.unsupportedExtension(path: originalPath, ext: url.pathExtension)
        }
    }

    static func validateExistence(url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CLIError.fileNotFound(resolvedPath: url.path)
        }
    }

    /// Check that the file is readable and valid UTF-8.
    static func validateReadability(url: URL) throws {
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw CLIError.fileNotReadable(
                resolvedPath: url.path,
                reason: "permission denied"
            )
        }
        do {
            _ = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw CLIError.fileNotReadable(
                resolvedPath: url.path,
                reason: "file is not valid UTF-8 text"
            )
        }
    }
}
