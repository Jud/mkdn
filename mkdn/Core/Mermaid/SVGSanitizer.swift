import Foundation

/// Resolves CSS custom properties and modern CSS features in beautiful-mermaid SVG
/// output so that SwiftDraw (a CoreGraphics-based renderer) can parse them.
///
/// SwiftDraw does not support `var()`, `color-mix()`, or `@import url()`.
/// This sanitizer extracts the concrete color values from the SVG root element's
/// inline style, computes all derived colors using the known beautiful-mermaid
/// blend percentages, and replaces every CSS feature reference with a literal hex color.
/// Input colors extracted from an SVG's root style attribute.
struct SVGThemeColors {
    let bg: String
    let fg: String
    var line: String?
    var accent: String?
    var muted: String?
    var surface: String?
    var border: String?
}

/// Resolves CSS custom properties and modern CSS features in beautiful-mermaid SVG
/// output so that SwiftDraw (a CoreGraphics-based renderer) can parse them.
enum SVGSanitizer {
    // MARK: - Public API

    /// Sanitize a beautiful-mermaid SVG string for SwiftDraw compatibility.
    ///
    /// - Parameter svgString: Raw SVG output from beautiful-mermaid's `renderMermaid()`.
    /// - Returns: SVG string with all `var()`, `color-mix()`, and `@import` removed.
    static func sanitize(_ svgString: String) -> String {
        let rootVars = extractRootVariables(from: svgString)
        let colors = SVGThemeColors(
            bg: rootVars["bg"] ?? "#FFFFFF",
            fg: rootVars["fg"] ?? "#27272A",
            line: rootVars["line"],
            accent: rootVars["accent"],
            muted: rootVars["muted"],
            surface: rootVars["surface"],
            border: rootVars["border"]
        )

        let variableMap = buildVariableMap(from: colors)

        var result = svgString
        result = stripImportRules(result)
        result = resolveVarReferences(result, variableMap: variableMap)
        result = resolveColorMixExpressions(result)
        result = replaceGoogleFonts(result)
        result = stripCSSVariableDeclarations(result)
        return result
    }

    // MARK: - Root Variable Extraction

    /// Parse the `style` attribute on the root `<svg>` element for CSS custom property values.
    static func extractRootVariables(from svgString: String) -> [String: String] {
        guard let styleRange = findSVGStyleAttribute(in: svgString) else {
            return [:]
        }

        let styleValue = String(svgString[styleRange])
        var variables: [String: String] = [:]

        let declarations = styleValue.components(separatedBy: ";")
        for declaration in declarations {
            let trimmed = declaration.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("--") else { continue }

            let parts = trimmed.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let name = parts[0].trimmingCharacters(in: .whitespaces)
                .dropFirst(2)
            let value = parts[1].trimmingCharacters(in: .whitespaces)

            if !value.isEmpty {
                variables[String(name)] = value
            }
        }

        return variables
    }

    // MARK: - Variable Map

    /// Build the complete mapping from CSS variable names to concrete hex colors.
    ///
    /// The blend percentages match the `xe` constants in beautiful-mermaid's JS bundle.
    static func buildVariableMap(from colors: SVGThemeColors) -> [String: String] {
        let bg = colors.bg
        let fg = colors.fg
        var map: [String: String] = [:]

        map["--bg"] = bg
        map["--fg"] = fg

        if let line = colors.line { map["--line"] = line }
        if let accent = colors.accent { map["--accent"] = accent }
        if let muted = colors.muted { map["--muted"] = muted }
        if let surface = colors.surface { map["--surface"] = surface }
        if let border = colors.border { map["--border"] = border }

        map["--_text"] = fg
        map["--_text-sec"] = colors.muted ?? colorMix(fg: fg, percent: 60, bg: bg)
        map["--_text-muted"] = colors.muted ?? colorMix(fg: fg, percent: 40, bg: bg)
        map["--_text-faint"] = colorMix(fg: fg, percent: 25, bg: bg)
        map["--_line"] = colors.line ?? colorMix(fg: fg, percent: 30, bg: bg)
        map["--_arrow"] = colors.accent ?? colorMix(fg: fg, percent: 50, bg: bg)
        map["--_node-fill"] = colors.surface ?? colorMix(fg: fg, percent: 3, bg: bg)
        map["--_node-stroke"] = colors.border ?? colorMix(fg: fg, percent: 20, bg: bg)
        map["--_group-fill"] = bg
        map["--_group-hdr"] = colorMix(fg: fg, percent: 5, bg: bg)
        map["--_inner-stroke"] = colorMix(fg: fg, percent: 12, bg: bg)
        map["--_key-badge"] = colorMix(fg: fg, percent: 10, bg: bg)

        return map
    }

    // MARK: - Color Mixing

    /// Compute `color-mix(in srgb, fg pct%, bg)` as a hex string.
    ///
    /// Formula: `result = fg * (percent/100) + bg * (1 - percent/100)`
    static func colorMix(fg: String, percent: Int, bg: String) -> String {
        guard let fgRGB = parseHex(fg), let bgRGB = parseHex(bg) else {
            return fg
        }

        let pct = Double(percent) / 100.0
        let red = Int(round(Double(fgRGB.r) * pct + Double(bgRGB.r) * (1.0 - pct)))
        let green = Int(round(Double(fgRGB.g) * pct + Double(bgRGB.g) * (1.0 - pct)))
        let blue = Int(round(Double(fgRGB.b) * pct + Double(bgRGB.b) * (1.0 - pct)))

        return String(format: "#%02X%02X%02X", min(red, 255), min(green, 255), min(blue, 255))
    }

    // MARK: - Hex Color Parsing

