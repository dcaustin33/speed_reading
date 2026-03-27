#!/usr/bin/env swift

// SpatialBookEntityTests.swift
// Tests for SpatialBookEntity deterministic fallback color logic
// RealityKit entity creation is verified via visionOS simulator build

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

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, line: Int = #line) throws {
    guard actual == expected else {
        throw TestError.assertionFailed("Expected \(expected), got \(actual) at line \(line)")
    }
}

func assertTrue(_ condition: Bool, _ message: String = "", line: Int = #line) throws {
    guard condition else {
        throw TestError.assertionFailed("Assertion failed: \(message) at line \(line)")
    }
}

enum TestError: Error {
    case assertionFailed(String)
}

// MARK: - Mirrored Logic from SpatialBookEntity

/// Fixed color palette for fallback book covers (RGB tuples)
let fallbackColorPalette: [(r: Float, g: Float, b: Float)] = [
    (0.26, 0.52, 0.96),  // Blue
    (0.85, 0.26, 0.22),  // Red
    (0.20, 0.66, 0.33),  // Green
    (0.61, 0.35, 0.71),  // Purple
    (0.95, 0.61, 0.07),  // Orange
    (0.00, 0.59, 0.53),  // Teal
    (0.83, 0.18, 0.55),  // Pink
    (0.40, 0.31, 0.64),  // Indigo
]

/// Deterministic color index from a book title string
func fallbackColorIndex(for title: String) -> Int {
    var hash: UInt64 = 5381
    for char in title.utf8 {
        hash = ((hash &<< 5) &+ hash) &+ UInt64(char)  // djb2
    }
    return Int(hash % UInt64(fallbackColorPalette.count))
}

// MARK: - Tests

print("=== SpatialBookEntity Tests ===\n")

// Test 1: Same title always produces the same color index
test("Deterministic: same title → same color index") {
    let title = "The Great Gatsby"
    let index1 = fallbackColorIndex(for: title)
    let index2 = fallbackColorIndex(for: title)
    let index3 = fallbackColorIndex(for: title)
    try assertEqual(index1, index2)
    try assertEqual(index2, index3)
}

// Test 2: Different titles can produce different color indices
test("Different titles produce different indices (statistical)") {
    let titles = [
        "War and Peace",
        "1984",
        "Moby Dick",
        "Pride and Prejudice",
        "The Odyssey",
        "Dune",
        "Neuromancer",
        "Snow Crash",
        "Foundation",
        "Brave New World",
    ]
    let indices = Set(titles.map { fallbackColorIndex(for: $0) })
    // With 10 titles and 8 colors, we should get at least 3 distinct indices
    try assertTrue(indices.count >= 3, "Expected at least 3 distinct colors from 10 titles, got \(indices.count)")
}

// Test 3: Color index is always within palette bounds
test("Color index always within palette bounds") {
    let titles = [
        "", "A", "Short", "A Very Long Book Title That Goes On And On",
        "特殊文字", "🎉📚", "123456789",
    ]
    for title in titles {
        let index = fallbackColorIndex(for: title)
        try assertTrue(index >= 0 && index < fallbackColorPalette.count,
                      "Index \(index) out of bounds for title '\(title)'")
    }
}

// Test 4: Empty title produces a valid index
test("Empty title produces valid color index") {
    let index = fallbackColorIndex(for: "")
    try assertTrue(index >= 0 && index < fallbackColorPalette.count,
                  "Index \(index) out of bounds for empty title")
}

// Test 5: Palette has expected count
test("Fallback color palette has 8 colors") {
    try assertEqual(fallbackColorPalette.count, 8)
}

// Test 6: All palette colors have valid RGB values (0.0-1.0)
test("All palette colors have valid RGB values") {
    for (i, color) in fallbackColorPalette.enumerated() {
        try assertTrue(color.r >= 0 && color.r <= 1, "Color \(i) red out of range: \(color.r)")
        try assertTrue(color.g >= 0 && color.g <= 1, "Color \(i) green out of range: \(color.g)")
        try assertTrue(color.b >= 0 && color.b <= 1, "Color \(i) blue out of range: \(color.b)")
    }
}

// Test 7: Similar titles produce different indices (not trivially sequential)
test("Similar titles with minor differences produce varied indices") {
    let base = "Book Title"
    let variants = (1...20).map { "\(base) \($0)" }
    let indices = Set(variants.map { fallbackColorIndex(for: $0) })
    // 20 variants across 8 colors — should use at least 4
    try assertTrue(indices.count >= 4, "Expected at least 4 distinct colors from 20 similar titles, got \(indices.count)")
}

// MARK: - Summary

print("\n=== Test Summary ===")
print("Passed: \(testsPassed)")
print("Failed: \(testsFailed)")

if testsFailed > 0 {
    exit(1)
}
