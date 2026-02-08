<!--
  Fixture: theme-tokens.md
  Purpose: Code blocks with known Swift tokens for syntax highlighting
           color verification across both Solarized themes.
  Used by: Visual compliance tests for syntax highlighting token colors.

  Expected rendering characteristics:
  - Each code block isolates specific token types for targeted color sampling
  - Token colors are defined in SyntaxColors (same accent palette for both themes):
      keyword  -> green  (#859900) - import, struct, let, var, func, return, if, else, guard, class, enum, case, protocol, static, private
      string   -> cyan   (#2aa198) - "string literals", string interpolation delimiters
      comment  -> base01 (#586e75 dark) / base1 (#586e75 light) - // and /* */ comments
      type     -> yellow (#b58900) - String, Int, Double, Bool, Array, Optional, Result
      number   -> magenta (#d33682) - 42, 3.14, 0xFF, 1_000
      function -> blue   (#268bd2) - function names at call site
      property -> orange (#cb4b16) - property access, dot-member access
      preprocessor -> red (#dc322f) - #if, #available, @attribute
  - Code blocks use codeBackground and codeForeground from ThemeColors
  - Background: base02 (#073642 dark) / base2 (#eee8d5 light)
  - Foreground: base0 (#839496 dark) / base00 (#657b83 light)

  Token isolation strategy: Each block emphasizes one or two token types
  with minimal surrounding syntax, making pixel-level color sampling
  unambiguous.
-->

# Syntax Token Reference

## Keywords

```swift
import Foundation
struct Example {}
class Container {}
enum Direction { case north, south }
protocol Drawable {}
let constant = true
var variable = false
func execute() {}
return
if true {} else {}
guard true else {}
static let shared = true
private var hidden = 0
```

## String Literals

```swift
let greeting = "Hello, World!"
let name = "mkdn"
let interpolated = "Value: \(42)"
let multiword = "The quick brown fox"
let empty = ""
```

## Comments

```swift
// This is a single-line comment
// Another comment line for sampling

/* This is a block comment
   spanning multiple lines */

/// Documentation comment
```

## Type Names

```swift
let text: String = ""
let count: Int = 0
let ratio: Double = 0.0
let flag: Bool = true
let items: Array<String> = []
let maybe: Optional<Int> = nil
let outcome: Result<String, Error> = .success("")
```

## Numeric Literals

```swift
let integer = 42
let decimal = 3.14
let hex = 0xFF
let grouped = 1_000_000
let negative = -7
let float: Float = 2.718
```

## Function Calls

```swift
print("output")
stride(from: 0, to: 10, by: 2)
max(1, 2)
min(3, 4)
abs(-5)
```

## Property Access

```swift
let length = text.count
let first = items.first
let isEmpty = items.isEmpty
let uppercased = name.uppercased()
let description = count.description
```

## Preprocessor and Attributes

```swift
@available(macOS 14.0, *)
@MainActor
@discardableResult
#if DEBUG
let debug = true
#endif
```
