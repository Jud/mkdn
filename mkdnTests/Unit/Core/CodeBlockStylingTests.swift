import AppKit
import Testing
@testable import mkdnLib

@Suite("CodeBlockStyling")
struct CodeBlockStylingTests {
    // MARK: - Helpers

    @MainActor private func buildSingle(
        _ block: MarkdownBlock,
        theme: AppTheme = .solarizedDark
    ) -> TextStorageResult {
        let indexed = IndexedBlock(index: 0, block: block)
        return MarkdownTextStorageBuilder.build(blocks: [indexed], theme: theme)
    }

    @MainActor private func collectRangeAttributes(
        from str: NSAttributedString
    ) -> [(value: String, range: NSRange)] {
        var results: [(value: String, range: NSRange)] = []
        str.enumerateAttribute(
            CodeBlockAttributes.range,
            in: NSRange(location: 0, length: str.length)
        ) { value, range, _ in
            if let blockID = value as? String {
                results.append((value: blockID, range: range))
            }
        }
        return results
    }

    @MainActor private func locationOf(_ substring: String, in text: String) -> Int? {
        guard let range = text.range(of: substring) else { return nil }
        return text.distance(from: text.startIndex, to: range.lowerBound)
    }

    // MARK: - Range Attribute

    @Test("Code block text carries codeBlockRange attribute with non-empty string")
    @MainActor func codeBlockRangeAttribute() {
        let result = buildSingle(.codeBlock(language: nil, code: "let x = 1"))
        let rangeAttrs = collectRangeAttributes(from: result.attributedString)

        #expect(!rangeAttrs.isEmpty)
        for attr in rangeAttrs {
            #expect(!attr.value.isEmpty)
        }
    }

    // MARK: - Color Info Attribute

    @Test(
        "Code block carries codeBlockColors with correct theme colors",
        arguments: AppTheme.allCases
    )
    @MainActor func codeBlockColorsAttribute(theme: AppTheme) {
        let result = buildSingle(.codeBlock(language: nil, code: "print(1)"), theme: theme)
        let str = result.attributedString

        let expectedBackground = PlatformTypeConverter.nsColor(from: theme.colors.codeBackground)
        let expectedBorder = PlatformTypeConverter.nsColor(from: theme.colors.border)

        var foundColorInfo = false
        str.enumerateAttribute(
            CodeBlockAttributes.colors,
            in: NSRange(location: 0, length: str.length)
        ) { value, _, _ in
            guard let info = value as? CodeBlockColorInfo else { return }
            foundColorInfo = true
            #expect(info.background == expectedBackground)
            #expect(info.border == expectedBorder)
        }
        #expect(foundColorInfo)
    }

    // MARK: - Paragraph Indent

    @Test("Code block paragraph style has headIndent of 12pt and tailIndent of -12pt")
    @MainActor func codeBlockParagraphIndent() {
        let result = buildSingle(.codeBlock(language: nil, code: "let x = 1"))
        let str = result.attributedString

        guard let location = locationOf("let x = 1", in: str.string) else {
            Issue.record("Expected to find code content in attributed string")
            return
        }

        let attrs = str.attributes(at: location, effectiveRange: nil)
        let style = attrs[.paragraphStyle] as? NSParagraphStyle

        #expect(style != nil)
        #expect(style?.headIndent == MarkdownTextStorageBuilder.codeBlockPadding)
        #expect(style?.firstLineHeadIndent == MarkdownTextStorageBuilder.codeBlockPadding)
        #expect(style?.tailIndent == -MarkdownTextStorageBuilder.codeBlockPadding)
    }

    // MARK: - No Per-Run Background Color

    @Test("Code block content does not have per-run backgroundColor attribute")
    @MainActor func noPerRunBackgroundColor() {
        let result = buildSingle(.codeBlock(language: "swift", code: "let x = 1"))
        let str = result.attributedString

        var hasBackgroundColor = false
        str.enumerateAttribute(
            .backgroundColor,
            in: NSRange(location: 0, length: str.length)
        ) { value, _, _ in
            if value != nil {
                hasBackgroundColor = true
            }
        }
        #expect(!hasBackgroundColor)
    }

    // MARK: - Swift Syntax Highlighting

