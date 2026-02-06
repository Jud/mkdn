import ArgumentParser
import Foundation

/// Handles command-line argument parsing for `mkdn file.md`.
///
/// When the app is launched from the terminal with a file argument,
/// this struct parses the path and resolves it to a URL.
struct CLIHandler {
    /// Attempt to extract a file URL from process arguments.
    ///
    /// Checks `CommandLine.arguments` for a Markdown file path.
    /// Returns `nil` if no valid path was provided.
    static func fileURLFromArguments() -> URL? {
        let args = CommandLine.arguments

        // Skip the first argument (executable path).
        // Look for the first argument that looks like a file path.
        for arg in args.dropFirst() {
            // Skip flags
            guard !arg.hasPrefix("-") else { continue }

            let path = (arg as NSString).expandingTildeInPath
            let url: URL

            if path.hasPrefix("/") {
                url = URL(fileURLWithPath: path)
            } else {
                let cwd = FileManager.default.currentDirectoryPath
                url = URL(fileURLWithPath: cwd).appendingPathComponent(path)
            }

            // Validate the file exists and has a Markdown extension.
            let ext = url.pathExtension.lowercased()
            guard ext == "md" || ext == "markdown" else { continue }
            guard FileManager.default.fileExists(atPath: url.path) else { continue }

            return url
        }

        return nil
    }
}
