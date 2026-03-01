import SwiftUI
import Testing
@testable import mkdnLib

@Suite("MarkdownInteraction")
struct MarkdownInteractionTests {
    @MainActor
    @Test("default init has all closures nil")
    func defaultInitAllNil() {
        let interaction = MarkdownInteraction()

        #expect(interaction.onBlockTapped == nil)
        #expect(interaction.onLinkTapped == nil)
        #expect(interaction.blockContextMenuBuilder == nil)
        #expect(interaction.onBlockSizeChanged == nil)
        #expect(interaction.scrollTarget == nil)
        #expect(interaction.onCodeCopy == nil)
        #expect(interaction.onVisibleBlocksChanged == nil)
        #expect(interaction.onScrollOffsetChanged == nil)
        #expect(interaction.blockViewWrapperClosure == nil)
    }

    @MainActor
    @Test("onBlockTapped closure can be set")
    func setOnBlockTapped() {
        var interaction = MarkdownInteraction()

        interaction.onBlockTapped = { _ in }

        #expect(interaction.onBlockTapped != nil)
    }

    @MainActor
    @Test("onLinkTapped closure can be set")
    func setOnLinkTapped() {
        var interaction = MarkdownInteraction()

        interaction.onLinkTapped = { _, _ in true }

        #expect(interaction.onLinkTapped != nil)
    }

    @MainActor
    @Test("blockContextMenuBuilder closure can be set")
    func setBlockContextMenuBuilder() {
        var interaction = MarkdownInteraction()

        interaction.blockContextMenuBuilder = { _ in AnyView(EmptyView()) }

        #expect(interaction.blockContextMenuBuilder != nil)
    }

    @MainActor
    @Test("onBlockSizeChanged closure can be set")
    func setOnBlockSizeChanged() {
        var interaction = MarkdownInteraction()

        interaction.onBlockSizeChanged = { _, _ in }

        #expect(interaction.onBlockSizeChanged != nil)
    }

    @MainActor
    @Test("onCodeCopy closure can be set")
    func setOnCodeCopy() {
        var interaction = MarkdownInteraction()

        interaction.onCodeCopy = { _, _ in }

        #expect(interaction.onCodeCopy != nil)
    }

    @MainActor
    @Test("onVisibleBlocksChanged closure can be set")
    func setOnVisibleBlocksChanged() {
        var interaction = MarkdownInteraction()

        interaction.onVisibleBlocksChanged = { _ in }

        #expect(interaction.onVisibleBlocksChanged != nil)
    }

    @MainActor
    @Test("onScrollOffsetChanged closure can be set")
    func setOnScrollOffsetChanged() {
        var interaction = MarkdownInteraction()

        interaction.onScrollOffsetChanged = { _ in }

        #expect(interaction.onScrollOffsetChanged != nil)
    }

    @MainActor
    @Test("blockViewWrapperClosure can be set")
    func setBlockViewWrapperClosure() {
        var interaction = MarkdownInteraction()

        interaction.blockViewWrapperClosure = { _, view in view }

        #expect(interaction.blockViewWrapperClosure != nil)
    }
}
