#!/usr/bin/env swift

// FontMetricsTests.swift
// Tests for cross-platform FontMetrics character width measurement

import Foundation
import CoreText

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

func assertTrue(_ condition: Bool, _ message: String = "", line: Int = #line) throws {
    guard condition else {
        throw TestError.assertionFailed("Assertion failed: \(message) at line \(line)")
    }
}

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, line: Int = #line) throws {
    guard actual == expected else {
        throw TestError.assertionFailed("Expected \(expected), got \(actual) at line \(line)")
    }
}

enum TestError: Error {
    case assertionFailed(String)
}

// MARK: - FontMetrics Logic (mirrors UI/Helpers/FontMetrics.swift, CTFont path)

func monospacedCharacterWidth(fontSize: CGFloat) -> CGFloat {
    let font = CTFontCreateWithName("Menlo" as CFString, fontSize, nil)
    let characters: [UniChar] = [0x0057] // 'W'
    var glyphs: [CGGlyph] = [0]
    CTFontGetGlyphsForCharacters(font, characters, &glyphs, 1)
    var advance = CGSize.zero
    CTFontGetAdvancesForGlyphs(font, .horizontal, &glyphs, &advance, 1)
    return advance.width
}

// MARK: - Tests

print("=== FontMetrics Tests ===\n")

// Test 1: Character width is positive for standard font size
test("Character width > 0 for fontSize 48") {
    let width = monospacedCharacterWidth(fontSize: 48)
    try assertTrue(width > 0, "Width should be > 0, got \(width)")
}

// Test 2: Character width is positive for visionOS default font size
test("Character width > 0 for fontSize 64 (visionOS default)") {
    let width = monospacedCharacterWidth(fontSize: 64)
    try assertTrue(width > 0, "Width should be > 0, got \(width)")
}

// Test 3: Deterministic — same input gives same output
test("Deterministic across multiple calls") {
    let width1 = monospacedCharacterWidth(fontSize: 48)
    let width2 = monospacedCharacterWidth(fontSize: 48)
    let width3 = monospacedCharacterWidth(fontSize: 48)
    try assertEqual(width1, width2)
    try assertEqual(width2, width3)
}

// Test 4: Larger font size produces larger width
test("Larger font size produces larger character width") {
    let small = monospacedCharacterWidth(fontSize: 24)
    let medium = monospacedCharacterWidth(fontSize: 48)
    let large = monospacedCharacterWidth(fontSize: 96)
    try assertTrue(small < medium, "24pt (\(small)) should be < 48pt (\(medium))")
    try assertTrue(medium < large, "48pt (\(medium)) should be < 96pt (\(large))")
}

// Test 5: Reasonable range for all sizes 24-96
test("Reasonable width range for sizes 24-96") {
    for size in stride(from: CGFloat(24), through: 96, by: 8) {
        let width = monospacedCharacterWidth(fontSize: size)
        try assertTrue(width > 0, "Width for \(size)pt should be > 0")
        // Monospace char width is roughly 0.6x font size
        let minExpected = size * 0.4
        let maxExpected = size * 0.9
        try assertTrue(width >= minExpected && width <= maxExpected,
            "Width \(width) for \(size)pt outside reasonable range [\(minExpected), \(maxExpected)]")
    }
}

// Test 6: Width scales approximately linearly with font size
test("Width scales linearly — doubling font size roughly doubles width") {
    let w24 = monospacedCharacterWidth(fontSize: 24)
    let w48 = monospacedCharacterWidth(fontSize: 48)
    let ratio = w48 / w24
    // Should be ~2.0, allow 1.8-2.2
    try assertTrue(ratio >= 1.8 && ratio <= 2.2,
        "Ratio of 48pt/24pt width should be ~2.0, got \(ratio)")
}

// Test 7: Very small font size still returns positive width
test("Very small font size (8pt) returns positive width") {
    let width = monospacedCharacterWidth(fontSize: 8)
    try assertTrue(width > 0, "Width for 8pt should be > 0, got \(width)")
}

// MARK: - Summary

print("\n=== Test Summary ===")
print("Passed: \(testsPassed)")
print("Failed: \(testsFailed)")

if testsFailed > 0 {
    exit(1)
}
