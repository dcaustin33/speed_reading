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
    var isImmersiveSpaceOpen: Bool = false
    var immersiveSpaceError: String?

    func selectBook(_ bookId: UUID) {
        selectedBookId = bookId
        isReaderOpen = true
    }

    func closeReader() {
        isReaderOpen = false
        isImmersiveSpaceOpen = false
        selectedBookId = nil
    }

    func immersiveSpaceOpened() {
        isImmersiveSpaceOpen = true
        immersiveSpaceError = nil
    }

    func immersiveSpaceFailed(_ error: String) {
        immersiveSpaceError = error
        isImmersiveSpaceOpen = false
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

// MARK: - Immersive Space Tests

// Test 9: Initial immersive space state
test("Initial state: immersive space closed, no error") {
    let state = SpatialNavigationState()
    try assertEqual(state.isImmersiveSpaceOpen, false)
    try assertNil(state.immersiveSpaceError)
}

// Test 10: immersiveSpaceOpened sets flag and clears error
test("immersiveSpaceOpened sets isImmersiveSpaceOpen to true") {
    let state = SpatialNavigationState()
    state.immersiveSpaceOpened()
    try assertEqual(state.isImmersiveSpaceOpen, true)
    try assertNil(state.immersiveSpaceError)
}

// Test 11: immersiveSpaceFailed sets error and marks not open
test("immersiveSpaceFailed sets error and marks space not open") {
    let state = SpatialNavigationState()
    state.immersiveSpaceFailed("System error")
    try assertEqual(state.isImmersiveSpaceOpen, false)
    try assertEqual(state.immersiveSpaceError, "System error")
}

// Test 12: closeReader resets immersive space state
test("closeReader resets isImmersiveSpaceOpen") {
    let state = SpatialNavigationState()
    let bookId = UUID()
    state.selectBook(bookId)
    state.immersiveSpaceOpened()
    try assertEqual(state.isImmersiveSpaceOpen, true)

    state.closeReader()
    try assertEqual(state.isImmersiveSpaceOpen, false)
    try assertEqual(state.isReaderOpen, false)
    try assertNil(state.selectedBookId)
}

// Test 13: Error cleared on next successful open
test("Error cleared on next successful immersiveSpaceOpened") {
    let state = SpatialNavigationState()
    state.immersiveSpaceFailed("Something went wrong")
    try assertEqual(state.immersiveSpaceError, "Something went wrong")

    state.immersiveSpaceOpened()
    try assertEqual(state.isImmersiveSpaceOpen, true)
    try assertNil(state.immersiveSpaceError)
}

// Test 14: Full flow — select book, open immersive, close
test("Full flow: selectBook → immersiveSpaceOpened → closeReader") {
    let state = SpatialNavigationState()
    let bookId = UUID()

    state.selectBook(bookId)
    try assertEqual(state.isReaderOpen, true)
    try assertEqual(state.selectedBookId, bookId)

    state.immersiveSpaceOpened()
    try assertEqual(state.isImmersiveSpaceOpen, true)

    state.closeReader()
    try assertEqual(state.isReaderOpen, false)
    try assertEqual(state.isImmersiveSpaceOpen, false)
    try assertNil(state.selectedBookId)
}

// Test 15: Rapid open/close cycles maintain consistency
test("Rapid open/close cycles maintain consistent state") {
    let state = SpatialNavigationState()

    for _ in 0..<10 {
        let bookId = UUID()
        state.selectBook(bookId)
        state.immersiveSpaceOpened()
        try assertEqual(state.isReaderOpen, true)
        try assertEqual(state.isImmersiveSpaceOpen, true)

        state.closeReader()
        try assertEqual(state.isReaderOpen, false)
        try assertEqual(state.isImmersiveSpaceOpen, false)
        try assertNil(state.selectedBookId)
    }
}

// Test 16: Double open guard — calling opened twice is idempotent
test("Double immersiveSpaceOpened is idempotent") {
    let state = SpatialNavigationState()
    state.immersiveSpaceOpened()
    state.immersiveSpaceOpened()
    try assertEqual(state.isImmersiveSpaceOpen, true)
    try assertNil(state.immersiveSpaceError)
}

// Test 17: Failed then retry succeeds
test("immersiveSpaceFailed then retry with immersiveSpaceOpened succeeds") {
    let state = SpatialNavigationState()
    let bookId = UUID()

    state.selectBook(bookId)
    state.immersiveSpaceFailed("Another app has immersive space")
    try assertEqual(state.isImmersiveSpaceOpen, false)
    try assertNotNil(state.immersiveSpaceError)

    // Retry
    state.immersiveSpaceOpened()
    try assertEqual(state.isImmersiveSpaceOpen, true)
    try assertNil(state.immersiveSpaceError)
}

// Test 18: immersiveSpaceError persists until cleared
test("immersiveSpaceError persists until immersiveSpaceOpened clears it") {
    let state = SpatialNavigationState()
    state.immersiveSpaceFailed("Error A")
    try assertEqual(state.immersiveSpaceError, "Error A")

    // Failing again overwrites the error
    state.immersiveSpaceFailed("Error B")
    try assertEqual(state.immersiveSpaceError, "Error B")

    // Only opened clears it
    state.immersiveSpaceOpened()
    try assertNil(state.immersiveSpaceError)
}

// MARK: - Summary

print("\n=== Test Summary ===")
print("Passed: \(testsPassed)")
print("Failed: \(testsFailed)")

if testsFailed > 0 {
    exit(1)
}
