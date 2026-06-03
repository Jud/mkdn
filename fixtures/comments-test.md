# v3 Comments Demo

The <mkdn-comment id="d1" edge="start"/>quick brown fox<mkdn-comment id="d1" edge="end"/> jumps over the <mkdn-comment id="d5" edge="start"/>lazy dog near the <mkdn-comment id="d6" edge="start"/>river bank<mkdn-comment id="d6" edge="end"/><mkdn-comment id="d5" edge="end"/>.

See the <mkdn-comment id="d2" edge="start"/>[documentation](https://example.com)<mkdn-comment id="d2" edge="end"/> and run <mkdn-comment id="d3" edge="start"/>`swift build`<mkdn-comment id="d3" edge="end"/> to begin.

<mkdn-comment id="d4" edge="start"/>First word<mkdn-comment id="d4" edge="end"/> of this paragraph is commentable now.

<!--mkdn-comments
{
  "comments" : [
    {
      "body" : "Nice imagery — keep it.",
      "id" : "d1",
      "prefix" : "# v3 Comments Demo\n\nThe ",
      "quote" : "quick brown fox",
      "suffix" : " jumps over the lazy dog near th"
    },
    {
      "body" : "Link the v3 page instead.",
      "id" : "d2",
      "prefix" : "g near the river bank.\n\nSee the ",
      "quote" : "[documentation](https://example.com)",
      "suffix" : " and run `swift build` to begin."
    },
    {
      "body" : "Should this be `swift test`?",
      "id" : "d3",
      "prefix" : "n](https://example.com) and run ",
      "quote" : "`swift build`",
      "suffix" : " to begin.\n\nFirst word of this p"
    },
    {
      "body" : "Line\u002dstart comment — works now!",
      "id" : "d4",
      "prefix" : "nd run `swift build` to begin.\n\n",
      "quote" : "First word",
      "suffix" : " of this paragraph is commentabl"
    },
    {
      "body" : "Whole clause.",
      "id" : "d5",
      "prefix" : " quick brown fox jumps over the ",
      "quote" : "lazy dog near the river bank",
      "suffix" : ".\n\nSee the [documentation](https"
    },
    {
      "body" : "Inner comment (overlap).",
      "id" : "d6",
      "prefix" : "umps over the lazy dog near the ",
      "quote" : "river bank",
      "suffix" : ".\n\nSee the [documentation](https"
    },
    {
      "body" : "Recovered via TextQuote (no anchors).",
      "id" : "orphan",
      "prefix" : "",
      "quote" : "jumps over",
      "suffix" : ""
    }
  ],
  "v" : 1
}
-->
