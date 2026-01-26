import Foundation

/// Strips markdown syntax from text while preserving content
enum MarkdownStripper {
    /// Strips markdown syntax from text while preserving content and paragraph structure
    static func strip(_ text: String) -> String {
        var result = text

        // Remove fenced code blocks (```...```)
        // Must be done first to avoid processing markdown inside code blocks
        result = removeFencedCodeBlocks(result)

        // Remove inline code (`code`)
        result = removeInlineCode(result)

        // Remove images (![alt](url))
        result = removeImages(result)

        // Convert links [text](url) to just text
        result = convertLinks(result)

        // Remove headers (# ## ### etc.) - keep text
        result = removeHeaders(result)

        // Remove bold/italic markers (**, *, __, _) - keep text
        result = removeBoldItalic(result)

        // Remove horizontal rules (---, ***, ___)
        result = removeHorizontalRules(result)

        // Remove blockquote markers (>)
        result = removeBlockquotes(result)

        // Remove list markers (-, *, +, 1., 2., etc.)
        result = removeListMarkers(result)

        return result
    }

    // MARK: - Private Methods

    private static func removeFencedCodeBlocks(_ text: String) -> String {
        // Match ```language\n...``` or just ```...```
        let pattern = "```[^`]*```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }

    private static func removeInlineCode(_ text: String) -> String {
        // Match `code` but not inside code blocks (already removed)
        let pattern = "`([^`]+)`"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1")
    }

    private static func removeImages(_ text: String) -> String {
        // Match ![alt](url) or ![alt][ref]
        let pattern = "!\\[[^\\]]*\\]\\([^)]*\\)|!\\[[^\\]]*\\]\\[[^\\]]*\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }

    private static func convertLinks(_ text: String) -> String {
        // Match [text](url) and replace with text
        let pattern = "\\[([^\\]]+)\\]\\([^)]*\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1")
    }

    private static func removeHeaders(_ text: String) -> String {
        // Match lines starting with # ## ### etc.
        let lines = text.components(separatedBy: "\n")
        let processedLines = lines.map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                // Find first non-# non-space character
                var index = trimmed.startIndex
                while index < trimmed.endIndex && (trimmed[index] == "#" || trimmed[index] == " ") {
                    index = trimmed.index(after: index)
                }
                return String(trimmed[index...])
            }
            return line
        }
        return processedLines.joined(separator: "\n")
    }

    private static func removeBoldItalic(_ text: String) -> String {
        var result = text

        // Bold: **text** or __text__
        let boldPatterns = ["\\*\\*([^*]+)\\*\\*", "__([^_]+)__"]
        for pattern in boldPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1")
            }
        }

        // Italic: *text* or _text_
        // Be careful not to match underscores in words like snake_case
        let italicPatterns = ["\\*([^*]+)\\*", "(?<![\\w])_([^_]+)_(?![\\w])"]
        for pattern in italicPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1")
            }
        }

        return result
    }

    private static func removeHorizontalRules(_ text: String) -> String {
        // Match lines that are just ---, ***, or ___ (with optional spaces)
        let lines = text.components(separatedBy: "\n")
        let filteredLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Check for horizontal rules
            let hrPatterns = [
                "^-{3,}$",
                "^\\*{3,}$",
                "^_{3,}$",
                "^(- ){3,}-?$",
                "^(\\* ){3,}\\*?$",
                "^(_ ){3,}_?$"
            ]
            for pattern in hrPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                    return false
                }
            }
            return true
        }
        return filteredLines.joined(separator: "\n")
    }

    private static func removeBlockquotes(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let processedLines = lines.map { line -> String in
            var result = line
            // Remove leading > characters
            while result.hasPrefix(">") {
                result = String(result.dropFirst())
                // Also remove a space after > if present
                if result.hasPrefix(" ") {
                    result = String(result.dropFirst())
                }
            }
            return result
        }
        return processedLines.joined(separator: "\n")
    }

    private static func removeListMarkers(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let processedLines = lines.map { line -> String in
            var trimmed = line
            // Get leading whitespace
            let leadingSpaces = line.prefix(while: { $0 == " " || $0 == "\t" })
            trimmed = String(line.dropFirst(leadingSpaces.count))

            // Check for unordered list markers (-, *, +)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                return String(leadingSpaces) + String(trimmed.dropFirst(2))
            }

            // Check for ordered list markers (1., 2., etc.)
            let orderedPattern = "^(\\d+)\\.\\s"
            if let regex = try? NSRegularExpression(pattern: orderedPattern, options: []),
               let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)) {
                let afterMatch = trimmed.index(trimmed.startIndex, offsetBy: match.range.location + match.range.length)
                return String(leadingSpaces) + String(trimmed[afterMatch...])
            }

            return line
        }
        return processedLines.joined(separator: "\n")
    }
}
