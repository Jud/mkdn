import ArgumentParser

public struct MkdnCLI: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "mkdn",
        abstract: "A Mac-native Markdown viewer.",
        version: "1.0.0"
    )

    @Argument(help: "Path to a Markdown file (.md or .markdown).")
    public var file: String?

    public init() {}
}
