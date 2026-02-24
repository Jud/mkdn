# Field Notes: native-latex-math

## T1: SwiftMath Version Mismatch

The design specifies SwiftMath >= 3.3.0, but this version does not exist. The package's latest release is 1.7.3 (tag history goes from 1.0.0 to 1.7.3). Used `from: "1.7.0"` which resolves to 1.7.3.

The API surface (MTMathUILabel, MTMathImage, etc.) appears to be the same as described in the design. Subsequent tasks (T2) should verify that `MTMathUILabel` properties like `latex`, `fontSize`, `textColor`, `labelMode`, `hasError`, `sizeThatFits`, and `descent` exist and behave as expected.

## T4: MathRenderer @MainActor Removal

The design specified `@MainActor` on `MathRenderer` because it assumed `MTMathUILabel` (an NSView). However, T2 implemented `MathRenderer` using `MathImage` (a struct) which renders via CoreGraphics drawing commands -- no NSView involved. The `@MainActor` annotation caused Swift 6 strict concurrency errors when calling `MathRenderer.renderToImage` from `MarkdownTextStorageBuilder.convertInlineContent` (a nonisolated static method).

Removing `@MainActor` is correct because:
1. `MathImage` is a value type (struct), not an NSView
2. `MathImage.asImage()` uses `NSImage(size:flipped:)` draw handler which sets up its own `NSGraphicsContext` -- safe from any thread
3. `MTMathListBuilder.build` and `MTTypesetter.createLineForMathList` are pure computation

This allows `MarkdownTextStorageBuilder` to call `MathRenderer` directly without isolation boundary crossing, avoiding cascading `@MainActor` annotations across the entire builder.
