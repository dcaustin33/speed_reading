#!/usr/bin/env swift

// ChapterTimeRemainingTests.swift
// Tests for chapter time remaining calculation

import Foundation

// MARK: - Test Framework

var testsPassed = 0
var testsFailed = 0

func test(_ name: String, _ block: () throws -> Void) {
    do {
        try block()
        print("  \(name)")
        testsPassed += 1
    } catch {
        print("  \(name): \(error)")
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

func assertNil<T>(_ value: T?, _ message: String = "", file: String = #file, line: Int = #line) throws {
    guard value == nil else {
        throw TestError.assertionFailed("Expected nil, got \(value!) \(message) at line \(line)")
    }
}

func assertNotNil<T>(_ value: T?, _ message: String = "", file: String = #file, line: Int = #line) throws {
    guard value != nil else {
        throw TestError.assertionFailed("Expected non-nil \(message) at line \(line)")
    }
}

func assertApproxEqual(_ actual: Double, _ expected: Double, tolerance: Double = 0.01, file: String = #file, line: Int = #line) throws {
    guard abs(actual - expected) <= tolerance else {
        throw TestError.assertionFailed("Expected ~\(expected), got \(actual) (tolerance \(tolerance)) at line \(line)")
    }
}

enum TestError: Error {
    case assertionFailed(String)
}

// MARK: - Type Copies

struct Word: Equatable, Hashable {
    let text: String
    let orpIndex: Int
    let sentenceEnd: Bool
    let paragraphEnd: Bool
    let chapterIndex: Int?

    init(
        text: String,
        orpIndex: Int,
        sentenceEnd: Bool = false,
        paragraphEnd: Bool = false,
        chapterIndex: Int? = nil
    ) {
        self.text = text
        self.orpIndex = orpIndex
        self.sentenceEnd = sentenceEnd
        self.paragraphEnd = paragraphEnd
        self.chapterIndex = chapterIndex
    }
}

struct Chapter: Equatable, Hashable, Codable {
    let title: String
    let startWordIndex: Int
}

struct Document {
    let words: [Word]
    let chapters: [Chapter]?
    var totalWords: Int { words.count }

    init(words: [Word], chapters: [Chapter]? = nil) {
        self.words = words
        self.chapters = chapters
    }
}

// MARK: - Chapter Time Remaining Logic (mirrors PlaybackEngine)

func chapterRemainingTime(
    document: Document,
    currentWordIndex: Int,
    wpm: Int,
    paragraphPause: Double
) -> TimeInterval? {
    guard let chapters = document.chapters, !chapters.isEmpty else { return nil }
    guard currentWordIndex < document.totalWords else { return nil }

    let currentWord = document.words[currentWordIndex]
    guard let chapterIdx = currentWord.chapterIndex else { return nil }

    // Find chapter end: next chapter's startWordIndex, or totalWords for last chapter
    let chapterEnd: Int
    if chapterIdx + 1 < chapters.count {
        chapterEnd = chapters[chapterIdx + 1].startWordIndex
    } else {
        chapterEnd = document.totalWords
    }

    let remainingWords = chapterEnd - currentWordIndex
    guard remainingWords > 0 else { return 0 }

    let wordDelayMs = 60000 / max(wpm, 1)
    let wordTime = Double(remainingWords) * (Double(wordDelayMs) / 1000.0)

    // Count paragraph pauses in remaining chapter range
    var paragraphCount = 0
    for i in currentWordIndex..<chapterEnd {
        if document.words[i].paragraphEnd {
            paragraphCount += 1
        }
    }
    let paragraphTime = Double(paragraphCount) * paragraphPause

    return wordTime + paragraphTime
}

func formatTime(_ seconds: TimeInterval) -> String {
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    } else {
        return String(format: "%d:%02d", minutes, secs)
    }
}

func chapterRemainingTimeFormatted(
    document: Document,
    currentWordIndex: Int,
    wpm: Int,
    paragraphPause: Double
) -> String? {
    guard let time = chapterRemainingTime(
        document: document,
        currentWordIndex: currentWordIndex,
        wpm: wpm,
        paragraphPause: paragraphPause
    ) else { return nil }
    return formatTime(time)
}

// MARK: - Helper: Build Words

func makeWords(count: Int, chapterIndex: Int? = nil, paragraphEndIndices: Set<Int> = []) -> [Word] {
    (0..<count).map { i in
        Word(
            text: "word\(i)",
            orpIndex: 1,
            paragraphEnd: paragraphEndIndices.contains(i),
            chapterIndex: chapterIndex
        )
    }
}

func makeWordsForChapters(chapters: [Chapter], totalWords: Int, paragraphEndIndices: Set<Int> = []) -> [Word] {
    (0..<totalWords).map { i in
        var chapterIdx: Int? = nil
        for (ci, chapter) in chapters.enumerated() {
            if chapter.startWordIndex <= i {
                chapterIdx = ci
            } else {
                break
            }
        }
        return Word(
            text: "word\(i)",
            orpIndex: 1,
            paragraphEnd: paragraphEndIndices.contains(i),
            chapterIndex: chapterIdx
        )
    }
}

// MARK: - Tests

print("=== Chapter Time Remaining Tests ===\n")

// Test 1: No chapters returns nil
test("No chapters returns nil") {
    let words = makeWords(count: 100)
    let doc = Document(words: words, chapters: nil)
    let result = chapterRemainingTime(document: doc, currentWordIndex: 5, wpm: 300, paragraphPause: 1.0)
    try assertNil(result, "Should return nil when no chapters")
}

// Test 2: Single chapter equals book remaining time
test("Single chapter equals book remaining time") {
    let chapters = [Chapter(title: "Chapter 1", startWordIndex: 0)]
    let words = makeWordsForChapters(chapters: chapters, totalWords: 100)
    let doc = Document(words: words, chapters: chapters)

    let chapterTime = chapterRemainingTime(document: doc, currentWordIndex: 50, wpm: 300, paragraphPause: 1.0)
    try assertNotNil(chapterTime)

    // Remaining = 100 - 50 = 50 words, delay = 60000/300 = 200ms = 0.2s
    // No paragraph pauses in this test
    let expected = 50.0 * 0.2
    try assertApproxEqual(chapterTime!, expected)
}

// Test 3: First chapter time remaining
test("First chapter time remaining") {
    let chapters = [
        Chapter(title: "Ch 1", startWordIndex: 0),
        Chapter(title: "Ch 2", startWordIndex: 100),
    ]
    let words = makeWordsForChapters(chapters: chapters, totalWords: 200)
    let doc = Document(words: words, chapters: chapters)

    // At word 5, chapter 1 ends at 100, so remaining = 100 - 5 = 95
    let time = chapterRemainingTime(document: doc, currentWordIndex: 5, wpm: 300, paragraphPause: 1.0)
    try assertNotNil(time)
    let expected = 95.0 * 0.2
    try assertApproxEqual(time!, expected)
}

// Test 4: Middle chapter time remaining
test("Middle chapter time remaining") {
    let chapters = [
        Chapter(title: "Ch 1", startWordIndex: 0),
        Chapter(title: "Ch 2", startWordIndex: 100),
        Chapter(title: "Ch 3", startWordIndex: 200),
    ]
    let words = makeWordsForChapters(chapters: chapters, totalWords: 300)
    let doc = Document(words: words, chapters: chapters)

    // At word 150, chapter 2 (100-199), remaining = 200 - 150 = 50
    let time = chapterRemainingTime(document: doc, currentWordIndex: 150, wpm: 300, paragraphPause: 1.0)
    try assertNotNil(time)
    let expected = 50.0 * 0.2
    try assertApproxEqual(time!, expected)
}

// Test 5: Last chapter time remaining
test("Last chapter time remaining") {
    let chapters = [
        Chapter(title: "Ch 1", startWordIndex: 0),
        Chapter(title: "Ch 2", startWordIndex: 100),
        Chapter(title: "Ch 3", startWordIndex: 200),
    ]
    let words = makeWordsForChapters(chapters: chapters, totalWords: 300)
    let doc = Document(words: words, chapters: chapters)

    // At word 250, last chapter (200-299), remaining = 300 - 250 = 50
    let time = chapterRemainingTime(document: doc, currentWordIndex: 250, wpm: 300, paragraphPause: 1.0)
    try assertNotNil(time)
    let expected = 50.0 * 0.2
    try assertApproxEqual(time!, expected)
}

// Test 6: At chapter boundary
test("At chapter boundary, time equals full chapter duration") {
    let chapters = [
        Chapter(title: "Ch 1", startWordIndex: 0),
        Chapter(title: "Ch 2", startWordIndex: 100),
    ]
    let words = makeWordsForChapters(chapters: chapters, totalWords: 200)
    let doc = Document(words: words, chapters: chapters)

    // At word 100 (first word of Ch 2), remaining = 200 - 100 = 100
    let time = chapterRemainingTime(document: doc, currentWordIndex: 100, wpm: 300, paragraphPause: 1.0)
    try assertNotNil(time)
    let expected = 100.0 * 0.2
    try assertApproxEqual(time!, expected)
}

// Test 7: Paragraph pauses within chapter
test("Paragraph pauses within chapter are included") {
    let chapters = [
        Chapter(title: "Ch 1", startWordIndex: 0),
        Chapter(title: "Ch 2", startWordIndex: 100),
    ]
    // Paragraph ends at indices 20 and 50 (within chapter 1)
    let words = makeWordsForChapters(chapters: chapters, totalWords: 200, paragraphEndIndices: [20, 50, 150])
    let doc = Document(words: words, chapters: chapters)

    // At word 10, chapter 1 ends at 100, remaining = 90 words
    // Paragraph ends in range [10, 100): indices 20 and 50 = 2 pauses
    let time = chapterRemainingTime(document: doc, currentWordIndex: 10, wpm: 300, paragraphPause: 1.0)
    try assertNotNil(time)
    let wordTime = 90.0 * 0.2 // 18.0
    let paraTime = 2.0 * 1.0  // 2.0
    try assertApproxEqual(time!, wordTime + paraTime)
}

// Test 8: Paragraph pauses outside chapter excluded
test("Paragraph pauses outside chapter are excluded") {
    let chapters = [
        Chapter(title: "Ch 1", startWordIndex: 0),
        Chapter(title: "Ch 2", startWordIndex: 100),
    ]
    // Paragraph end at 150 is in chapter 2, should not affect chapter 1 time
    let words = makeWordsForChapters(chapters: chapters, totalWords: 200, paragraphEndIndices: [150])
    let doc = Document(words: words, chapters: chapters)

    // At word 10 in chapter 1, no paragraph pauses in [10, 100)
    let time = chapterRemainingTime(document: doc, currentWordIndex: 10, wpm: 300, paragraphPause: 1.0)
    try assertNotNil(time)
    let expected = 90.0 * 0.2 // No paragraph pauses
    try assertApproxEqual(time!, expected)
}

// Test 9: Formatted output nil when no chapters
test("Formatted output nil when no chapters") {
    let words = makeWords(count: 100)
    let doc = Document(words: words, chapters: nil)
    let result = chapterRemainingTimeFormatted(document: doc, currentWordIndex: 5, wpm: 300, paragraphPause: 1.0)
    try assertNil(result)
}

// Test 10: Formatted output M:SS format
test("Formatted output M:SS format") {
    let chapters = [Chapter(title: "Ch 1", startWordIndex: 0)]
    // 600 words at 300 WPM = 120 seconds = 2:00
    let words = makeWordsForChapters(chapters: chapters, totalWords: 600)
    let doc = Document(words: words, chapters: chapters)

    let formatted = chapterRemainingTimeFormatted(document: doc, currentWordIndex: 0, wpm: 300, paragraphPause: 1.0)
    try assertNotNil(formatted)
    try assertEqual(formatted!, "2:00")
}

// Test 11: Formatted output H:MM:SS format
test("Formatted output H:MM:SS format") {
    let chapters = [Chapter(title: "Ch 1", startWordIndex: 0)]
    // 60000 words at 300 WPM = 0.2s * 60000 = 12000 seconds = 3:20:00
    let words = makeWordsForChapters(chapters: chapters, totalWords: 60000)
    let doc = Document(words: words, chapters: chapters)

    let formatted = chapterRemainingTimeFormatted(document: doc, currentWordIndex: 0, wpm: 300, paragraphPause: 1.0)
    try assertNotNil(formatted)
    try assertEqual(formatted!, "3:20:00")
}

// Test 12: At last word of chapter
test("At last word of chapter, time is minimal") {
    let chapters = [
        Chapter(title: "Ch 1", startWordIndex: 0),
        Chapter(title: "Ch 2", startWordIndex: 100),
    ]
    let words = makeWordsForChapters(chapters: chapters, totalWords: 200)
    let doc = Document(words: words, chapters: chapters)

    // At word 99 (last word of Ch 1), remaining = 100 - 99 = 1 word
    let time = chapterRemainingTime(document: doc, currentWordIndex: 99, wpm: 300, paragraphPause: 1.0)
    try assertNotNil(time)
    let expected = 1.0 * 0.2
    try assertApproxEqual(time!, expected)
}

// Test 13: WPM changes affect chapter time
test("WPM changes affect chapter time") {
    let chapters = [Chapter(title: "Ch 1", startWordIndex: 0)]
    let words = makeWordsForChapters(chapters: chapters, totalWords: 100)
    let doc = Document(words: words, chapters: chapters)

    let time300 = chapterRemainingTime(document: doc, currentWordIndex: 0, wpm: 300, paragraphPause: 1.0)!
    let time600 = chapterRemainingTime(document: doc, currentWordIndex: 0, wpm: 600, paragraphPause: 1.0)!

    // 300 WPM: 100 * 0.2 = 20s, 600 WPM: 100 * 0.1 = 10s
    try assertApproxEqual(time300, 20.0)
    try assertApproxEqual(time600, 10.0)
    try assertTrue(time300 > time600, "Higher WPM should mean less time")
}

// MARK: - Summary

print("\n=== Test Summary ===")
print("Passed: \(testsPassed)")
print("Failed: \(testsFailed)")

if testsFailed > 0 {
    exit(1)
}
