# Field Notes: automated-ui-testing

## SwiftFormat `try await try` Corruption (T10)

When SwiftFormat processes nested async calls like:

```swift
try extractAnimThemeColors(from: try await client.getThemeColors())
```

It can rewrite the expression to invalid syntax:

```swift
try await try extractAnimThemeColors(from: client.getThemeColors())
```

**Workaround**: Always separate nested `try await` calls into two lines:

```swift
let resp = try await client.getThemeColors()
let colors = try extractAnimThemeColors(from: resp)
```

This pattern avoids the corruption and is also more readable.

## Private Members in Extensions Across Files

Swift `private` members are file-scoped. When splitting a struct across multiple files using extensions, any helper called from extension files must be `internal` (or `fileprivate` in the same file). This affects the compliance test pattern where the main struct has helpers used by extensions in separate files (e.g., `requireCalibration()`).

## Type Body Length Budget

SwiftLint enforces `type_body_length: 350` warning threshold. The compliance test suites (Spatial, Visual, Animation) approach this limit. Extracted helpers and extension files are the primary strategy for staying under the limit. Free functions at file scope (like `extractWindowSize`, `extractAnimThemeColors`) also reduce type body count.
