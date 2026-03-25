#if os(macOS)
    import AppKit

    /// Pre-built lookup index for attachment positions,
    /// replacing O(n) enumeration with O(1) dictionary lookups.
    extension OverlayCoordinator {
        /// Enumerates attachment attributes once and builds a dictionary
        /// for O(1) lookup in `attachmentRange(for:)`.
        func buildPositionIndex(from textStorage: NSTextStorage) {
            attachmentIndex.removeAll()

            let fullRange = NSRange(location: 0, length: textStorage.length)

            textStorage.enumerateAttribute(
                .attachment, in: fullRange, options: []
            ) { value, range, _ in
                if let attachment = value as? NSTextAttachment {
                    attachmentIndex[ObjectIdentifier(attachment)] = range
                }
            }
        }
    }
#endif