    /// Parse a `#RRGGBB` or `#RGB` hex string into RGB components.
    static func parseHex(_ hex: String) -> (r: Int, g: Int, b: Int)? {
        var cleaned = hex.trimmingCharacters(in: .whitespaces)
        if cleaned.hasPrefix("#") {
            cleaned = String(cleaned.dropFirst())
        }

        if cleaned.count == 3 {
            let chars = Array(cleaned)
            cleaned = "\(chars[0])\(chars[0])\(chars[1])\(chars[1])\(chars[2])\(chars[2])"
        }

        guard cleaned.count == 6,
              let value = UInt32(cleaned, radix: 16)
        else {
            return nil
        }

        return (
            r: Int((value >> 16) & 0xFF),
            g: Int((value >> 8) & 0xFF),
            b: Int(value & 0xFF)
        )
    }

    // MARK: - CSS Processing

    /// Replace all `var(--name)` and `var(--name, fallback)` references with concrete values.
    static func resolveVarReferences(_ svg: String, variableMap: [String: String]) -> String {
        var result = svg
        var previousResult = ""

        // Iterate to resolve nested var() references (e.g. var(--muted, color-mix(...var(--fg)...)))
        // Limit passes to prevent infinite loops on unresolvable references.
        var passes = 0
        let maxPasses = 5
        while result.contains("var(--"), result != previousResult, passes < maxPasses {
            previousResult = result
            result = resolveOneVarPass(result, variableMap: variableMap)
            passes += 1
        }

        return result
    }

    /// Strip `@import url(...)` declarations from `<style>` blocks.
    static func stripImportRules(_ svg: String) -> String {
        let pattern = #"@import\s+url\([^)]*\)\s*;"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return svg
        }
        return regex.stringByReplacingMatches(
            in: svg,
            range: NSRange(svg.startIndex..., in: svg),
            withTemplate: ""
        )
    }

    /// Resolve remaining `color-mix(in srgb, <color> <pct>%, <color>)` expressions.
    static func resolveColorMixExpressions(_ svg: String) -> String {
        let pattern = #"color-mix\(in\s+srgb\s*,\s*(#[0-9A-Fa-f]{3,8})\s+(\d+)%\s*,\s*(#[0-9A-Fa-f]{3,8})\s*\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return svg
        }

        var result = svg
        // Process matches from end to start so replacements don't shift ranges
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        for match in matches.reversed() {
            guard match.numberOfRanges == 4,
                  let fullRange = Range(match.range, in: result),
                  let colorARange = Range(match.range(at: 1), in: result),
                  let pctRange = Range(match.range(at: 2), in: result),
                  let colorBRange = Range(match.range(at: 3), in: result),
                  let pct = Int(result[pctRange])
            else { continue }

            let colorA = String(result[colorARange])
            let colorB = String(result[colorBRange])
            let mixed = colorMix(fg: colorA, percent: pct, bg: colorB)
            result.replaceSubrange(fullRange, with: mixed)
        }

        return result
    }

    /// Replace Google Fonts font-family references with system font stack.
    static func replaceGoogleFonts(_ svg: String) -> String {
        var result = svg
        let fontPattern = #"font-family:\s*['"]?Inter['"]?"#
        if let regex = try? NSRegularExpression(pattern: fontPattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "font-family: -apple-system, Helvetica Neue, Helvetica, Arial, sans-serif"
            )
        }

        result = result.replacingOccurrences(
            of: #"font-family="Inter""#,
            with: #"font-family="-apple-system, Helvetica Neue, Helvetica, Arial, sans-serif""#
        )

        let monoPattern = #"font-family:\s*['"]?JetBrains Mono['"]?"#
        if let regex = try? NSRegularExpression(pattern: monoPattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "font-family: SF Mono, Menlo, monospace"
            )
        }

        result = result.replacingOccurrences(
            of: #"font-family="JetBrains Mono""#,
            with: #"font-family="SF Mono, Menlo, monospace""#
        )

        return result
    }

    // MARK: - Internal Helpers

    /// Find the value of the `style` attribute on the root `<svg>` element.
    private static func findSVGStyleAttribute(in svg: String) -> Range<String.Index>? {
        let pattern = #"<svg\s[^>]*style="([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: svg, range: NSRange(svg.startIndex..., in: svg)),
              match.numberOfRanges >= 2,
              let captureRange = Range(match.range(at: 1), in: svg)
        else {
            return nil
        }
        return captureRange
    }

    /// Single pass of var() resolution, replacing outermost var() expressions.
    private static func resolveOneVarPass(_ svg: String, variableMap: [String: String]) -> String {
        let pattern = #"var\((--[\w-]+)(?:\s*,\s*([^)]*(?:\([^)]*\)[^)]*)*))?\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return svg
        }

        var result = svg
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))

        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: result),
                  let varNameRange = Range(match.range(at: 1), in: result)
            else { continue }

            let varName = String(result[varNameRange])

            if let resolved = variableMap[varName] {
                result.replaceSubrange(fullRange, with: resolved)
            } else if match.numberOfRanges >= 3,
                      match.range(at: 2).location != NSNotFound,
                      let fallbackRange = Range(match.range(at: 2), in: result)
            {
                let fallback = String(result[fallbackRange]).trimmingCharacters(in: .whitespaces)
                result.replaceSubrange(fullRange, with: fallback)
            }
        }

        return result
    }

    /// Remove CSS custom property declarations from `<style>` blocks.
    /// These are no longer needed after var() resolution and would confuse SwiftDraw.
    private static func stripCSSVariableDeclarations(_ svg: String) -> String {
        let pattern = #"\s*--[\w-]+\s*:\s*[^;]+;"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return svg
        }
        return regex.stringByReplacingMatches(
            in: svg,
            range: NSRange(svg.startIndex..., in: svg),
            withTemplate: ""
        )
    }
}
