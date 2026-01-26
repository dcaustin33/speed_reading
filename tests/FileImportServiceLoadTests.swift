#!/usr/bin/env swift

// FileImportServiceLoadTests.swift
// Tests for FileImportService TXT and MD loading

import Foundation
import CryptoKit

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

func assertThrows<E: Error & Equatable>(_ expectedError: E, _ block: () throws -> Void) throws {
    do {
        try block()
        throw TestError.assertionFailed("Expected error \(expectedError) but no error was thrown")
    } catch let error as E {
        guard error == expectedError else {
            throw TestError.assertionFailed("Expected error \(expectedError) but got \(error)")
        }
    } catch {
        throw TestError.assertionFailed("Expected error \(expectedError) but got different error type: \(error)")
    }
}

enum TestError: Error {
    case assertionFailed(String)
}

// MARK: - Test Setup

let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("FileImportTests_\(UUID().uuidString)")

func setupTestDirectory() throws {
    try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
}

func cleanupTestDirectory() {
    try? FileManager.default.removeItem(at: testDir)
}

func createTestFile(name: String, content: String, encoding: String.Encoding = .utf8) throws -> URL {
    let url = testDir.appendingPathComponent(name)
    try content.write(to: url, atomically: true, encoding: encoding)
    return url
}

func createTestFileFromData(name: String, data: Data) throws -> URL {
    let url = testDir.appendingPathComponent(name)
    try data.write(to: url)
    return url
}

// MARK: - FileImportError (copy from implementation)

enum FileImportError: Error, Equatable {
    case fileNotFound
    case unsupportedFormat
    case encodingError
    case emptyFile
    case readError(String)
}

// MARK: - FileType (copy from implementation)

enum FileType: String, Codable, Hashable, CaseIterable {
    case txt
    case md
    case epub

    var fileExtension: String { rawValue }

    static func from(extension ext: String) -> FileType? {
        FileType(rawValue: ext.lowercased())
    }
}

// MARK: - MarkdownStripper (copy from implementation)

enum MarkdownStripper {
    static func strip(_ text: String) -> String {
        var result = text
        result = removeFencedCodeBlocks(result)
        result = removeInlineCode(result)
        result = removeImages(result)
        result = convertLinks(result)
        result = removeHeaders(result)
        result = removeBoldItalic(result)
        result = removeHorizontalRules(result)
        result = removeBlockquotes(result)
        result = removeListMarkers(result)
        return result
    }

