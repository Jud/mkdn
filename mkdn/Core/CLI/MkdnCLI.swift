import ArgumentParser

public struct MkdnCLI: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "mkdn",
        abstract: "A Mac-native Markdown viewer.",
        version: "1.0.0"
    )

    @Argument(help: "Path(s) to Markdown file(s) (.md or .markdown).")
    public var files: [String] = []

    public init() {}
}
