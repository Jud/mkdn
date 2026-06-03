import Foundation
@testable import mkdnLib

/// Builds v3 anchor-comment source for tests with deterministic ids, so
/// downstream tests can assert against known comment ids.
enum CommentFixture {
    /// Wrap the first occurrence of `substring` in `text` as a comment with a
    /// fixed `id` and `body`, producing the anchor pair + sidecar block.
    static func doc(
        _ text: String,
        comment substring: String,
        id: String = "c1",
        body: String = "note"
    ) -> String {
        doc(text, comments: [(substring, id, body)])
    }

    /// A raw start/end anchor token, so tests don't hard-code the marker syntax.
    static func start(_ id: String) -> String { CriticMarkup.anchorToken(id: id, edge: .start) }
    static func end(_ id: String) -> String { CriticMarkup.anchorToken(id: id, edge: .end) }

    /// Wrap several substrings in order, each with its own id and body.
    static func doc(_ text: String, comments: [(substring: String, id: String, body: String)]) -> String {
        var result = text
        for comment in comments {
            guard let range = result.range(of: comment.substring),
                  let wrapped = CriticMarkup.wrapComment(
                      in: result, range: range, body: comment.body, idGenerator: { comment.id }
                  )
            else {
                fatalError("CommentFixture could not wrap \(comment.substring)")
            }
            result = wrapped.source
        }
        return result
    }
}
