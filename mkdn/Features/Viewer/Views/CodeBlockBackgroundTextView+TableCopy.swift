import AppKit

/// Table-aware clipboard handling for `CodeBlockBackgroundTextView`.
///
/// When the user presses Cmd+C and the selection includes table text
/// (identified by ``TableAttributes/cellMap`` attributes in the text storage),
/// this extension builds a mixed clipboard with:
/// - **RTF** (`.rtf` pasteboard type): paragraph text as plain RTF paragraphs,
///   table content as `\trowd`/`\cell`/`\row` RTF table markup.
/// - **Tab-delimited plain text** (`.string` pasteboard type): paragraph text
///   verbatim, table content with columns separated by tabs and rows by newlines.
///
/// When no table text is in the selection, ``handleTableCopy()`` returns `false`
/// and the caller falls through to `super.copy(_:)`.
extension CodeBlockBackgroundTextView {
    // MARK: - Types

    private struct TableSegment {
        let absoluteRange: NSRange
        let cellMap: TableCellMap
        let colorInfo: TableColorInfo
    }

    // MARK: - Entry Point

    /// Attempts to handle Cmd+C when the selection includes table text.
    ///
    /// Returns `true` if table text was found and the clipboard was populated.
    /// Returns `false` if no table text is in the selection (caller should
    /// delegate to `super.copy`).
    func handleTableCopy() -> Bool {
        guard let textStorage,
              let selectedValue = selectedRanges.first
        else { return false }

        let range = selectedValue.rangeValue
        guard range.length > 0 else { return false }

        let segments = collectTableSegments(in: range, textStorage: textStorage)
        guard !segments.isEmpty else { return false }

        let (rtfData, plainText) = buildMixedClipboard(
            selectedRange: range,
            tableSegments: segments,
            textStorage: textStorage
        )

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if let rtfData {
            pasteboard.setData(rtfData, forType: .rtf)
        }
        pasteboard.setString(plainText, forType: .string)
        return true
    }

    // MARK: - Table Segment Collection

    private func collectTableSegments(
        in selectedRange: NSRange,
        textStorage: NSTextStorage
    ) -> [TableSegment] {
        var segments: [TableSegment] = []
        var seenCellMaps: Set<ObjectIdentifier> = []

        textStorage.enumerateAttribute(
            TableAttributes.cellMap,
            in: selectedRange,
            options: []
        ) { value, subRange, _ in
            guard let cellMap = value as? TableCellMap else { return }
            let mapID = ObjectIdentifier(cellMap)
            guard !seenCellMaps.contains(mapID) else { return }
            seenCellMaps.insert(mapID)

            var fullRange = NSRange()
            textStorage.attribute(
                TableAttributes.cellMap,
                at: subRange.location,
                longestEffectiveRange: &fullRange,
                in: NSRange(location: 0, length: textStorage.length)
            )

            guard let colorInfo = textStorage.attribute(
                TableAttributes.colors,
                at: subRange.location,
                effectiveRange: nil
            ) as? TableColorInfo
            else { return }

            segments.append(TableSegment(
                absoluteRange: fullRange,
                cellMap: cellMap,
                colorInfo: colorInfo
            ))
        }

        return segments.sorted { $0.absoluteRange.location < $1.absoluteRange.location }
    }

    // MARK: - Mixed Clipboard Builder

