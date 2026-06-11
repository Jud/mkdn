import AppKit
import Testing
@testable import mkdnLib

@Suite("TableCellTextLayout")
@MainActor
struct TableTextLayoutTests {
    private func makeLayout(
        _ text: String, wrapWidth: CGFloat = 400, isHeader: Bool = false
    ) -> TableCellTextLayout {
        TableCellTextLayout(
            text: AttributedString(text),
            isHeader: isHeader,
            wrapWidth: wrapWidth,
            scaleFactor: 1.0
        )
    }

    @Test("Hit-testing maps x positions to the caret offsets Core Text measures")
    func characterOffsetMatchesMeasuredWidths() {
        let layout = makeLayout("alpha beta gamma")
        let font = PlatformTypeConverter.bodyFont()
        let prefixWidth = NSAttributedString(
            string: "alpha ", attributes: [.font: font]
        ).size().width
        let lineMid = PlatformTypeConverter.lineHeight(of: font) / 2

        // Just past the prefix lands on offset 6 ("b" of beta).
        let offset = layout.characterOffset(at: CGPoint(x: prefixWidth + 1, y: lineMid))
        #expect(offset == 6)
        // Far left clamps to 0, far right to the text length.
        #expect(layout.characterOffset(at: CGPoint(x: -50, y: lineMid)) == 0)
        #expect(layout.characterOffset(at: CGPoint(x: 5_000, y: lineMid)) == 16)
    }

    @Test("Word range at an offset has double-click semantics")
    func wordRangeAtOffset() {
        let layout = makeLayout("alpha beta gamma")
        #expect(layout.wordRange(at: 7) == NSRange(location: 6, length: 4))
        #expect(layout.wordRange(at: 0) == NSRange(location: 0, length: 5))
    }

    @Test("Selection rects: one per wrapped line")
    func selectionRectsPerLine() {
        let font = PlatformTypeConverter.bodyFont()
        let wordWidth = NSAttributedString(
            string: "between", attributes: [.font: font]
        ).size().width
        // Wide enough for one word per line only: the full range paints two rects.
        let layout = makeLayout("between boundary", wrapWidth: wordWidth + 2)
        let rects = layout.selectionRects(for: layout.fullRange)
        #expect(rects.count == 2)
        // Single line when unwrapped.
        let wide = makeLayout("between boundary")
        #expect(wide.selectionRects(for: wide.fullRange).count == 1)
    }

    @Test("Empty cell is inert: zero offsets, no rects")
    func emptyCell() {
        let layout = makeLayout("")
        #expect(layout.textLength == 0)
        #expect(layout.characterOffset(at: CGPoint(x: 10, y: 10)) == 0)
        #expect(layout.selectionRects(for: NSRange(location: 0, length: 0)).isEmpty)
        #expect(layout.wordRange(at: 0) == NSRange(location: 0, length: 0))
    }

    @Test("Header layout measures with the bold font")
    func headerUsesBoldFont() {
        let regular = makeLayout("WideHeaderText")
        let header = makeLayout("WideHeaderText", isHeader: true)
        #expect(header.usedWidth > regular.usedWidth)
    }
}
