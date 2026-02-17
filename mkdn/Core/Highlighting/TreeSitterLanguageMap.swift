import SwiftTreeSitter
import TreeSitterBash
import TreeSitterC
import TreeSitterCPP
import TreeSitterCSS
import TreeSitterGo
import TreeSitterHTML
import TreeSitterJava
import TreeSitterJavaScript
import TreeSitterJSON
import TreeSitterKotlin
import TreeSitterPython
import TreeSitterRuby
import TreeSitterRust
import TreeSitterSwift
import TreeSitterTypeScript
import TreeSitterYAML

/// Configuration for a supported tree-sitter language.
struct LanguageConfig: Sendable {
    let language: Language
    let highlightQuery: String
}

/// Maps Markdown fence language tags to tree-sitter language configurations.
enum TreeSitterLanguageMap {
    private static let aliases: [String: String] = [
        "js": "javascript",
        "ts": "typescript",
        "py": "python",
        "rb": "ruby",
        "sh": "bash",
        "shell": "bash",
        "yml": "yaml",
        "cpp": "c++",
    ]

    /// Resolve a language tag to a LanguageConfig, or nil if unsupported.
    static func configuration(for tag: String) -> LanguageConfig? {
        let normalized = tag.lowercased().trimmingCharacters(in: .whitespaces)
        let canonical = aliases[normalized] ?? normalized
        return languageConfigs[canonical]
    }

    // swiftlint:disable closure_body_length
    private static let languageConfigs: [String: LanguageConfig] = {
        var configs = [String: LanguageConfig]()
        configs["swift"] = LanguageConfig(
            language: Language(language: tree_sitter_swift()),
            highlightQuery: HighlightQueries.swift
        )
        configs["python"] = LanguageConfig(
            language: Language(language: tree_sitter_python()),
            highlightQuery: HighlightQueries.python
        )
        configs["javascript"] = LanguageConfig(
            language: Language(language: tree_sitter_javascript()),
            highlightQuery: HighlightQueries.javascript
        )
        configs["typescript"] = LanguageConfig(
            language: Language(language: tree_sitter_typescript()),
            highlightQuery: HighlightQueries.typescript
        )
        configs["rust"] = LanguageConfig(
            language: Language(language: tree_sitter_rust()),
            highlightQuery: HighlightQueries.rust
        )
        configs["go"] = LanguageConfig(
            language: Language(language: tree_sitter_go()),
            highlightQuery: HighlightQueries.go
        )
        configs["bash"] = LanguageConfig(
            language: Language(language: tree_sitter_bash()),
            highlightQuery: HighlightQueries.bash
        )
        configs["json"] = LanguageConfig(
            language: Language(language: tree_sitter_json()),
            highlightQuery: HighlightQueries.json
        )
        configs["yaml"] = LanguageConfig(
            language: Language(language: tree_sitter_yaml()),
            highlightQuery: HighlightQueries.yaml
        )
        configs["html"] = LanguageConfig(
            language: Language(language: tree_sitter_html()),
            highlightQuery: HighlightQueries.html
        )
        configs["css"] = LanguageConfig(
            language: Language(language: tree_sitter_css()),
            highlightQuery: HighlightQueries.css
        )
        configs["c"] = LanguageConfig(
            language: Language(language: tree_sitter_c()),
            highlightQuery: HighlightQueries.cLang
        )
        configs["c++"] = LanguageConfig(
            language: Language(language: tree_sitter_cpp()),
            highlightQuery: HighlightQueries.cpp
        )
        configs["ruby"] = LanguageConfig(
            language: Language(language: tree_sitter_ruby()),
            highlightQuery: HighlightQueries.ruby
        )
        configs["java"] = LanguageConfig(
            language: Language(language: tree_sitter_java()),
            highlightQuery: HighlightQueries.java
        )
        configs["kotlin"] = LanguageConfig(
            language: Language(language: tree_sitter_kotlin()),
            highlightQuery: HighlightQueries.kotlin
        )
        return configs
    }()

    // swiftlint:enable closure_body_length

    /// All supported canonical language names.
    static var supportedLanguages: [String] {
        Array(languageConfigs.keys).sorted()
    }
}
