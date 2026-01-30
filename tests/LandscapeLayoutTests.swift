#!/usr/bin/env swift
// LandscapeLayoutTests.swift
// Tests for landscape orientation layout support.
// Verifies adaptive column calculations and compact-height padding.

import Foundation

// MARK: - Test Infrastructure

struct TestResult {
    let name: String
    let passed: Bool
    let message: String
}

var testResults: [TestResult] = []

func test(_ name: String, _ condition: Bool, _ message: String = "") {
    testResults.append(TestResult(
        name: name,
        passed: condition,
        message: condition ? "PASSED" : "FAILED: \(message)"
    ))
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ name: String) {
    test(name, a == b, "Expected \(b), got \(a)")
}

func assertTrue(_ condition: Bool, _ name: String) {
    test(name, condition, "Expected true")
}

// MARK: - Duplicated LayoutHelper Logic (standalone, no SwiftUI)

// Mirrors LayoutHelper.libraryColumnCount(for:) using Double instead of CGFloat
func libraryColumnCount(for availableWidth: Double) -> Int {
    let minimumColumnWidth: Double = 100
    let spacing: Double = 16
    let horizontalPadding: Double = 32 // 16 on each side

    let usableWidth = availableWidth - horizontalPadding
    let count = Int((usableWidth + spacing) / (minimumColumnWidth + spacing))
    return min(max(count, 2), 6)
}

// Mirrors LayoutHelper.completionOverlayTopPadding(isCompactHeight:)
func completionOverlayTopPadding(isCompactHeight: Bool) -> Double {
    isCompactHeight ? 24 : 100
}

// MARK: - Adaptive Column Count Tests

func testAdaptiveColumnCount() {
    print("\n--- Adaptive Column Count Tests ---\n")

    // Portrait iPhone (~390pt width) -> 3 columns
    let portraitColumns = libraryColumnCount(for: 390)
    assertEqual(portraitColumns, 3, "Portrait iPhone (~390pt) should have 3 columns")

    // Landscape iPhone (~844pt width) -> 5+ columns
    let landscapeColumns = libraryColumnCount(for: 844)
    assertTrue(landscapeColumns >= 5, "Landscape iPhone (~844pt) should have 5+ columns, got \(landscapeColumns)")

    // Narrow width (~320pt) -> 2 columns
    let narrowColumns = libraryColumnCount(for: 320)
    assertEqual(narrowColumns, 2, "Narrow width (~320pt) should have 2 columns")

    // Very wide width -> capped at 6
    let wideColumns = libraryColumnCount(for: 1200)
    assertEqual(wideColumns, 6, "Very wide width (1200pt) should be capped at 6 columns")

    // Minimum clamp: even very small widths get 2 columns
    let tinyColumns = libraryColumnCount(for: 100)
    assertEqual(tinyColumns, 2, "Very small width (100pt) should clamp to 2 columns")

    // Medium width (~430pt, larger iPhone portrait) -> 3 columns
    let mediumColumns = libraryColumnCount(for: 430)
    assertEqual(mediumColumns, 3, "Medium width (~430pt) should have 3 columns")

    // iPad-like width (~768pt) -> at least 5 columns
    let ipadColumns = libraryColumnCount(for: 768)
    assertTrue(ipadColumns >= 5, "iPad-like width (~768pt) should have 5+ columns, got \(ipadColumns)")
}

// MARK: - Completion Overlay Padding Tests

func testCompletionOverlayPadding() {
    print("\n--- Completion Overlay Padding Tests ---\n")

    let compactPadding = completionOverlayTopPadding(isCompactHeight: true)
    assertEqual(compactPadding, 24, "Compact height (landscape) should use 24pt padding")

    let regularPadding = completionOverlayTopPadding(isCompactHeight: false)
    assertEqual(regularPadding, 100, "Regular height (portrait) should use 100pt padding")
}

// MARK: - Column Count Monotonicity Test

func testColumnCountMonotonicity() {
    print("\n--- Column Count Monotonicity Tests ---\n")

    // As width increases, column count should never decrease
    var previousCount = 0
    let widths = stride(from: 200.0, through: 1200.0, by: 50.0)
    var isMonotonic = true
    for width in widths {
        let count = libraryColumnCount(for: width)
        if count < previousCount {
            isMonotonic = false
            test("Column count monotonic at \(width)pt", false, "Count \(count) < previous \(previousCount)")
        }
        previousCount = count
    }
    if isMonotonic {
        test("Column count is monotonically non-decreasing with width", true)
    }
}

// MARK: - Run All Tests

testAdaptiveColumnCount()
testCompletionOverlayPadding()
testColumnCountMonotonicity()

// Print results
print("\n========================================")
print("  Landscape Layout Test Results")
print("========================================\n")

var passed = 0
var failed = 0
for result in testResults {
    let icon = result.passed ? "✅" : "❌"
    print("\(icon) \(result.name): \(result.message)")
    if result.passed { passed += 1 } else { failed += 1 }
}

print("\n----------------------------------------")
print("Total: \(testResults.count) | Passed: \(passed) | Failed: \(failed)")
print("----------------------------------------\n")

if failed > 0 {
    print("⚠️  SOME TESTS FAILED")
    exit(1)
} else {
    print("🎉 ALL TESTS PASSED")
}
