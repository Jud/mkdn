import AppKit

/// Code block background drawing for `CodeBlockBackgroundTextView`.
///
/// Enumerates `.codeBlockRange` attributes in the text storage, computes
/// bounding rectangles from TextKit 2 layout fragment frames, and draws
/// filled-and-stroked rounded rectangles behind the code text.
extension CodeBlockBackgroundTextView {
    // MARK: - Code Block Container Drawing

    func drawCodeBlockContainers(in dirtyRect: NSRect) {
        guard let textStorage,
              let layoutManager = textLayoutManager,
              let contentManager = layoutManager.textContentManager
        else { return }

        let blocks = collectCodeBlocks(from: textStorage)
        guard !blocks.isEmpty else { return }

        let origin = textContainerOrigin
        let containerWidth = textContainer?.size.width ?? bounds.width
        let borderInset = Self.borderWidth / 2

        for block in blocks {
            let frames = fragmentFrames(
                for: block.range,
                layoutManager: layoutManager,
                contentManager: contentManager
            )
            guard !frames.isEmpty else { continue }

            let bounding = frames.reduce(frames[0]) { $0.union($1) }
            let drawRect = CGRect(
                x: origin.x + borderInset,
                y: bounding.minY + origin.y,
                width: containerWidth - 2 * borderInset,
                height: bounding.height + Self.bottomPadding
            )
            guard drawRect.intersects(dirtyRect) else { continue }

            drawRoundedContainer(
                in: drawRect,
                colorInfo: block.colorInfo
            )
        }
    }

    // MARK: - Rounded Container

    private func drawRoundedContainer(
        in rect: NSRect,
        colorInfo: CodeBlockColorInfo
    ) {
        let path = NSBezierPath(
            roundedRect: rect,
            xRadius: Self.cornerRadius,
            yRadius: Self.cornerRadius
        )

        colorInfo.background.setFill()
        path.fill()

        colorInfo.border
            .withAlphaComponent(Self.borderOpacity).setStroke()
        path.lineWidth = Self.borderWidth
        path.stroke()
    }

    // MARK: - Block Collection

    func collectCodeBlocks(
        from textStorage: NSTextStorage
    ) -> [CodeBlockInfo] {
        if isCodeBlockCacheValid {
            return cachedCodeBlocks
        }

        var grouped: [String: (range: NSRange, colorInfo: CodeBlockColorInfo)] = [:]
        let fullRange = NSRange(location: 0, length: textStorage.length)

        textStorage.enumerateAttribute(
            CodeBlockAttributes.range,
            in: fullRange,
            options: []
        ) { value, range, _ in
            guard let blockID = value as? String else { return }
            if var existing = grouped[blockID] {
                existing.range = NSUnionRange(existing.range, range)
                grouped[blockID] = existing
            } else if let colorInfo = textStorage.attribute(
                CodeBlockAttributes.colors,
                at: range.location,
                effectiveRange: nil
            ) as? CodeBlockColorInfo {
                grouped[blockID] = (range: range, colorInfo: colorInfo)
            }
        }

        cachedCodeBlocks = grouped.map { blockID, entry in
            CodeBlockInfo(blockID: blockID, range: entry.range, colorInfo: entry.colorInfo)
        }
        isCodeBlockCacheValid = true
        return cachedCodeBlocks
    }

    // MARK: - Layout Fragment Geometry

    func fragmentFrames(
        for nsRange: NSRange,
        layoutManager: NSTextLayoutManager,
        contentManager: NSTextContentManager
    ) -> [CGRect] {
        guard let textRange = textRange(
            from: nsRange,
            contentManager: contentManager
        )
        else { return [] }

        var frames: [CGRect] = []
        let endLocation = textRange.endLocation

        layoutManager.enumerateTextLayoutFragments(
            from: textRange.location,
            options: [.ensuresLayout]
        ) { fragment in
            let fragmentStart = fragment.rangeInElement.location
            if fragmentStart.compare(endLocation) != .orderedAscending {
                return false
            }
            frames.append(fragment.layoutFragmentFrame)
            return true
        }

        return frames
    }

    private func textRange(
        from nsRange: NSRange,
        contentManager: NSTextContentManager
    ) -> NSTextRange? {
        guard nsRange.length > 0 else { return nil }

        guard let startLocation = contentManager.location(
            contentManager.documentRange.location,
            offsetBy: nsRange.location
        )
        else { return nil }

        guard let endLocation = contentManager.location(
            startLocation,
            offsetBy: nsRange.length
        )
        else { return nil }

        return NSTextRange(location: startLocation, end: endLocation)
    }
}
