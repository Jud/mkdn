# Heading Level 1

## Heading Level 2

### Heading Level 3

#### Heading Level 4

##### Heading Level 5

###### Heading Level 6

## Inline Formatting

Regular text with **bold text** and *italic text* and ***bold italic text*** together. Also `inline code` mixed with normal text. Here's ~~strikethrough~~ if supported.

Multiple **bold** words in **one** sentence to check **spacing** stays correct.

A paragraph with a [simple link](https://example.com) and a [link with longer text that might wrap](https://example.com/some/very/long/path/that/goes/on) in the middle of a sentence.

## Blockquotes

> A single-line blockquote.

> A multi-line blockquote that contains enough text to wrap across multiple lines. This tests whether the left border extends the full height and the background fills correctly behind wrapped text.

> A blockquote with **bold**, *italic*, `code`, and [links](https://example.com) inside.

> First level of nesting.
>
> > Second level of nesting. The indent and border should stack.
>
> Back to first level.

## Ordered Lists

1. First item
2. Second item
3. Third item with enough text to wrap to a second line and verify that the number alignment stays correct when text flows below
4. Fourth item
   1. Nested ordered item one
   2. Nested ordered item two
5. Back to top level

## Unordered Lists

- Apple
- Banana
- Cherry with a longer description that should wrap to test bullet alignment with multi-line content
- Date
  - Nested item one
  - Nested item two
    - Deeply nested item
  - Back to second level
- Back to top level

## Task Lists

- [x] Completed task
- [x] Another completed task
- [ ] Incomplete task
- [ ] Another incomplete task with longer text that wraps to verify checkbox alignment

## Code Blocks

```swift
import SwiftUI

struct ContentView: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Count: \(count)")
                .font(.largeTitle)

            Button("Increment") {
                count += 1
            }
        }
        .padding()
    }
}
```

```python
def fibonacci(n: int) -> list[int]:
    """Generate the first n Fibonacci numbers."""
    if n <= 0:
        return []
    sequence = [0, 1]
    while len(sequence) < n:
        sequence.append(sequence[-1] + sequence[-2])
    return sequence[:n]

for i, num in enumerate(fibonacci(10)):
    print(f"F({i}) = {num}")
```

```
Plain code block without language specification.
Should still render in monospace with a background.
```

## Mixed Content Flow

Here's a paragraph before a blockquote.

> This blockquote sits between two paragraphs.

And here's the paragraph after. The spacing above and below the blockquote should be consistent.

Now a list right after text:
- Item one
- Item two

And code right after a list:

```bash
echo "Hello from bash"
```

Followed by another paragraph to verify spacing after code blocks.

## Links and Emphasis Together

Check that [**bold links**](https://example.com) render correctly. Also [*italic links*](https://example.com) and [`code links`](https://example.com).

A paragraph with lots of inline elements: **bold** then *italic* then `code` then [link](https://example.com) then back to **bold** again, all in one line.

---

## Thematic Break

The horizontal rule above should be visible. Here's another one below:

---

And text continues after the second rule.

## Long Paragraph

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

A second long paragraph to test consistent line spacing and text color across multiple blocks. The spacing between these paragraphs should match the spacing used elsewhere in the document between adjacent blocks.

## Final Section

This is the last section, useful for testing scroll-to-bottom behavior and ensuring no content is clipped at the document end.
