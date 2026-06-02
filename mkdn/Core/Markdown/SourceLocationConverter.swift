import Foundation
import Markdown

/// Converts swift-markdown `SourceLocation` / `SourceRange` coordinates into
/// `String.Index` positions within a source string.
///
/// swift-markdown reports a column as the number of UTF-8 *bytes* from the
/// start of the line (see `SourceLocation.column`), with both line and column
/// 1-based. Swift `String` is indexed by `Character`, and `NSRange`/selection
/// coordinates are UTF-16. This converter bridges the UTF-8-byte world to
/// `String.Index`, after which Foundation's `NSRange(_:in:)` /
/// `Range(_:in:)` handle the UTF-16 side. It must therefore cope with
/// multi-byte scalars, emoji, combining marks, and CRLF line endings.
struct SourceLocationConverter {
    private let source: String
    /// UTF-8 index at the start of each line (index `i` == line `i + 1`).
    private let lineStartsUTF8: [String.UTF8View.Index]

    init(source: String) {
        self.source = source
        let utf8 = source.utf8
        var starts: [String.UTF8View.Index] = [utf8.startIndex]
        var index = utf8.startIndex
        while index != utf8.endIndex {
            let next = utf8.index(after: index)
            if utf8[index] == 0x0A { // "\n" — CRLF's "\r" stays at the end of the prior line
                starts.append(next)
            }
            index = next
        }
        lineStartsUTF8 = starts
    }

    /// Convert a 1-based line and 1-based UTF-8 byte column to a `String.Index`.
    /// Returns `nil` when the position is out of bounds or does not fall on a
    /// `Character` boundary (e.g. mid-scalar or between a base character and its
    /// combining mark).
    func index(line: Int, column: Int) -> String.Index? {
        guard line >= 1, line <= lineStartsUTF8.count, column >= 1 else { return nil }
        let utf8 = source.utf8
        let lineStart = lineStartsUTF8[line - 1]
        guard let target = utf8.index(
            lineStart, offsetBy: column - 1, limitedBy: utf8.endIndex
        ) else {
            return nil
        }
        return target.samePosition(in: source)
    }

    func index(for location: SourceLocation) -> String.Index? {
        index(line: location.line, column: location.column)
    }

    /// Convert a `SourceRange` to a half-open `Range<String.Index>`, or `nil`
    /// if either endpoint cannot be resolved to a character boundary.
    func range(for sourceRange: SourceRange) -> Range<String.Index>? {
        guard let lower = index(for: sourceRange.lowerBound),
              let upper = index(for: sourceRange.upperBound),
              lower <= upper
        else {
            return nil
        }
        return lower ..< upper
    }
}
