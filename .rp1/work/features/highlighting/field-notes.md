# Field Notes: Multi-Language Syntax Highlighting

## T1: Tree-Sitter Grammar Package Compatibility Issues

### Problem: FileManager-Based Source Detection in Grammar Package.swift

Many tree-sitter grammar packages (Python, JavaScript, Go, CSS, YAML at newer versions) use dynamic source detection in their Package.swift:

```swift
var sources = ["src/parser.c"]
if FileManager.default.fileExists(atPath: "src/scanner.c") {
    sources.append("src/scanner.c")
}
```

This relative path check resolves against the working directory where `swift build` runs (the consuming project root), not the grammar package's checkout directory. When the scanner.c file is not found, it's excluded from compilation, causing undefined symbol linker errors for the external scanner functions.

**Mitigation**: Pin grammar packages to versions that use explicit static source lists (e.g., Python 0.23.6, JavaScript 0.23.1, CSS 0.23.2, Bash 0.23.3, Go 0.23.4).

### Problem: SwiftTreeSitter URL Split

The tree-sitter grammar ecosystem has two SwiftTreeSitter mirror URLs:
- `https://github.com/ChimeHQ/SwiftTreeSitter` (original)
- `https://github.com/tree-sitter/swift-tree-sitter` (mirror, identical commits)

SPM treats these as different packages due to different URL-derived identities ("swifttreesitter" vs "swift-tree-sitter"). Grammar packages at newer versions switched from ChimeHQ to tree-sitter org URL. The `tree-sitter-c` package at v0.24.0+ has an additional bug: it references `"SwiftTreeSitter"` in its test target but declares the dependency URL as `tree-sitter/swift-tree-sitter`, causing identity mismatch.

**Mitigation**: Pin grammar packages to versions that reference `ChimeHQ/SwiftTreeSitter` consistently (the 0.23.x range for most).

### Problem: alex-pinkus/tree-sitter-swift Missing Generated Files

The alex-pinkus/tree-sitter-swift package at semver tags (e.g., 0.7.1) does not include the generated `parser.c` file in `src/`. Tree-sitter grammars require running `tree-sitter generate` to produce parser.c from grammar.js. The repo provides separate `-with-generated-files` tags for this purpose, but these are not valid semver tags for SPM version resolution.

**Mitigation**: Use a revision-based dependency pinned to the `0.7.1-with-generated-files` tag commit (277b583bbb024f20ba88b95c48bf5a6a0b4f2287).

### Resolved Version Matrix

| Grammar | Package | Resolved Version | Notes |
|---------|---------|-----------------|-------|
| Swift | alex-pinkus/tree-sitter-swift | 277b583 (0.7.1-with-generated-files) | Revision pin required |
| Python | tree-sitter/tree-sitter-python | 0.23.6 | Pinned < 0.24.0 |
| JavaScript | tree-sitter/tree-sitter-javascript | 0.23.1 | Pinned < 0.24.0 |
| TypeScript | tree-sitter/tree-sitter-typescript | 0.23.2 | Pinned < 0.24.0 |
| Rust | tree-sitter/tree-sitter-rust | 0.23.3 | Pinned < 0.24.0 |
| Go | tree-sitter/tree-sitter-go | 0.23.4 | Pinned < 0.24.0 |
| Bash | tree-sitter/tree-sitter-bash | 0.23.3 | Pinned < 0.24.0 |
| JSON | tree-sitter/tree-sitter-json | 0.24.8 | Pinned < 0.25.0 |
| YAML | tree-sitter-grammars/tree-sitter-yaml | 0.7.0 | Exact pin (only version with static sources) |
| HTML | tree-sitter/tree-sitter-html | 0.23.2 | Pinned < 0.24.0 |
| CSS | tree-sitter/tree-sitter-css | 0.23.2 | Pinned < 0.24.0 |
| C | tree-sitter/tree-sitter-c | 0.23.6 | Pinned < 0.24.0 |
| C++ | tree-sitter/tree-sitter-cpp | 0.23.4 | Pinned < 0.24.0 |
| Ruby | tree-sitter/tree-sitter-ruby | 0.23.1 | Pinned < 0.24.0 |
| Java | tree-sitter/tree-sitter-java | 0.23.5 | Pinned < 0.24.0 |
| Kotlin | fwcd/tree-sitter-kotlin | 0.3.8 | No issues |
| SwiftTreeSitter | ChimeHQ/SwiftTreeSitter | 0.25.0 | Core wrapper |
| tree-sitter (C) | tree-sitter/tree-sitter | 0.25.10 | Transitive dep |