    private func buildMixedClipboard(
        selectedRange: NSRange,
        tableSegments: [TableSegment],
        textStorage: NSTextStorage
    ) -> (rtfData: Data?, plainText: String) {
        let nsString = textStorage.string as NSString // swiftlint:disable:this legacy_objc_type
        var plainParts: [String] = []
        var rtfBodyParts: [String] = []
        var cursor = selectedRange.location
        let end = selectedRange.location + selectedRange.length

        for segment in tableSegments {
            let intersection = NSIntersectionRange(selectedRange, segment.absoluteRange)
            guard intersection.length > 0 else { continue }

            if cursor < intersection.location {
                let textRange = NSRange(
                    location: cursor,
                    length: intersection.location - cursor
                )
                let text = nsString.substring(with: textRange)
                plainParts.append(text)
                rtfBodyParts.append(rtfParagraphs(from: text))
            }

            let relativeRange = NSRange(
                location: intersection.location - segment.absoluteRange.location,
                length: intersection.length
            )
            let selectedCells = segment.cellMap.cellsInRange(relativeRange)

            if !selectedCells.isEmpty {
                plainParts.append(
                    segment.cellMap.tabDelimitedText(for: selectedCells)
                )
                rtfBodyParts.append(
                    rtfTableRows(
                        cellMap: segment.cellMap,
                        selectedCells: selectedCells,
                        isHeaderBold: true
                    )
                )
            }

            cursor = intersection.location + intersection.length
        }

        if cursor < end {
            let textRange = NSRange(location: cursor, length: end - cursor)
            let text = nsString.substring(with: textRange)
            plainParts.append(text)
            rtfBodyParts.append(rtfParagraphs(from: text))
        }

        let plainText = plainParts.joined()
        let colorInfo = tableSegments[0].colorInfo
        let rtfData = rtfDocument(
            body: rtfBodyParts.joined(),
            colorInfo: colorInfo
        ).data(using: .utf8)

        return (rtfData: rtfData, plainText: plainText)
    }

    // MARK: - RTF Document Assembly

    private func rtfDocument(body: String, colorInfo: TableColorInfo) -> String {
        let fgRGB = srgbComponents(colorInfo.foreground)
        let hdRGB = srgbComponents(colorInfo.headingColor)

        var rtf = "{\\rtf1\\ansi\\deff0\n"
        rtf += "{\\fonttbl{\\f0 Helvetica;}}\n"
        rtf += "{\\colortbl;"
        rtf += "\\red\(fgRGB.r)\\green\(fgRGB.g)\\blue\(fgRGB.b);"
        rtf += "\\red\(hdRGB.r)\\green\(hdRGB.g)\\blue\(hdRGB.b);"
        rtf += "}\n"
        rtf += body
        rtf += "}"
        return rtf
    }

    // MARK: - RTF Table Rows

    private func rtfTableRows(
        cellMap: TableCellMap,
        selectedCells: Set<TableCellMap.CellPosition>,
        isHeaderBold: Bool
    ) -> String {
        let cellsByPosition = Dictionary(
            cellMap.cells.map { ($0.position, $0.content) }
        ) { first, _ in first }

        let rows = Set(selectedCells.map(\.row)).sorted()
        let twips = cumulativeTwips(from: cellMap.columnWidths)

        var rtf = ""
        for row in rows {
            let isHeader = row == -1
            rtf += "\\trowd\\trgaph108"
            for twip in twips {
                rtf += "\\cellx\(twip)"
            }
            rtf += "\n"

            let colorIndex = isHeader ? 2 : 1
            let fontStyle = isHeader && isHeaderBold ? "\\b" : ""

            for col in 0 ..< cellMap.columnCount {
                let pos = TableCellMap.CellPosition(row: row, column: col)
                let content: String = if selectedCells.contains(pos) {
                    rtfEscaped(cellsByPosition[pos] ?? "")
                } else {
                    ""
                }
                rtf += "\\intbl\\cf\(colorIndex)\(fontStyle) \(content)\\cell\n"
            }
            rtf += "\\row\n"
        }
        return rtf
    }

    // MARK: - RTF Plain Text Paragraphs

    private func rtfParagraphs(from text: String) -> String {
        guard !text.isEmpty else { return "" }
        let escaped = rtfEscaped(text)
        let withBreaks = escaped.replacingOccurrences(
            of: "\n",
            with: "\\par\n"
        )
        return "\\pard\\cf1 " + withBreaks
    }

    // MARK: - RTF Helpers

    private func rtfEscaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "{", with: "\\{")
            .replacingOccurrences(of: "}", with: "\\}")
    }

    private func srgbComponents(
        _ color: NSColor
    ) -> (r: Int, g: Int, b: Int) {
        let converted = color.usingColorSpace(.sRGB) ?? color
        return (
            r: Int(converted.redComponent * 255),
            g: Int(converted.greenComponent * 255),
            b: Int(converted.blueComponent * 255)
        )
    }

    private func cumulativeTwips(from columnWidths: [CGFloat]) -> [Int] {
        var cumulative: CGFloat = 0
        return columnWidths.map { width in
            cumulative += width
            return Int(cumulative * 20)
        }
    }
}
