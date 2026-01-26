import Foundation

/// Strips HTML tags and converts HTML content to plain text with paragraph breaks.
/// Per spec: removes script/style entirely, converts block-level tags to paragraph breaks,
/// handles consecutive BR tags, decodes HTML entities.
enum HTMLStripper {
    /// Strip HTML from content, preserving paragraph structure
    /// - Parameter html: The HTML content to process
    /// - Returns: Plain text with paragraph breaks (\n\n)
    static func strip(_ html: String) -> String {
        var result = html

        // 1. Remove script and style content entirely (including tags)
        result = removeTagWithContent(result, tag: "script")
        result = removeTagWithContent(result, tag: "style")

        // 2. Convert block-level elements to paragraph breaks BEFORE removing tags
        let blockTags = ["p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "li", "blockquote", "article", "section", "header", "footer", "aside", "nav"]
        for tag in blockTags {
            // Opening tags become paragraph breaks
            result = result.replacingOccurrences(
                of: "<\(tag)(\\s[^>]*)?>",
                with: "\n\n",
                options: [.regularExpression, .caseInsensitive]
            )
            // Closing tags become paragraph breaks
            result = result.replacingOccurrences(
                of: "</\(tag)>",
                with: "\n\n",
                options: .caseInsensitive
            )
        }

        // 3. Handle consecutive <br> tags as paragraph breaks
        // Two or more <br> tags in sequence = paragraph break
        result = result.replacingOccurrences(
            of: "(<br\\s*/?>\\s*){2,}",
            with: "\n\n",
            options: [.regularExpression, .caseInsensitive]
        )

        // Single <br> becomes a newline (not paragraph break)
        result = result.replacingOccurrences(
            of: "<br\\s*/?>",
            with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )

        // 4. Remove all remaining HTML tags
        result = result.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )

        // 5. Decode HTML entities
        result = decodeHTMLEntities(result)

        // 6. Normalize whitespace
        // Collapse multiple spaces to single space (but preserve newlines)
        result = result.replacingOccurrences(
            of: "[ \\t]+",
            with: " ",
            options: .regularExpression
        )

        // Collapse 3+ newlines to double newline (paragraph break)
        result = result.replacingOccurrences(
            of: "\\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )

        // Trim each line
        let lines = result.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        result = lines.joined(separator: "\n")

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private Methods

    private static func removeTagWithContent(_ html: String, tag: String) -> String {
        // Remove <tag>...</tag> including content
        // Use non-greedy matching
        let pattern = "<\(tag)(\\s[^>]*)?>([\\s\\S]*?)</\(tag)>"
        return html.replacingOccurrences(
            of: pattern,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    private static func decodeHTMLEntities(_ text: String) -> String {
        var result = text

        // Named entities - common ones per spec
        let namedEntities: [String: String] = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            // Typographic quotes
            "&ldquo;": "\u{201C}",  // "
            "&rdquo;": "\u{201D}",  // "
            "&lsquo;": "\u{2018}",  // '
            "&rsquo;": "\u{2019}",  // '
            // Dashes
            "&mdash;": "\u{2014}",  // —
            "&ndash;": "\u{2013}",  // –
            // Other common entities
            "&hellip;": "…",
            "&copy;": "©",
            "&reg;": "®",
            "&trade;": "™",
            "&deg;": "°",
            "&pound;": "£",
            "&euro;": "€",
            "&cent;": "¢",
            "&yen;": "¥",
            "&sect;": "§",
            "&para;": "¶",
            "&dagger;": "†",
            "&Dagger;": "‡",
            "&bull;": "•",
            "&middot;": "·",
            "&iexcl;": "¡",
            "&iquest;": "¿"
        ]

        for (entity, replacement) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        // Numeric entities (decimal): &#123;
        if let regex = try? NSRegularExpression(pattern: "&#(\\d+);", options: []) {
            let matches = regex.matches(in: result, options: [], range: NSRange(result.startIndex..., in: result))
            // Process in reverse to not invalidate ranges
            for match in matches.reversed() {
                if let codeRange = Range(match.range(at: 1), in: result),
                   let fullRange = Range(match.range, in: result),
                   let codePoint = Int(result[codeRange]),
                   let scalar = Unicode.Scalar(codePoint) {
                    result.replaceSubrange(fullRange, with: String(Character(scalar)))
                }
            }
        }

        // Numeric entities (hex): &#x1F4;
        if let regex = try? NSRegularExpression(pattern: "&#x([0-9a-fA-F]+);", options: []) {
            let matches = regex.matches(in: result, options: [], range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let codeRange = Range(match.range(at: 1), in: result),
                   let fullRange = Range(match.range, in: result),
                   let codePoint = Int(result[codeRange], radix: 16),
                   let scalar = Unicode.Scalar(codePoint) {
                    result.replaceSubrange(fullRange, with: String(Character(scalar)))
                }
            }
        }

        return result
    }
}