    private static func removeFencedCodeBlocks(_ text: String) -> String {
        let pattern = "```[^`]*```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }

    private static func removeInlineCode(_ text: String) -> String {
        let pattern = "`([^`]+)`"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1")
    }

    private static func removeImages(_ text: String) -> String {
        let pattern = "!\\[[^\\]]*\\]\\([^)]*\\)|!\\[[^\\]]*\\]\\[[^\\]]*\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }

    private static func convertLinks(_ text: String) -> String {
        let pattern = "\\[([^\\]]+)\\]\\([^)]*\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1")
    }

    private static func removeHeaders(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let processedLines = lines.map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
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
        let boldPatterns = ["\\*\\*([^*]+)\\*\\*", "__([^_]+)__"]
        for pattern in boldPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1")
            }
        }
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
        let lines = text.components(separatedBy: "\n")
        let filteredLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let hrPatterns = ["^-{3,}$", "^\\*{3,}$", "^_{3,}$", "^(- ){3,}-?$", "^(\\* ){3,}\\*?$", "^(_ ){3,}_?$"]
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
            while result.hasPrefix(">") {
                result = String(result.dropFirst())
                if result.hasPrefix(" ") { result = String(result.dropFirst()) }
            }
            return result
        }
        return processedLines.joined(separator: "\n")
    }

    private static func removeListMarkers(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let processedLines = lines.map { line -> String in
            var trimmed = line
            let leadingSpaces = line.prefix(while: { $0 == " " || $0 == "\t" })
            trimmed = String(line.dropFirst(leadingSpaces.count))
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                return String(leadingSpaces) + String(trimmed.dropFirst(2))
            }
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

// MARK: - FileLoadResult (copy from implementation)

struct FileLoadResult {
    let content: String
    let hash: String
}

// MARK: - FileImportService (copy from implementation)

enum FileImportService {
    static func loadTextFile(from url: URL) throws -> FileLoadResult {
        let data = try loadFileData(from: url)
        let content = try decodeText(from: data)
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FileImportError.emptyFile
        }
        let hash = calculateHash(data: data)
        return FileLoadResult(content: content, hash: hash)
    }

    static func loadMarkdownFile(from url: URL) throws -> FileLoadResult {
        let data = try loadFileData(from: url)
        let rawContent = try decodeText(from: data)
        let strippedContent = MarkdownStripper.strip(rawContent)
        guard !strippedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FileImportError.emptyFile
        }
        let hash = calculateHash(data: data)
        return FileLoadResult(content: strippedContent, hash: hash)
    }

    static func loadFile(from url: URL, fileType: FileType) throws -> FileLoadResult {
        switch fileType {
        case .txt:
            return try loadTextFile(from: url)
        case .md:
            return try loadMarkdownFile(from: url)
        case .epub:
            throw FileImportError.unsupportedFormat
        }
    }

    static func fileType(from url: URL) -> FileType? {
        let ext = url.pathExtension.lowercased()
        return FileType.from(extension: ext)
    }

    static func validateFileType(url: URL) throws -> FileType {
        guard let type = fileType(from: url) else {
            throw FileImportError.unsupportedFormat
        }
        return type
    }

    private static func loadFileData(from url: URL) throws -> Data {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileImportError.fileNotFound
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw FileImportError.readError(error.localizedDescription)
        }
    }

    private static func decodeText(from data: Data) throws -> String {
        if let text = String(data: data, encoding: .utf8) { return text }
        // Try single-byte encodings before UTF-16
        let singleByteEncodings: [String.Encoding] = [.isoLatin1, .windowsCP1252, .ascii]
        for encoding in singleByteEncodings {
            if let text = String(data: data, encoding: encoding) { return text }
        }
        // Try UTF-16 variants last
        let utf16Encodings: [String.Encoding] = [.utf16, .utf16LittleEndian, .utf16BigEndian]
        for encoding in utf16Encodings {
            if let text = String(data: data, encoding: encoding) { return text }
        }
        throw FileImportError.encodingError
    }

    private static func calculateHash(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Tests

print("=== FileImportService Tests ===\n")

do {
    try setupTestDirectory()
} catch {
    print("Failed to setup test directory: \(error)")
    exit(1)
}

defer { cleanupTestDirectory() }

// Test: Load plain text file
test("loadTextFile loads UTF-8 content correctly") {
    let content = "Hello, World!\nThis is a test file."
    let url = try createTestFile(name: "test.txt", content: content)
    let result = try FileImportService.loadTextFile(from: url)
    try assertEqual(result.content, content)
    try assertFalse(result.hash.isEmpty, "Hash should not be empty")
}

test("loadTextFile calculates correct SHA256 hash") {
    let content = "Test content for hashing"
    let url = try createTestFile(name: "hash_test.txt", content: content)
    let result = try FileImportService.loadTextFile(from: url)

    // Manually calculate expected hash
    let data = content.data(using: .utf8)!
    let expectedHash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    try assertEqual(result.hash, expectedHash)
}

test("loadTextFile handles Latin-1 encoding") {
    // Create Latin-1 encoded file with bytes that are invalid UTF-8 but valid Latin-1
    // 0xE9 = é in Latin-1, which is invalid as a standalone byte in UTF-8
    let latin1Bytes: [UInt8] = [0x43, 0x61, 0x66, 0xE9]  // "Café" in Latin-1
    let data = Data(latin1Bytes)
    let url = try createTestFileFromData(name: "latin1.txt", data: data)
    let result = try FileImportService.loadTextFile(from: url)
    try assertTrue(result.content.contains("Caf"), "Should contain decoded content")
}

test("loadTextFile throws fileNotFound for missing file") {
    let url = testDir.appendingPathComponent("nonexistent.txt")
    try assertThrows(FileImportError.fileNotFound) {
        _ = try FileImportService.loadTextFile(from: url)
    }
}

test("loadTextFile throws emptyFile for empty content") {
    let url = try createTestFile(name: "empty.txt", content: "")
    try assertThrows(FileImportError.emptyFile) {
        _ = try FileImportService.loadTextFile(from: url)
    }
}

test("loadTextFile throws emptyFile for whitespace-only content") {
    let url = try createTestFile(name: "whitespace.txt", content: "   \n\n   \t  ")
    try assertThrows(FileImportError.emptyFile) {
        _ = try FileImportService.loadTextFile(from: url)
    }
}

// Test: Load markdown file
test("loadMarkdownFile strips markdown and returns content") {
    let markdown = """
    # Hello World

    This is **bold** and *italic* text.

    - Item 1
    - Item 2
    """
    let url = try createTestFile(name: "test.md", content: markdown)
    let result = try FileImportService.loadMarkdownFile(from: url)

    try assertTrue(result.content.contains("Hello World"), "Should contain header text")
    try assertTrue(result.content.contains("bold"), "Should contain bold text")
    try assertTrue(result.content.contains("italic"), "Should contain italic text")
    try assertTrue(result.content.contains("Item 1"), "Should contain list items")
    try assertFalse(result.content.contains("#"), "Should not contain header marker")
    try assertFalse(result.content.contains("**"), "Should not contain bold markers")
}

test("loadMarkdownFile calculates hash from original data") {
    let markdown = "# Title\n\nContent"
    let url = try createTestFile(name: "hash_md.md", content: markdown)
    let result = try FileImportService.loadMarkdownFile(from: url)

    // Hash should be of original content, not stripped
    let data = markdown.data(using: .utf8)!
    let expectedHash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    try assertEqual(result.hash, expectedHash)
}

test("loadMarkdownFile throws emptyFile for markdown-only content") {
    // A file with only markdown syntax that becomes empty when stripped
    let url = try createTestFile(name: "only_markdown.md", content: "# \n---\n```\n```")
    try assertThrows(FileImportError.emptyFile) {
        _ = try FileImportService.loadMarkdownFile(from: url)
    }
}

// Test: File type detection
test("fileType correctly identifies .txt files") {
    let url = URL(fileURLWithPath: "/path/to/file.txt")
    let type = FileImportService.fileType(from: url)
    try assertEqual(type, .txt)
}

test("fileType correctly identifies .md files") {
    let url = URL(fileURLWithPath: "/path/to/file.md")
    let type = FileImportService.fileType(from: url)
    try assertEqual(type, .md)
}

test("fileType correctly identifies .epub files") {
    let url = URL(fileURLWithPath: "/path/to/file.epub")
    let type = FileImportService.fileType(from: url)
    try assertEqual(type, .epub)
}

test("fileType returns nil for unsupported extensions") {
    let url = URL(fileURLWithPath: "/path/to/file.pdf")
    let type = FileImportService.fileType(from: url)
    try assertEqual(type, nil)
}

test("fileType is case insensitive") {
    let url1 = URL(fileURLWithPath: "/path/to/file.TXT")
    let url2 = URL(fileURLWithPath: "/path/to/file.MD")
    let url3 = URL(fileURLWithPath: "/path/to/file.EPUB")

    try assertEqual(FileImportService.fileType(from: url1), .txt)
    try assertEqual(FileImportService.fileType(from: url2), .md)
    try assertEqual(FileImportService.fileType(from: url3), .epub)
}

// Test: validateFileType
test("validateFileType returns type for supported files") {
    let txtUrl = URL(fileURLWithPath: "/path/to/file.txt")
    let mdUrl = URL(fileURLWithPath: "/path/to/file.md")
    let epubUrl = URL(fileURLWithPath: "/path/to/file.epub")

    let txtType = try FileImportService.validateFileType(url: txtUrl)
    let mdType = try FileImportService.validateFileType(url: mdUrl)
    let epubType = try FileImportService.validateFileType(url: epubUrl)

    try assertEqual(txtType, .txt)
    try assertEqual(mdType, .md)
    try assertEqual(epubType, .epub)
}

test("validateFileType throws unsupportedFormat for unknown extensions") {
    let url = URL(fileURLWithPath: "/path/to/file.pdf")
    try assertThrows(FileImportError.unsupportedFormat) {
        _ = try FileImportService.validateFileType(url: url)
    }
}

// Test: loadFile dispatcher
test("loadFile dispatches to loadTextFile for .txt") {
    let content = "Plain text content"
    let url = try createTestFile(name: "dispatch.txt", content: content)
    let result = try FileImportService.loadFile(from: url, fileType: .txt)
    try assertEqual(result.content, content)
}

test("loadFile dispatches to loadMarkdownFile for .md") {
    let markdown = "# Title\nContent"
    let url = try createTestFile(name: "dispatch.md", content: markdown)
    let result = try FileImportService.loadFile(from: url, fileType: .md)
    try assertTrue(result.content.contains("Title"), "Should contain title")
    try assertFalse(result.content.contains("#"), "Should strip markdown")
}

test("loadFile throws unsupportedFormat for .epub") {
    // EPUB is handled by EPUBImportService (Task 5)
    let url = URL(fileURLWithPath: "/fake/file.epub")
    try assertThrows(FileImportError.unsupportedFormat) {
        _ = try FileImportService.loadFile(from: url, fileType: .epub)
    }
}

// Test: Unicode content
test("loadTextFile handles unicode content") {
    let content = "Hello 你好 مرحبا שלום 🌍🎉"
    let url = try createTestFile(name: "unicode.txt", content: content)
    let result = try FileImportService.loadTextFile(from: url)
    try assertEqual(result.content, content)
}

// Test: Large content
test("loadTextFile handles large files") {
    let paragraph = "This is a paragraph of text that will be repeated many times. "
    let content = String(repeating: paragraph, count: 10000)
    let url = try createTestFile(name: "large.txt", content: content)
    let result = try FileImportService.loadTextFile(from: url)
    try assertEqual(result.content.count, content.count)
}

// MARK: - Summary

print("\n=== Test Summary ===")
print("Passed: \(testsPassed)")
print("Failed: \(testsFailed)")

if testsFailed > 0 {
    exit(1)
}
