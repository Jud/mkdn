import Testing

@testable import mkdnLib

@Suite("TreeSitterLanguageMap")
struct TreeSitterLanguageMapTests {
    // MARK: - Canonical Name Resolution

    @Test(
        "All 16 canonical language names resolve to a configuration",
        arguments: [
            "swift", "python", "javascript", "typescript", "rust", "go",
            "bash", "json", "yaml", "html", "css", "c", "c++", "ruby",
            "java", "kotlin",
        ]
    )
    func canonicalNameResolves(language: String) {
        let config = TreeSitterLanguageMap.configuration(for: language)
        #expect(config != nil, "Expected configuration for canonical name '\(language)'")
    }

    @Test("supportedLanguages returns all 16 canonical names sorted")
    func supportedLanguagesCount() {
        let supported = TreeSitterLanguageMap.supportedLanguages
        #expect(supported.count == 16)
        #expect(supported == supported.sorted())
    }

    // MARK: - Alias Resolution

    @Test(
        "Language aliases resolve to the correct canonical configuration",
        arguments: [
            ("js", "javascript"),
            ("ts", "typescript"),
            ("py", "python"),
            ("rb", "ruby"),
            ("sh", "bash"),
            ("shell", "bash"),
            ("yml", "yaml"),
            ("cpp", "c++"),
        ]
    )
    func aliasResolves(alias: String, canonical: String) {
        let aliasConfig = TreeSitterLanguageMap.configuration(for: alias)
        let canonicalConfig = TreeSitterLanguageMap.configuration(for: canonical)

        #expect(aliasConfig != nil, "Expected alias '\(alias)' to resolve")
        #expect(canonicalConfig != nil, "Expected canonical '\(canonical)' to resolve")
        #expect(
            aliasConfig?.highlightQuery == canonicalConfig?.highlightQuery,
            "Alias '\(alias)' should resolve to same config as '\(canonical)'"
        )
    }

    // MARK: - Case Insensitive Lookup

    @Test(
        "Language tag lookup is case-insensitive",
        arguments: ["Python", "PYTHON", "python", "pYtHoN"]
    )
    func caseInsensitiveLookup(tag: String) {
        let config = TreeSitterLanguageMap.configuration(for: tag)
        #expect(config != nil, "Expected case-insensitive resolution for '\(tag)'")
    }

    @Test("Alias lookup is case-insensitive")
    func aliasLookupCaseInsensitive() {
        #expect(TreeSitterLanguageMap.configuration(for: "JS") != nil)
        #expect(TreeSitterLanguageMap.configuration(for: "Ts") != nil)
        #expect(TreeSitterLanguageMap.configuration(for: "SH") != nil)
        #expect(TreeSitterLanguageMap.configuration(for: "YML") != nil)
    }

    // MARK: - Unsupported and Edge Cases

    @Test("Unsupported language returns nil")
    func unsupportedLanguageReturnsNil() {
        #expect(TreeSitterLanguageMap.configuration(for: "elixir") == nil)
        #expect(TreeSitterLanguageMap.configuration(for: "haskell") == nil)
        #expect(TreeSitterLanguageMap.configuration(for: "lua") == nil)
    }

    @Test("Empty string returns nil")
    func emptyStringReturnsNil() {
        #expect(TreeSitterLanguageMap.configuration(for: "") == nil)
    }

    @Test("Whitespace-padded tags resolve correctly")
    func whitespacePaddedTagResolves() {
        #expect(TreeSitterLanguageMap.configuration(for: " python ") != nil)
        #expect(TreeSitterLanguageMap.configuration(for: "  swift  ") != nil)
        #expect(TreeSitterLanguageMap.configuration(for: " js ") != nil)
    }
}
