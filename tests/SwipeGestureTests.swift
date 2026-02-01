#!/usr/bin/env swift
// SwipeGestureTests.swift
// Tests for swipe gesture logic in ReaderView.
// Verifies swipe direction detection, thresholds, and gesture conflicts.

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

// MARK: - Mock Swipe Handler

/// Simulates the swipe gesture logic for testing
struct SwipeGestureHandler {
    static let minimumDistance: CGFloat = 50

    enum SwipeAction {
        case none
        case previousSentence
        case nextSentence
    }

    /// Determines swipe action based on drag gesture translation
    /// - Parameters:
    ///   - horizontalTranslation: The x-axis translation (positive = right, negative = left)
    ///   - verticalTranslation: The y-axis translation
    /// - Returns: The appropriate swipe action
    static func determineAction(horizontalTranslation: CGFloat, verticalTranslation: CGFloat) -> SwipeAction {
        // Must be primarily horizontal
        guard abs(horizontalTranslation) > abs(verticalTranslation) else {
            return .none
        }

        // Must exceed minimum distance
        guard abs(horizontalTranslation) >= minimumDistance else {
            return .none
        }

        // Swipe right = positive translation = previous sentence
        // Swipe left = negative translation = next sentence
        if horizontalTranslation > 0 {
            return .previousSentence
        } else {
            return .nextSentence
        }
    }

    /// Checks if a swipe should trigger haptic feedback
    static func shouldTriggerHaptic(action: SwipeAction) -> Bool {
        return action != .none
    }
}

// MARK: - Swipe Right Tests

func testSwipeRight() {
    print("\n--- Swipe Right (Previous Sentence) Tests ---\n")

    // Swipe right with sufficient distance
    let action1 = SwipeGestureHandler.determineAction(
        horizontalTranslation: 100,
        verticalTranslation: 10
    )
    assertEqual(action1, .previousSentence, "Swipe right (100pt) should trigger previousSentence")

    // Swipe right at exactly threshold
    let action2 = SwipeGestureHandler.determineAction(
        horizontalTranslation: 50,
        verticalTranslation: 0
    )
    assertEqual(action2, .previousSentence, "Swipe right at exactly 50pt should trigger previousSentence")

    // Large swipe right
    let action3 = SwipeGestureHandler.determineAction(
        horizontalTranslation: 200,
        verticalTranslation: 30
    )
    assertEqual(action3, .previousSentence, "Large swipe right (200pt) should trigger previousSentence")
}

// MARK: - Swipe Left Tests

func testSwipeLeft() {
    print("\n--- Swipe Left (Next Sentence) Tests ---\n")

    // Swipe left with sufficient distance
    let action1 = SwipeGestureHandler.determineAction(
        horizontalTranslation: -100,
        verticalTranslation: 10
    )
    assertEqual(action1, .nextSentence, "Swipe left (-100pt) should trigger nextSentence")

    // Swipe left at exactly threshold
    let action2 = SwipeGestureHandler.determineAction(
        horizontalTranslation: -50,
        verticalTranslation: 0
    )
    assertEqual(action2, .nextSentence, "Swipe left at exactly -50pt should trigger nextSentence")

    // Large swipe left
    let action3 = SwipeGestureHandler.determineAction(
        horizontalTranslation: -200,
        verticalTranslation: -30
    )
    assertEqual(action3, .nextSentence, "Large swipe left (-200pt) should trigger nextSentence")
}

// MARK: - Vertical Swipe Tests

func testVerticalSwipes() {
    print("\n--- Vertical Swipe (No Action) Tests ---\n")

    // Mostly vertical swipe up
    let action1 = SwipeGestureHandler.determineAction(
        horizontalTranslation: 30,
        verticalTranslation: -100
    )
    assertEqual(action1, .none, "Mostly vertical swipe (up) should not trigger navigation")

    // Mostly vertical swipe down
    let action2 = SwipeGestureHandler.determineAction(
        horizontalTranslation: -30,
        verticalTranslation: 100
    )
    assertEqual(action2, .none, "Mostly vertical swipe (down) should not trigger navigation")

    // Diagonal but more vertical
    let action3 = SwipeGestureHandler.determineAction(
        horizontalTranslation: 60,
        verticalTranslation: -80
    )
    assertEqual(action3, .none, "Diagonal swipe that's more vertical should not trigger navigation")
}

// MARK: - Threshold Tests

