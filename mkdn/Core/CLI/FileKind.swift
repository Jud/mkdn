import Foundation

/// Classifies a file by its extension into a rendering category.
///
/// - ``markdown``: Standard Markdown files (.md, .markdown) -- rendered via
///   the existing MarkdownPreviewView pipeline.
/// - ``sourceCode(language:)``: Programming language files -- rendered with
///   tree-sitter syntax highlighting when available, plain monospaced otherwise.
/// - ``plainText``: Generic text files (.txt) -- rendered as plain monospaced text.
public enum FileKind: Equatable, Sendable {
    case markdown
    case sourceCode(language: String)
    case plainText

    /// The language name for source code files, nil otherwise.
    public var language: String? {
        switch self {
        case let .sourceCode(language):
            language
        default:
            nil
        }
    }
}

// MARK: - Extension Mapping

public extension URL {
    /// Classify this URL by its file extension into a ``FileKind``.
    /// Returns nil for unrecognized extensions.
    var fileKind: FileKind? {
        FileKind.from(extension: pathExtension)
    }

    /// Whether this URL points to a text file recognized by mkdn
    /// (Markdown, source code, or plain text).
    var isTextFile: Bool {
        fileKind != nil
    }
}

extension FileKind {
    /// Map a file extension to a FileKind.
    static func from(extension ext: String) -> FileKind? {
        let normalized = ext.lowercased()
        if markdownExtensions.contains(normalized) {
            return .markdown
        }
        if let language = extensionToLanguage[normalized] {
            return .sourceCode(language: language)
        }
        if plainTextExtensions.contains(normalized) {
            return .plainText
        }
        return nil
    }

    private static let markdownExtensions: Set<String> = ["md", "markdown"]

    private static let plainTextExtensions: Set<String> = ["txt"]

    private static let extensionToLanguage: [String: String] = {
        var map = [String: String]()
        // Languages with tree-sitter support
        map["swift"] = "swift"
        map["py"] = "python"
        map["js"] = "javascript"
        map["mjs"] = "javascript"
        map["cjs"] = "javascript"
        map["ts"] = "typescript"
        map["rs"] = "rust"
        map["go"] = "go"
        map["c"] = "c"
        map["h"] = "c"
        map["cpp"] = "c++"
        map["cc"] = "c++"
        map["cxx"] = "c++"
        map["hpp"] = "c++"
        map["java"] = "java"
        map["rb"] = "ruby"
        map["json"] = "json"
        map["yaml"] = "yaml"
        map["yml"] = "yaml"
        map["html"] = "html"
        map["htm"] = "html"
        map["css"] = "css"
        map["sh"] = "bash"
        map["bash"] = "bash"
        map["kt"] = "kotlin"
        // Languages without tree-sitter support
        map["toml"] = "toml"
        map["xml"] = "xml"
        map["sql"] = "sql"
        map["r"] = "r"
        map["lua"] = "lua"
        map["zig"] = "zig"
        return map
    }()

    /// All file extensions recognized by FileKind.
    static let allExtensions: Set<String> = {
        var exts = markdownExtensions
        exts.formUnion(plainTextExtensions)
        exts.formUnion(extensionToLanguage.keys)
        return exts
    }()
}
