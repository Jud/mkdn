import ArgumentParser

public struct MkdnCLI: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "mkdn",
        abstract: "A Mac-native Markdown viewer.",
        version: "0.1.1"
    )

    @Argument(help: "Path(s) to Markdown file(s) or director(ies).")
    public var files: [String] = []

    public init() {}
}