func testMinimumDistanceThreshold() {
    print("\n--- Minimum Distance Threshold Tests ---\n")

    // Verify threshold constant
    assertEqual(SwipeGestureHandler.minimumDistance, 50.0, "Minimum swipe distance should be 50pt")

    // Just below threshold - right
    let action1 = SwipeGestureHandler.determineAction(
        horizontalTranslation: 49,
        verticalTranslation: 0
    )
    assertEqual(action1, .none, "Swipe of 49pt (below threshold) should not trigger action")

    // Just below threshold - left
    let action2 = SwipeGestureHandler.determineAction(
        horizontalTranslation: -49,
        verticalTranslation: 0
    )
    assertEqual(action2, .none, "Swipe of -49pt (below threshold) should not trigger action")

    // Very small swipe
    let action3 = SwipeGestureHandler.determineAction(
        horizontalTranslation: 10,
        verticalTranslation: 5
    )
    assertEqual(action3, .none, "Very small swipe (10pt) should not trigger action")

    // Zero movement
    let action4 = SwipeGestureHandler.determineAction(
        horizontalTranslation: 0,
        verticalTranslation: 0
    )
    assertEqual(action4, .none, "Zero movement should not trigger action")
}

// MARK: - Tap Gesture Compatibility Tests

func testTapGestureCompatibility() {
    print("\n--- Tap Gesture Compatibility Tests ---\n")

    // Tap is essentially zero movement
    // The 50pt minimum distance ensures taps don't trigger swipe actions

    let action1 = SwipeGestureHandler.determineAction(
        horizontalTranslation: 0,
        verticalTranslation: 0
    )
    assertEqual(action1, .none, "Tap (no movement) should not trigger swipe action")

    // Small accidental movement during tap
    let action2 = SwipeGestureHandler.determineAction(
        horizontalTranslation: 5,
        verticalTranslation: 3
    )
    assertEqual(action2, .none, "Small movement during tap should not trigger swipe action")

    // Test that minimum distance of 50 distinguishes swipes from taps
    // Typical tap accidental movement is < 10pt
    assertTrue(SwipeGestureHandler.minimumDistance > 10, "Minimum distance should be large enough to distinguish from taps")
}

// MARK: - Haptic Feedback Tests

func testHapticFeedback() {
    print("\n--- Haptic Feedback Tests ---\n")

    // Successful swipe should trigger haptic
    let successfulSwipe = SwipeGestureHandler.SwipeAction.previousSentence
    assertTrue(SwipeGestureHandler.shouldTriggerHaptic(action: successfulSwipe), "Successful swipe should trigger haptic feedback")

    let successfulSwipe2 = SwipeGestureHandler.SwipeAction.nextSentence
    assertTrue(SwipeGestureHandler.shouldTriggerHaptic(action: successfulSwipe2), "Next sentence swipe should trigger haptic feedback")

    // No action should not trigger haptic
    let noAction = SwipeGestureHandler.SwipeAction.none
    assertFalse(SwipeGestureHandler.shouldTriggerHaptic(action: noAction), "No action should not trigger haptic feedback")
}

// MARK: - Edge Cases

func testEdgeCases() {
    print("\n--- Edge Cases Tests ---\n")

    // Exactly diagonal (equal horizontal and vertical)
    let action1 = SwipeGestureHandler.determineAction(
        horizontalTranslation: 60,
        verticalTranslation: 60
    )
    assertEqual(action1, .none, "Exactly diagonal swipe (equal h/v) should not trigger action")

    // Horizontal slightly dominant
    let action2 = SwipeGestureHandler.determineAction(
        horizontalTranslation: 61,
        verticalTranslation: 60
    )
    assertEqual(action2, .previousSentence, "Slightly more horizontal swipe should trigger action")

    // Negative values for both
    let action3 = SwipeGestureHandler.determineAction(
        horizontalTranslation: -100,
        verticalTranslation: -50
    )
    assertEqual(action3, .nextSentence, "Swipe left-down should trigger nextSentence (horizontal dominant)")
}

// MARK: - Run All Tests

func runAllTests() {
    print("==============================================")
    print("        Swipe Gesture Logic Tests            ")
    print("==============================================")

    testSwipeRight()
    testSwipeLeft()
    testVerticalSwipes()
    testMinimumDistanceThreshold()
    testTapGestureCompatibility()
    testHapticFeedback()
    testEdgeCases()

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
        print("\nAll swipe gesture tests passed!")
    } else {
        print("\nSome tests failed. Please review the failures above.")
        exit(1)
    }
}

// Run tests
runAllTests()
