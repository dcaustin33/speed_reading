#!/usr/bin/env swift

// FileImportServiceTests.swift
// Test-first tests for FileImportService

import Foundation

// MARK: - Test Framework

var testsPassed = 0
var testsFailed = 0

func test(_ name: String, _ block: () throws -> Void) {
    do {
        try block()
        print("✅ \(name)")
        testsPassed += 1
    } catch {
        print("❌ \(name): \(error)")
        testsFailed += 1
    }
}

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, file: String = #file, line: Int = #line) throws {
    guard actual == expected else {
        throw TestError.assertionFailed("Expected \(expected), got \(actual) at line \(line)")
    }
}

func assertTrue(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) throws {
    guard condition else {
        throw TestError.assertionFailed("Assertion failed: \(message) at line \(line)")
    }
}

func assertFalse(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) throws {
    guard !condition else {
        throw TestError.assertionFailed("Expected false: \(message) at line \(line)")
    }
}

enum TestError: Error {
    case assertionFailed(String)
}

// MARK: - FileImportError (expected from implementation)

enum FileImportError: Error, Equatable {
    case fileNotFound
    case unsupportedFormat
    case encodingError
    case emptyFile
    case readError(String)
}

// MARK: - MarkdownStripper (copy from implementation for testing)

enum MarkdownStripper {
    /// Strips markdown syntax from text while preserving content
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

// MARK: - Tests

print("=== Markdown Stripping Tests ===\n")

// Test: Remove fenced code blocks
test("removes fenced code blocks") {
    let input = """
    Before code
    ```python
    def hello():
        print("hello")
    ```
    After code
    """
    let result = MarkdownStripper.strip(input)
    try assertFalse(result.contains("```"), "Should not contain code fence")
    try assertFalse(result.contains("def hello"), "Should not contain code")
    try assertTrue(result.contains("Before code"), "Should keep text before")
    try assertTrue(result.contains("After code"), "Should keep text after")
}

test("removes multiple fenced code blocks") {
    let input = """
    First block:
    ```
    code1
    ```
    Middle text
    ```js
    code2
    ```
    End text
    """
    let result = MarkdownStripper.strip(input)
    try assertFalse(result.contains("code1"), "Should not contain code1")
    try assertFalse(result.contains("code2"), "Should not contain code2")
    try assertTrue(result.contains("First block"), "Should keep first text")
    try assertTrue(result.contains("Middle text"), "Should keep middle text")
    try assertTrue(result.contains("End text"), "Should keep end text")
}

// Test: Remove inline code
test("removes inline code backticks but keeps content") {
    let input = "Use the `print()` function"
    let result = MarkdownStripper.strip(input)
    try assertEqual(result, "Use the print() function")
}

test("handles multiple inline codes") {
    let input = "Variables `x` and `y` are used"
    let result = MarkdownStripper.strip(input)
    try assertEqual(result, "Variables x and y are used")
}

// Test: Remove images
test("removes images entirely") {
    let input = "Text ![alt text](image.png) more text"
    let result = MarkdownStripper.strip(input)
    try assertFalse(result.contains("!["), "Should not contain image syntax")
    try assertFalse(result.contains("image.png"), "Should not contain image URL")
    try assertTrue(result.contains("Text"), "Should keep text before")
    try assertTrue(result.contains("more text"), "Should keep text after")
}

test("removes images with reference syntax") {
    let input = "See ![image][ref] below"
    let result = MarkdownStripper.strip(input)
    try assertFalse(result.contains("!["), "Should not contain image syntax")
}

// Test: Convert links
test("converts links to just text") {
    let input = "Click [here](https://example.com) to continue"
    let result = MarkdownStripper.strip(input)
    try assertEqual(result, "Click here to continue")
}

test("handles multiple links") {
    let input = "[Link1](url1) and [Link2](url2)"
    let result = MarkdownStripper.strip(input)
    try assertEqual(result, "Link1 and Link2")
}

// Test: Remove headers
test("removes h1 headers") {
    let input = "# Main Title\nContent here"
    let result = MarkdownStripper.strip(input)
    try assertTrue(result.contains("Main Title"), "Should keep header text")
    try assertFalse(result.contains("#"), "Should not contain #")
}

test("removes h2-h6 headers") {
    let input = """
    ## Section
    ### Subsection
    #### Deep
    ##### Deeper
    ###### Deepest
    """
    let result = MarkdownStripper.strip(input)
    try assertFalse(result.contains("#"), "Should not contain any #")
    try assertTrue(result.contains("Section"), "Should keep Section")
    try assertTrue(result.contains("Subsection"), "Should keep Subsection")
}

// Test: Remove bold/italic
test("removes bold markers **text**") {
    let input = "This is **bold** text"
    let result = MarkdownStripper.strip(input)
    try assertEqual(result, "This is bold text")
}

test("removes bold markers __text__") {
    let input = "This is __bold__ text"
    let result = MarkdownStripper.strip(input)
    try assertEqual(result, "This is bold text")
}

test("removes italic markers *text*") {
    let input = "This is *italic* text"
    let result = MarkdownStripper.strip(input)
    try assertEqual(result, "This is italic text")
}

test("removes italic markers _text_") {
    let input = "This is _italic_ text"
    let result = MarkdownStripper.strip(input)
    try assertEqual(result, "This is italic text")
}

test("preserves underscores in words") {
    let input = "Variable snake_case_name is used"
    let result = MarkdownStripper.strip(input)
    try assertEqual(result, "Variable snake_case_name is used")
}

test("handles nested bold and italic") {
    let input = "This is ***bold and italic*** text"
    let result = MarkdownStripper.strip(input)
    try assertTrue(result.contains("bold and italic"), "Should keep content")
    try assertFalse(result.contains("***"), "Should not contain markers")
}

// Test: Remove horizontal rules
test("removes horizontal rule ---") {
    let input = "Above\n---\nBelow"
    let result = MarkdownStripper.strip(input)
    try assertFalse(result.contains("---"), "Should not contain ---")
    try assertTrue(result.contains("Above"), "Should keep Above")
    try assertTrue(result.contains("Below"), "Should keep Below")
}

test("removes horizontal rule ***") {
    let input = "Above\n***\nBelow"
    let result = MarkdownStripper.strip(input)
    try assertFalse(result.contains("***"), "Should not contain ***")
}

test("removes horizontal rule ___") {
    let input = "Above\n___\nBelow"
    let result = MarkdownStripper.strip(input)
    try assertFalse(result.contains("___"), "Should not contain ___")
}

// Test: Remove blockquotes
test("removes blockquote markers") {
    let input = "> This is a quote"
    let result = MarkdownStripper.strip(input)
    try assertEqual(result, "This is a quote")
}

test("handles nested blockquotes") {
    let input = ">> Nested quote"
    let result = MarkdownStripper.strip(input)
    try assertEqual(result, "Nested quote")
}

test("handles multi-line blockquotes") {
    let input = """
    > Line 1
    > Line 2
    > Line 3
    """
    let result = MarkdownStripper.strip(input)
    try assertTrue(result.contains("Line 1"), "Should keep Line 1")
    try assertFalse(result.contains(">"), "Should not contain >")
}

// Test: Remove list markers
test("removes unordered list marker -") {
    let input = """
    - Item 1
    - Item 2
    - Item 3
    """
    let result = MarkdownStripper.strip(input)
    try assertTrue(result.contains("Item 1"), "Should keep Item 1")
    try assertTrue(result.contains("Item 2"), "Should keep Item 2")
    // Check that dash markers are removed (but dashes in content should be kept)
    let lines = result.components(separatedBy: "\n")
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        try assertFalse(trimmed.hasPrefix("- "), "Line should not start with '- ': \(line)")
    }
}

