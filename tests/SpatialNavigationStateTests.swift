#!/usr/bin/env swift

// SpatialNavigationStateTests.swift
// Tests for visionOS SpatialNavigationState state machine

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

func assertNil<T>(_ value: T?, _ message: String = "", line: Int = #line) throws {
    guard value == nil else {
        throw TestError.assertionFailed("Expected nil, got \(value!) \(message) at line \(line)")
    }
}

func assertNotNil<T>(_ value: T?, _ message: String = "", line: Int = #line) throws {
    guard value != nil else {
        throw TestError.assertionFailed("Expected non-nil \(message) at line \(line)")
    }
}

enum TestError: Error {
    case assertionFailed(String)
}

// MARK: - SpatialNavigationState (mirrors Features/VisionOS/SpatialNavigationState.swift)

final class SpatialNavigationState {
    var selectedBookId: UUID?
    var isReaderOpen: Bool = false

    func selectBook(_ bookId: UUID) {
        selectedBookId = bookId
        isReaderOpen = true
    }

    func closeReader() {
        isReaderOpen = false
        selectedBookId = nil
    }
}

// MARK: - Tests

print("=== SpatialNavigationState Tests ===\n")

// Test 1: Initial state
test("Initial state: no book selected, reader closed") {
    let state = SpatialNavigationState()
    try assertNil(state.selectedBookId, "selectedBookId should be nil initially")
    try assertEqual(state.isReaderOpen, false)
}

// Test 2: selectBook sets both properties
test("selectBook sets selectedBookId and opens reader") {
    let state = SpatialNavigationState()
    let bookId = UUID()
    state.selectBook(bookId)
    try assertEqual(state.selectedBookId, bookId)
    try assertEqual(state.isReaderOpen, true)
}

// Test 3: closeReader clears both properties
test("closeReader clears selectedBookId and closes reader") {
    let state = SpatialNavigationState()
    let bookId = UUID()
    state.selectBook(bookId)
    state.closeReader()
    try assertNil(state.selectedBookId, "selectedBookId should be nil after close")
    try assertEqual(state.isReaderOpen, false)
}

// Test 4: Double select replaces book ID
test("Selecting a second book replaces the first") {
    let state = SpatialNavigationState()
    let book1 = UUID()
    let book2 = UUID()
    state.selectBook(book1)
    state.selectBook(book2)
    try assertEqual(state.selectedBookId, book2)
    try assertEqual(state.isReaderOpen, true)
}

// Test 5: Close when already closed is safe
test("closeReader when already closed is a no-op") {
    let state = SpatialNavigationState()
    state.closeReader()
    try assertNil(state.selectedBookId)
    try assertEqual(state.isReaderOpen, false)
}

// Test 6: Select → close → select cycle
test("Select, close, select again works correctly") {
    let state = SpatialNavigationState()
    let book1 = UUID()
    let book2 = UUID()

    state.selectBook(book1)
    try assertEqual(state.selectedBookId, book1)
    try assertEqual(state.isReaderOpen, true)

    state.closeReader()
    try assertNil(state.selectedBookId)
    try assertEqual(state.isReaderOpen, false)

    state.selectBook(book2)
    try assertEqual(state.selectedBookId, book2)
    try assertEqual(state.isReaderOpen, true)
}

// Test 7: Multiple close calls are safe
test("Multiple closeReader calls are safe") {
    let state = SpatialNavigationState()
    let bookId = UUID()
    state.selectBook(bookId)
    state.closeReader()
    state.closeReader()
    state.closeReader()
    try assertNil(state.selectedBookId)
    try assertEqual(state.isReaderOpen, false)
}

// Test 8: selectedBookId preserved until close
test("selectedBookId preserved across multiple isReaderOpen checks") {
    let state = SpatialNavigationState()
    let bookId = UUID()
    state.selectBook(bookId)
    // Simulate multiple reads without close
    for _ in 0..<5 {
        try assertEqual(state.selectedBookId, bookId)
        try assertEqual(state.isReaderOpen, true)
    }
}

// MARK: - Summary

print("\n=== Test Summary ===")
print("Passed: \(testsPassed)")
print("Failed: \(testsFailed)")

if testsFailed > 0 {
    exit(1)
}
