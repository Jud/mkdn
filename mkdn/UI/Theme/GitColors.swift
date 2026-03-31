#if os(macOS)
    import SwiftUI

    /// Solarized-based colors and badge letters for git file statuses.
    public enum GitColors {
        /// Color for a git status badge, using Solarized accent colors.
        public static func color(for status: GitFileStatus) -> Color {
            switch status {
            case .modified:
                Color(red: 0.710, green: 0.537, blue: 0.000) // Solarized yellow
            case .added, .untracked:
                Color(red: 0.522, green: 0.600, blue: 0.000) // Solarized green
            case .deleted:
                Color(red: 0.863, green: 0.196, blue: 0.184) // Solarized red
            case .renamed:
                Color(red: 0.149, green: 0.545, blue: 0.824) // Solarized blue
            }
        }

        /// Single-letter badge for a git status.
        public static func badge(for status: GitFileStatus) -> String {
            switch status {
            case .modified: "M"
            case .added: "A"
            case .deleted: "D"
            case .untracked: "?"
            case .renamed: "R"
            }
        }
    }
#endif