test("removes unordered list marker *") {
    let input = """
    * Item 1
    * Item 2
    """
    let result = MarkdownStripper.strip(input)
    try assertTrue(result.contains("Item 1"), "Should keep Item 1")
    let lines = result.components(separatedBy: "\n")
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        try assertFalse(trimmed.hasPrefix("* "), "Line should not start with '* '")
    }
}

test("removes unordered list marker +") {
    let input = """
    + Item 1
    + Item 2
    """
    let result = MarkdownStripper.strip(input)
    try assertTrue(result.contains("Item 1"), "Should keep Item 1")
    let lines = result.components(separatedBy: "\n")
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        try assertFalse(trimmed.hasPrefix("+ "), "Line should not start with '+ '")
    }
}

test("removes ordered list markers") {
    let input = """
    1. First
    2. Second
    10. Tenth
    """
    let result = MarkdownStripper.strip(input)
    try assertTrue(result.contains("First"), "Should keep First")
    try assertTrue(result.contains("Second"), "Should keep Second")
    try assertTrue(result.contains("Tenth"), "Should keep Tenth")
    let lines = result.components(separatedBy: "\n")
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Check line doesn't start with number followed by dot and space
        if let regex = try? NSRegularExpression(pattern: "^\\d+\\.\\s", options: []),
           regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
            throw TestError.assertionFailed("Line should not start with ordered list marker: \(line)")
        }
    }
}

test("preserves indented list content") {
    let input = """
    - Item 1
      - Nested item
    - Item 2
    """
    let result = MarkdownStripper.strip(input)
    try assertTrue(result.contains("Item 1"), "Should keep Item 1")
    try assertTrue(result.contains("Nested item"), "Should keep Nested item")
    try assertTrue(result.contains("Item 2"), "Should keep Item 2")
}

// Test: Complex document
test("handles complex markdown document") {
    let input = """
    # Welcome to My Document

    This is a **bold** statement with *emphasis*.

    ## Features

    - Feature 1
    - Feature 2
    - Feature 3

    Here's some `code` inline.

    ```python
    def main():
        pass
    ```

    > A wise quote

    Visit [our site](https://example.com) for more.

    ---

    1. First step
    2. Second step
    """

    let result = MarkdownStripper.strip(input)

    // Should contain text content
    try assertTrue(result.contains("Welcome to My Document"), "Should keep title")
    try assertTrue(result.contains("bold"), "Should keep bold text")
    try assertTrue(result.contains("emphasis"), "Should keep emphasis text")
    try assertTrue(result.contains("Feature 1"), "Should keep features")
    try assertTrue(result.contains("code"), "Should keep inline code content")
    try assertTrue(result.contains("A wise quote"), "Should keep quote text")
    try assertTrue(result.contains("our site"), "Should keep link text")
    try assertTrue(result.contains("First step"), "Should keep list items")

    // Should not contain markdown syntax
    try assertFalse(result.contains("#"), "Should not contain headers")
    try assertFalse(result.contains("**"), "Should not contain bold markers")
    try assertFalse(result.contains("```"), "Should not contain code fences")
    try assertFalse(result.contains("def main"), "Should not contain code block content")
    try assertFalse(result.contains("]("), "Should not contain link syntax")
}

// Test: Preserve paragraph structure
test("preserves blank lines for paragraph structure") {
    let input = """
    # Title

    First paragraph text.

    Second paragraph text.
    """
    let result = MarkdownStripper.strip(input)
    // Should have blank lines preserved
    try assertTrue(result.contains("\n\n"), "Should preserve paragraph breaks")
}

// MARK: - Summary

print("\n=== Test Summary ===")
print("Passed: \(testsPassed)")
print("Failed: \(testsFailed)")

if testsFailed > 0 {
    exit(1)
}
