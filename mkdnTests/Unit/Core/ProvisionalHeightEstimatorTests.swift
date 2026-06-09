import AppKit
import Testing
@testable import mkdnLib

@Suite("ProvisionalHeightEstimator")
struct ProvisionalHeightEstimatorTests {
    let theme: AppTheme = .solarizedDark

    private let mixedDocument = """
    # Title

    A paragraph with **bold**, `inline code`, a [link](https://example.com),
    and enough trailing prose that it wraps at narrow widths too.

    ## Section one

    ```swift
    func measure(_ width: CGFloat) -> CGFloat {
        width * 2
    }
    ```

    - first item with a longer run of text that should wrap when narrow
    - second item
      - nested item

    1. ordered one
    2. ordered two

    > A blockquote with enough words to wrap across more than a single line
    > at the narrow measurement width.

    | Column | Value |
    | --- | --- |
    | a | 1 |
    | b | 2 |

    ![alt text](missing.png)

    $$
    e^{i\\pi} + 1 = 0
    $$

    ---

    ### Last section

    Final paragraph.
    """

    private let proseDocument = (0 ..< 30).map { index in
        "Paragraph \(index) carries a moderately long sentence that wraps a "
            + "few times at typical preview widths, with some **emphasis** and "
            + "`inline code` mixed in so the run conversion stays realistic."
    }.joined(separator: "\n\n")

    private let codeDocument = (0 ..< 12).map { index in
        """
        ## Block \(index)

        ```swift
        func sample\(index)(_ value: Int) -> Int {
            let doubled = value * 2
            return doubled + \(index)
        }
        ```
        """
    }.joined(separator: "\n\n")

    /// Wide-glyph prose: each ideograph runs ~2x the ASCII sample average,
    /// the breach case for a character-count wrap estimate.
    private let cjkDocument = (0 ..< 10).map { _ in
        String(repeating: "視覚的な高さの見積もりは文字幅の平均に依存しているため、"
            + "全角文字が続く段落では行数を過小評価しやすい。", count: 3)
    }.joined(separator: "\n\n")

    /// Sentence-length cells wrap to several lines per row — the case a
    /// flat per-row height misses.
    private let tableDocument = """
    # Tables

    | Phase | What happens | Why it matters |
    | --- | --- | --- |
    \((0 ..< 8).map { index in
        "| step \(index) | a sentence-length cell describing the phase in enough "
            + "words to wrap | another long explanation that wraps across "
            + "several lines at the estimation width |"
    }.joined(separator: "\n"))
    """

    /// The floor must sit at or above the exact placeholder-based measure
    /// (what the post-tail pass computes before attachments resolve) at every
    /// width and scale — an under-estimate would let a deep scroll land past
    /// the provisional bottom — while staying within sane range of it.
    @Test("Floor covers the exact measure without ballooning")
    @MainActor func floorCoversExactMeasure() {
        let inset: CGFloat = 32
        for markdown in [
            mixedDocument, proseDocument, codeDocument, cjkDocument, tableDocument,
        ] {
            for scale in [0.5, 1.0, 1.25] as [CGFloat] {
                let blocks = MarkdownRenderer.render(text: markdown, theme: theme)
                let result = MarkdownTextStorageBuilder.build(
                    blocks: blocks, theme: theme, scaleFactor: scale
                )
                for width in [320.0, 600.0, 900.0] as [CGFloat] {
                    let exact = DocumentHeightEstimator.estimatedHeight(
                        of: result.attributedString,
                        model: result.documentHeightModel,
                        textWidth: width,
                        verticalInset: inset
                    )
                    let floor = ProvisionalHeightEstimator.provisionalHeight(
                        of: blocks, textWidth: width, scaleFactor: scale,
                        verticalInset: inset
                    )
                    let label: Comment =
                        "width \(width), scale \(scale), doc \(markdown.prefix(12))"
                    #expect(floor >= exact, label)
                    #expect(floor <= exact * 4, label)
                }
            }
        }
    }

    @Test("Degenerate inputs return zero")
    @MainActor func degenerateInputs() {
        let blocks = MarkdownRenderer.render(text: "hello", theme: theme)
        #expect(ProvisionalHeightEstimator.provisionalHeight(
            of: [], textWidth: 600, scaleFactor: 1, verticalInset: 32
        ) == 0)
        #expect(ProvisionalHeightEstimator.provisionalHeight(
            of: blocks, textWidth: 0, scaleFactor: 1, verticalInset: 32
        ) == 0)
    }
}
