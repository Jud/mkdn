import Foundation
import Testing
@testable import mkdnLib

@Suite("BlockInteractionContext")
struct BlockInteractionContextTests {
    // MARK: - Convenience Accessors

    @MainActor
    @Test("language returns language for codeBlock")
    func languageForCodeBlock() {
        let block = IndexedBlock(index: 0, block: .codeBlock(language: "swift", code: "let x = 1"))
        let context = BlockInteractionContext(block: block)

        #expect(context.language == "swift")
    }

    @MainActor
    @Test("language returns nil for non-codeBlock")
    func languageNilForHeading() {
        let block = IndexedBlock(index: 0, block: .heading(level: 2, text: AttributedString("Title")))
        let context = BlockInteractionContext(block: block)

        #expect(context.language == nil)
    }

    @MainActor
    @Test("language returns nil when codeBlock language is nil")
    func languageNilForCodeBlockWithoutLanguage() {
        let block = IndexedBlock(index: 0, block: .codeBlock(language: nil, code: "some code"))
        let context = BlockInteractionContext(block: block)

        #expect(context.language == nil)
    }

    @MainActor
    @Test("imageSource returns source for image block")
    func imageSourceForImage() {
        let block = IndexedBlock(index: 0, block: .image(source: "photo.png", alt: "A photo"))
        let context = BlockInteractionContext(block: block)

        #expect(context.imageSource == "photo.png")
    }

    @MainActor
    @Test("imageSource returns nil for non-image block")
    func imageSourceNilForParagraph() {
        let block = IndexedBlock(index: 0, block: .paragraph(text: AttributedString("text")))
        let context = BlockInteractionContext(block: block)

        #expect(context.imageSource == nil)
    }

    @MainActor
    @Test("imageAlt returns alt text for image block")
    func imageAltForImage() {
        let block = IndexedBlock(index: 0, block: .image(source: "photo.png", alt: "A photo"))
        let context = BlockInteractionContext(block: block)

        #expect(context.imageAlt == "A photo")
    }

    @MainActor
    @Test("imageAlt returns nil for non-image block")
    func imageAltNilForCodeBlock() {
        let block = IndexedBlock(index: 0, block: .codeBlock(language: "py", code: "print(1)"))
        let context = BlockInteractionContext(block: block)

        #expect(context.imageAlt == nil)
    }

    @MainActor
    @Test("headingLevel returns level for heading block")
    func headingLevelForHeading() {
        let block = IndexedBlock(index: 0, block: .heading(level: 3, text: AttributedString("Section")))
        let context = BlockInteractionContext(block: block)

        #expect(context.headingLevel == 3)
    }

    @MainActor
    @Test("headingLevel returns nil for non-heading block")
    func headingLevelNilForThematicBreak() {
        let block = IndexedBlock(index: 0, block: .thematicBreak)
        let context = BlockInteractionContext(block: block)

        #expect(context.headingLevel == nil)
    }

    @MainActor
    @Test("plainText returns text content for paragraph")
    func plainTextForParagraph() {
        let block = IndexedBlock(index: 0, block: .paragraph(text: AttributedString("Hello world")))
        let context = BlockInteractionContext(block: block)

        #expect(context.plainText == "Hello world")
    }

    @MainActor
    @Test("plainText returns code content for codeBlock")
    func plainTextForCodeBlock() {
        let block = IndexedBlock(index: 0, block: .codeBlock(language: "swift", code: "let x = 1"))
        let context = BlockInteractionContext(block: block)

        #expect(context.plainText == "let x = 1")
    }

    @MainActor
    @Test("plainText returns empty string for thematicBreak")
    func plainTextForThematicBreak() {
        let block = IndexedBlock(index: 0, block: .thematicBreak)
        let context = BlockInteractionContext(block: block)

        #expect(context.plainText.isEmpty)
    }

    @MainActor
    @Test("rawContent returns the underlying MarkdownBlock")
    func rawContentDelegation() {
        let markdownBlock = MarkdownBlock.codeBlock(language: "js", code: "console.log()")
        let block = IndexedBlock(index: 4, block: markdownBlock)
        let context = BlockInteractionContext(block: block)

        if case let .codeBlock(lang, code) = context.rawContent {
            #expect(lang == "js")
            #expect(code == "console.log()")
        } else {
            Issue.record("rawContent did not return codeBlock")
        }
    }

    // MARK: - IndexedBlock Delegation

    @MainActor
    @Test("blockIndex delegates to IndexedBlock.index")
    func blockIndexDelegation() {
        let block = IndexedBlock(index: 7, block: .thematicBreak)
        let context = BlockInteractionContext(block: block)

        #expect(context.blockIndex == 7)
    }

    @MainActor
    @Test("blockID delegates to IndexedBlock.block.id")
    func blockIDDelegation() {
        let markdownBlock = MarkdownBlock.heading(level: 1, text: AttributedString("Title"))
        let block = IndexedBlock(index: 0, block: markdownBlock)
        let context = BlockInteractionContext(block: block)

        #expect(context.blockID == markdownBlock.id)
    }

    // MARK: - Identifiable Conformance

    @MainActor
    @Test("id matches IndexedBlock.id and is stable")
    func identifiableId() {
        let block = IndexedBlock(index: 2, block: .paragraph(text: AttributedString("test")))
        let context = BlockInteractionContext(block: block)

        #expect(context.id == block.id)
    }

    @MainActor
    @Test("id is a nonisolated let accessible outside main actor")
    func nonisolatedIdProperty() {
        let block = IndexedBlock(index: 0, block: .thematicBreak)
        let context = BlockInteractionContext(block: block)
        let storedID = context.id

        #expect(storedID == block.id)
        #expect(!storedID.isEmpty)
    }

    // MARK: - Image Setters

    @MainActor
    @Test("loadedImage starts nil and can be set")
    func loadedImageSetter() {
        let block = IndexedBlock(index: 0, block: .image(source: "test.png", alt: "test"))
        let context = BlockInteractionContext(block: block)

        #expect(context.loadedImage == nil)

        let image = PlatformTypeConverter.PlatformImage()
        context.setLoadedImage(image)

        #expect(context.loadedImage != nil)
    }

    @MainActor
    @Test("renderedImage starts nil and can be set")
    func renderedImageSetter() {
        let block = IndexedBlock(index: 0, block: .mathBlock(code: "E = mc^2"))
        let context = BlockInteractionContext(block: block)

        #expect(context.renderedImage == nil)

        let image = PlatformTypeConverter.PlatformImage()
        context.setRenderedImage(image)

        #expect(context.renderedImage != nil)
    }

    @MainActor
    @Test("setLoadedImage can clear back to nil")
    func loadedImageClearToNil() {
        let block = IndexedBlock(index: 0, block: .image(source: "test.png", alt: ""))
        let context = BlockInteractionContext(block: block)

        context.setLoadedImage(PlatformTypeConverter.PlatformImage())
        #expect(context.loadedImage != nil)

        context.setLoadedImage(nil)
        #expect(context.loadedImage == nil)
    }

    @MainActor
    @Test("setRenderedImage can clear back to nil")
    func renderedImageClearToNil() {
        let block = IndexedBlock(index: 0, block: .mathBlock(code: "x^2"))
        let context = BlockInteractionContext(block: block)

        context.setRenderedImage(PlatformTypeConverter.PlatformImage())
        #expect(context.renderedImage != nil)

        context.setRenderedImage(nil)
        #expect(context.renderedImage == nil)
    }
}