    @Test("Swift code block has syntax highlighting with multiple foreground colors")
    @MainActor func swiftSyntaxHighlighting() {
        let swiftCode = "func greet() -> String { return \"hello\" }"

        let swiftResult = buildSingle(.codeBlock(language: "swift", code: swiftCode))
        let swiftStr = swiftResult.attributedString

        let plainResult = buildSingle(.codeBlock(language: nil, code: swiftCode))
        let plainStr = plainResult.attributedString

        guard let swiftCodeLoc = locationOf("func", in: swiftStr.string) else {
            Issue.record("Expected to find 'func' in Swift code block")
            return
        }
        guard let plainCodeLoc = locationOf("func", in: plainStr.string) else {
            Issue.record("Expected to find 'func' in plain code block")
            return
        }

        let swiftCodeRange = NSRange(location: swiftCodeLoc, length: swiftCode.count)
        let plainCodeRange = NSRange(location: plainCodeLoc, length: swiftCode.count)

        var swiftRunCount = 0
        swiftStr.enumerateAttributes(in: swiftCodeRange) { _, _, _ in
            swiftRunCount += 1
        }

        var plainRunCount = 0
        plainStr.enumerateAttributes(in: plainCodeRange) { _, _, _ in
            plainRunCount += 1
        }

        #expect(
            swiftRunCount > plainRunCount,
            "Swift code block should have more attribute runs than plain: swift=\(swiftRunCount) plain=\(plainRunCount)"
        )

        // Verify foreground colors are NSColor via the AppKit attribute key,
        // not SwiftUI-scoped keys that NSTextView cannot render.
        var foundNSColorForeground = false
        swiftStr.enumerateAttribute(
            .foregroundColor,
            in: swiftCodeRange
        ) { value, _, _ in
            if let color = value as? NSColor {
                foundNSColorForeground = true
                _ = color // suppress unused warning
            }
        }
        #expect(
            foundNSColorForeground,
            "Syntax-highlighted code must use NSAttributedString.Key.foregroundColor with NSColor values"
        )
    }

    // MARK: - Non-Swift Code Foreground

    @Test("Unsupported language code block uses codeForeground color")
    @MainActor func unsupportedLanguageCodeForeground() {
        let result = buildSingle(.codeBlock(language: "elixir", code: "IO.puts(\"hello\")"))
        let str = result.attributedString

        guard let location = locationOf("IO.puts", in: str.string) else {
            Issue.record("Expected to find code content in attributed string")
            return
        }
        let expected = PlatformTypeConverter.nsColor(from: AppTheme.solarizedDark.colors.codeForeground)

        let attrs = str.attributes(at: location, effectiveRange: nil)
        let color = attrs[.foregroundColor] as? NSColor
        #expect(color == expected)
    }

    // MARK: - Raw Code Attribute

    @Test("Code block carries rawCode attribute with trimmed code content")
    @MainActor func codeBlockRawCodeAttribute() {
        let code = "  let x = 1\n  let y = 2  "
        let result = buildSingle(.codeBlock(language: "swift", code: code))
        let str = result.attributedString

        guard let codeLocation = locationOf("let x = 1", in: str.string) else {
            Issue.record("Expected to find code content in attributed string")
            return
        }

        let rawCode = str.attribute(
            CodeBlockAttributes.rawCode,
            at: codeLocation,
            effectiveRange: nil
        ) as? String

        #expect(rawCode != nil)
        #expect(rawCode == code.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    @Test("Raw code attribute excludes language label text")
    @MainActor func rawCodeExcludesLanguageLabel() {
        let result = buildSingle(.codeBlock(language: "python", code: "print('hello')"))
        let str = result.attributedString

        guard let labelLocation = locationOf("python", in: str.string) else {
            Issue.record("Expected to find language label in attributed string")
            return
        }

        let labelRawCode = str.attribute(
            CodeBlockAttributes.rawCode,
            at: labelLocation,
            effectiveRange: nil
        ) as? String

        #expect(labelRawCode == nil || labelRawCode == "print('hello')")
    }

    // MARK: - Language Label Shares Block Range

    @Test("Language label carries same codeBlockRange as code body")
    @MainActor func languageLabelSharesBlockRange() {
        let result = buildSingle(.codeBlock(language: "swift", code: "let x = 1"))
        let str = result.attributedString

        guard let labelIndex = locationOf("swift", in: str.string) else {
            Issue.record("Expected to find language label in attributed string")
            return
        }
        guard let codeIndex = locationOf("let x = 1", in: str.string) else {
            Issue.record("Expected to find code content in attributed string")
            return
        }

        let labelAttrs = str.attributes(at: labelIndex, effectiveRange: nil)
        let codeAttrs = str.attributes(at: codeIndex, effectiveRange: nil)

        let labelBlockID = labelAttrs[CodeBlockAttributes.range] as? String
        let codeBlockID = codeAttrs[CodeBlockAttributes.range] as? String

        #expect(labelBlockID != nil)
        #expect(codeBlockID != nil)
        #expect(labelBlockID == codeBlockID)
    }
}
