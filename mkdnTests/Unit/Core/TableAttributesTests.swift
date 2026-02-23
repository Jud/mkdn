import AppKit
import Testing
@testable import mkdnLib

@Suite("TableAttributes")
struct TableAttributesTests {
    @Test("Table attribute keys are distinct from code block attribute keys")
    func attributeKeysDistinctFromCodeBlock() {
        let tableKeys: [NSAttributedString.Key] = [
            TableAttributes.range,
            TableAttributes.cellMap,
            TableAttributes.colors,
            TableAttributes.isHeader,
        ]
        let codeBlockKeys: [NSAttributedString.Key] = [
            CodeBlockAttributes.range,
            CodeBlockAttributes.colors,
            CodeBlockAttributes.rawCode,
        ]

        for tableKey in tableKeys {
            for codeKey in codeBlockKeys {
                #expect(tableKey != codeKey, "Table key \(tableKey) must not collide with code block key \(codeKey)")
            }
        }
    }

    @Test("Table attribute keys are unique among themselves")
    func attributeKeysUnique() {
        let keys: [NSAttributedString.Key] = [
            TableAttributes.range,
            TableAttributes.cellMap,
            TableAttributes.colors,
            TableAttributes.isHeader,
        ]

        let uniqueCount = Set(keys).count
        #expect(uniqueCount == keys.count, "All table attribute keys must be unique")
    }

    @Test("TableColorInfo stores resolved colors")
    func tableColorInfoStoresColors() {
        let bg = NSColor.red
        let bgSecondary = NSColor.blue
        let border = NSColor.green
        let headerBg = NSColor.yellow
        let fg = NSColor.white
        let heading = NSColor.orange

        let info = TableColorInfo(
            background: bg,
            backgroundSecondary: bgSecondary,
            border: border,
            headerBackground: headerBg,
            foreground: fg,
            headingColor: heading
        )

        #expect(info.background == bg)
        #expect(info.backgroundSecondary == bgSecondary)
        #expect(info.border == border)
        #expect(info.headerBackground == headerBg)
        #expect(info.foreground == fg)
        #expect(info.headingColor == heading)
    }

    @Test("TableColorInfo can be stored as NSAttributedString attribute value")
    func tableColorInfoAsAttribute() {
        let info = TableColorInfo(
            background: .red,
            backgroundSecondary: .blue,
            border: .green,
            headerBackground: .yellow,
            foreground: .white,
            headingColor: .orange
        )

        let str = NSMutableAttributedString(string: "test")
        str.addAttribute(
            TableAttributes.colors,
            value: info,
            range: NSRange(location: 0, length: str.length)
        )

        let retrieved = str.attribute(
            TableAttributes.colors,
            at: 0,
            effectiveRange: nil
        ) as? TableColorInfo

        #expect(retrieved === info)
    }
}
