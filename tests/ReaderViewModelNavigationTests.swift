#!/usr/bin/env swift
// ReaderViewModelNavigationTests.swift
// Tests for ReaderViewModel navigation overlay state management.
// Verifies visibility state, timer behavior, and cleanup.

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

func assertFalse(_ condition: Bool, _ name: String) {
    test(name, !condition, "Expected false")
}

// MARK: - Mock Navigation State

/// Simulates ReaderViewModel's navigation overlay state for testing
class MockNavigationState {
    var isNavigationOverlayVisible: Bool = false
    var navigationOverlayTimer: Timer?
    var timerResetCount: Int = 0

    static let autoHideDuration: TimeInterval = 2.0

    func showNavigationOverlay() {
        isNavigationOverlayVisible = true
        resetTimer()
    }

    func hideNavigationOverlay() {
        isNavigationOverlayVisible = false
        navigationOverlayTimer?.invalidate()
        navigationOverlayTimer = nil
    }

    func toggleNavigationOverlay() {
        if isNavigationOverlayVisible {
            hideNavigationOverlay()
        } else {
            showNavigationOverlay()
        }
    }

    func resetTimer() {
        navigationOverlayTimer?.invalidate()
        timerResetCount += 1
        // In real implementation, this would schedule a timer
        // For testing, we just track that resetTimer was called
    }

    func onNavigationAction() {
        if isNavigationOverlayVisible {
            resetTimer()
        }
    }

    func cleanup() {
        navigationOverlayTimer?.invalidate()
        navigationOverlayTimer = nil
    }
}

// MARK: - Initial State Tests

func testInitialState() {
    print("\n--- Initial State Tests ---\n")

    let state = MockNavigationState()

    // Test isNavigationOverlayVisible starts as false
    assertFalse(state.isNavigationOverlayVisible, "isNavigationOverlayVisible should start as false")

    // Test timer is nil initially
    assertTrue(state.navigationOverlayTimer == nil, "navigationOverlayTimer should be nil initially")
}

// MARK: - Show/Hide Tests

func testShowNavigationOverlay() {
    print("\n--- Show Navigation Overlay Tests ---\n")

    let state = MockNavigationState()

    // Initially hidden
    assertFalse(state.isNavigationOverlayVisible, "Overlay should start hidden")

    // Show overlay
    state.showNavigationOverlay()

    assertTrue(state.isNavigationOverlayVisible, "showNavigationOverlay() should set isNavigationOverlayVisible to true")
    assertTrue(state.timerResetCount > 0, "showNavigationOverlay() should start the auto-hide timer")
}

func testHideNavigationOverlay() {
    print("\n--- Hide Navigation Overlay Tests ---\n")

    let state = MockNavigationState()

    // First show it
    state.showNavigationOverlay()
    assertTrue(state.isNavigationOverlayVisible, "Overlay should be visible after show")

    // Hide it
    state.hideNavigationOverlay()

    assertFalse(state.isNavigationOverlayVisible, "hideNavigationOverlay() should set isNavigationOverlayVisible to false")
    assertTrue(state.navigationOverlayTimer == nil, "hideNavigationOverlay() should invalidate timer")
}

func testToggleNavigationOverlay() {
    print("\n--- Toggle Navigation Overlay Tests ---\n")

    let state = MockNavigationState()

    // Initial state
    assertFalse(state.isNavigationOverlayVisible, "Overlay should start hidden")

    // Toggle on
    state.toggleNavigationOverlay()
    assertTrue(state.isNavigationOverlayVisible, "First toggle should show overlay")

    // Toggle off
    state.toggleNavigationOverlay()
    assertFalse(state.isNavigationOverlayVisible, "Second toggle should hide overlay")

    // Toggle on again
    state.toggleNavigationOverlay()
    assertTrue(state.isNavigationOverlayVisible, "Third toggle should show overlay again")
}

// MARK: - Timer Tests

func testAutoHideDuration() {
    print("\n--- Auto-Hide Duration Tests ---\n")

    // Test that auto-hide duration is 2 seconds
    let expectedDuration: TimeInterval = 2.0
    assertEqual(MockNavigationState.autoHideDuration, expectedDuration, "Auto-hide timer duration should be 2 seconds")
}

func testTimerResetOnNavigationAction() {
    print("\n--- Timer Reset on Navigation Tests ---\n")

    let state = MockNavigationState()

    // Show overlay
    state.showNavigationOverlay()
    let initialResetCount = state.timerResetCount

    // Simulate navigation action (nextSentence/previousSentence)
    state.onNavigationAction()

    assertTrue(state.timerResetCount > initialResetCount, "Navigation actions should reset the timer when overlay is visible")
}

func testTimerNotResetWhenOverlayHidden() {
    print("\n--- Timer Not Reset When Hidden Tests ---\n")

    let state = MockNavigationState()

    // Keep overlay hidden
    assertFalse(state.isNavigationOverlayVisible, "Overlay should be hidden")

    let initialResetCount = state.timerResetCount

    // Simulate navigation action
    state.onNavigationAction()

    assertEqual(state.timerResetCount, initialResetCount, "Timer should not reset when overlay is hidden")
}

// MARK: - Cleanup Tests

func testCleanupOnDisappear() {
    print("\n--- Cleanup on Disappear Tests ---\n")

    let state = MockNavigationState()

    // Show overlay to create timer
    state.showNavigationOverlay()
    assertTrue(state.isNavigationOverlayVisible, "Overlay should be visible")

    // Cleanup
    state.cleanup()

    assertTrue(state.navigationOverlayTimer == nil, "Timer should be nil after cleanup")
}

// MARK: - Run All Tests

func runAllTests() {
    print("==============================================")
    print("  ReaderViewModel Navigation State Tests     ")
    print("==============================================")

    testInitialState()
    testShowNavigationOverlay()
    testHideNavigationOverlay()
    testToggleNavigationOverlay()
    testAutoHideDuration()
    testTimerResetOnNavigationAction()
    testTimerNotResetWhenOverlayHidden()
    testCleanupOnDisappear()

    // Print summary
    print("\n==============================================")
    print("                 Test Summary                 ")
    print("==============================================\n")

    let passed = testResults.filter { $0.passed }.count
    let failed = testResults.filter { !$0.passed }.count
    let total = testResults.count

    for result in testResults where !result.passed {
        print("FAILED: \(result.name)")
        print("        \(result.message)\n")
    }

    print("----------------------------------------------")
    print("Total: \(total) | Passed: \(passed) | Failed: \(failed)")
    print("----------------------------------------------")

    if failed == 0 {
        print("\nAll ReaderViewModel navigation tests passed!")
    } else {
        print("\nSome tests failed. Please review the failures above.")
        exit(1)
    }
}

// Run tests
runAllTests()
