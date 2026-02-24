# Field Notes: native-latex-math

## T1: SwiftMath Version Mismatch

The design specifies SwiftMath >= 3.3.0, but this version does not exist. The package's latest release is 1.7.3 (tag history goes from 1.0.0 to 1.7.3). Used `from: "1.7.0"` which resolves to 1.7.3.

The API surface (MTMathUILabel, MTMathImage, etc.) appears to be the same as described in the design. Subsequent tasks (T2) should verify that `MTMathUILabel` properties like `latex`, `fontSize`, `textColor`, `labelMode`, `hasError`, `sizeThatFits`, and `descent` exist and behave as expected.
