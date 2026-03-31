#if os(macOS)
    import Foundation

    /// Git file status categories derived from `--porcelain=v1` output.
    public enum GitFileStatus: String, Sendable, Hashable {
        case modified
        case added
        case deleted
        case untracked
        case renamed
    }

    /// Parses `git status --porcelain=v1 -z` output into a dictionary
    /// mapping repo-relative paths to their ``GitFileStatus``.
    ///
    /// Stateless enum following the ``DirectoryScanner`` pattern.
    public enum GitStatusParser {
        /// Parse NUL-delimited porcelain v1 status output.
        ///
        /// - Parameter data: Raw output from `git status --porcelain=v1 -z`.
        /// - Returns: Dictionary of repo-relative path → status.
        public static func parse(_ data: Data) -> [String: GitFileStatus] {
            guard !data.isEmpty else { return [:] }

            guard let raw = String(bytes: data, encoding: .utf8) else { return [:] }
            // Split on NUL; filter empty trailing element
            var fields = raw.split(separator: "\0", omittingEmptySubsequences: false)
            if fields.last?.isEmpty == true { fields.removeLast() }

            var result: [String: GitFileStatus] = [:]
            var index = fields.startIndex

            while index < fields.endIndex {
                let entry = fields[index]
                guard entry.count >= 4 else {
                    index = fields.index(after: index)
                    continue
                }

                let xChar = entry[entry.startIndex]
                let yChar = entry[entry.index(after: entry.startIndex)]
                let pathStart = entry.index(entry.startIndex, offsetBy: 3)
                let path = String(entry[pathStart...])

                let status = statusFrom(x: xChar, y: yChar)
                result[path] = status

                index = fields.index(after: index)

                // Rename entries have a second field for the original path
                if xChar == "R" || yChar == "R" {
                    if index < fields.endIndex {
                        index = fields.index(after: index) // skip original path
                    }
                }
            }

            return result
        }

        // MARK: - Private

        private static func statusFrom(x: Character, y: Character) -> GitFileStatus {
            // Untracked
            if x == "?", y == "?" { return .untracked }

            // Working tree (Y) takes precedence when non-space
            if y != " " {
                switch y {
                case "M": return .modified
                case "D": return .deleted
                case "A": return .added
                case "R": return .renamed
                default: break
                }
            }

            // Index (X) column
            switch x {
            case "M": return .modified
            case "A": return .added
            case "D": return .deleted
            case "R": return .renamed
            default: return .modified // fallback for unusual combos
            }
        }
    }
#endif
