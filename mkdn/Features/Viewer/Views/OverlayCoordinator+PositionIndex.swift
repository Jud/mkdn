import AppKit

/// Pre-built lookup indices for attachment and table range positions,
/// replacing O(n) enumeration with O(1) dictionary lookups.
extension OverlayCoordinator {
    /// Enumerates attachment and table-range attributes once and builds
    /// dictionaries for O(1) lookup in `attachmentRange(for:in:)` and
    /// `findTableTextRange(for:in:)`.
    func buildPositionIndex(from textStorage: NSTextStorage) {
        attachmentIndex.removeAll()
        tableRangeIndex.removeAll()

        let fullRange = NSRange(location: 0, length: textStorage.length)

        textStorage.enumerateAttribute(
            .attachment, in: fullRange, options: []
        ) { value, range, _ in
            if let attachment = value as? NSTextAttachment {
                attachmentIndex[ObjectIdentifier(attachment)] = range
            }
        }

        textStorage.enumerateAttribute(
            TableAttributes.range, in: fullRange, options: []
        ) { value, attrRange, _ in
            guard let ident = value as? String else { return }
            if let existing = tableRangeIndex[ident] {
                tableRangeIndex[ident] = NSUnionRange(existing, attrRange)
            } else {
                tableRangeIndex[ident] = attrRange
            }
        }
    }
}
