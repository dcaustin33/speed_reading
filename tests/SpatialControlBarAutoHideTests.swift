#!/usr/bin/env swift

// SpatialControlBarAutoHideTests.swift
// Tests for the auto-hide state machine used by SpatialControlBar
// The actual control bar uses SwiftUI Task-based timers; this tests
// the synchronous state transition logic extracted from the view.

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

func assertFalse(_ condition: Bool, _ message: String = "", line: Int = #line) throws {
    guard !condition else {
        throw TestError.assertionFailed("Expected false: \(message) at line \(line)")
    }
}

enum TestError: Error {
    case assertionFailed(String)
}

// MARK: - Auto-Hide State Machine (mirrors SpatialControlBar logic)

/// Extracts the auto-hide state machine from SpatialControlBar into a testable model.
/// In the real view:
///   - `startHideTimer()` → cancels existing task, starts new 3s Task that sets ornamentVisible = false
///   - `cancelHideTimer()` → cancels task, sets task = nil
///   - `handleInteraction()` → sets visible = true, starts timer if playing
///   - onChange(isPlaying): play → startHideTimer, pause → cancelHideTimer + show
///   - onChange(isCompleted): completed → cancelHideTimer + show
///   - onChange(isScrubbing): start → cancelHideTimer, end → startHideTimer if playing
final class AutoHideStateMachine {
    var ornamentVisible: Bool = true
    var timerRunning: Bool = false

    // External state (simulates viewModel properties)
    var isPlaying: Bool = false
    var isCompleted: Bool = false
    var isScrubbing: Bool = false

    /// Simulates the timer firing (3s elapsed)
    func timerFired() {
        guard timerRunning else { return }
        timerRunning = false
        ornamentVisible = false
    }

    /// Mirrors SpatialControlBar.startHideTimer()
    func startHideTimer() {
        timerRunning = true
    }

    /// Mirrors SpatialControlBar.cancelHideTimer()
    func cancelHideTimer() {
        timerRunning = false
    }

    /// Mirrors SpatialControlBar.handleInteraction()
    func handleInteraction() {
        ornamentVisible = true
        if isPlaying {
            startHideTimer()
        }
    }

    /// Mirrors .onChange(of: isPlaying)
    func playbackStateChanged(isPlaying newValue: Bool) {
        isPlaying = newValue
        if newValue {
            startHideTimer()
        } else {
            cancelHideTimer()
            ornamentVisible = true
        }
    }

    /// Mirrors .onChange(of: isCompleted)
    func completionStateChanged(isCompleted newValue: Bool) {
        isCompleted = newValue
        if newValue {
            cancelHideTimer()
            ornamentVisible = true
        }
    }

    /// Mirrors .onChange(of: isScrubbing)
    func scrubbingStateChanged(isScrubbing newValue: Bool) {
        isScrubbing = newValue
        if newValue {
            cancelHideTimer()
        } else if isPlaying {
            startHideTimer()
        }
    }
}

// MARK: - Tests

print("=== SpatialControlBar Auto-Hide Tests ===\n")

// Test 1: Initial state — visible, no timer
test("Initial state: ornament visible, timer not running") {
    let sm = AutoHideStateMachine()
    try assertTrue(sm.ornamentVisible, "ornament should be visible initially")
    try assertFalse(sm.timerRunning, "timer should not be running initially")
}

// Test 2: Play starts timer
test("Play starts hide timer") {
    let sm = AutoHideStateMachine()
    sm.playbackStateChanged(isPlaying: true)
    try assertTrue(sm.timerRunning, "timer should start on play")
    try assertTrue(sm.ornamentVisible, "ornament should still be visible before timer fires")
}

// Test 3: Timer firing hides ornament
test("Timer firing hides ornament") {
    let sm = AutoHideStateMachine()
    sm.playbackStateChanged(isPlaying: true)
    sm.timerFired()
    try assertFalse(sm.ornamentVisible, "ornament should be hidden after timer fires")
    try assertFalse(sm.timerRunning, "timer should stop after firing")
}

// Test 4: Pause cancels timer and shows ornament
test("Pause cancels timer and shows ornament") {
    let sm = AutoHideStateMachine()
    sm.playbackStateChanged(isPlaying: true)
    sm.timerFired()
    try assertFalse(sm.ornamentVisible, "should be hidden after timer")

    sm.playbackStateChanged(isPlaying: false)
    try assertTrue(sm.ornamentVisible, "ornament should show on pause")
    try assertFalse(sm.timerRunning, "timer should be cancelled on pause")
}

// Test 5: Interaction shows ornament and restarts timer when playing
test("Interaction shows ornament and restarts timer when playing") {
    let sm = AutoHideStateMachine()
    sm.playbackStateChanged(isPlaying: true)
    sm.timerFired()
    try assertFalse(sm.ornamentVisible, "should be hidden after timer")

    sm.handleInteraction()
    try assertTrue(sm.ornamentVisible, "ornament should show on interaction")
    try assertTrue(sm.timerRunning, "timer should restart on interaction while playing")
}

// Test 6: Interaction when paused shows but does NOT start timer
test("Interaction when paused shows ornament but no timer") {
    let sm = AutoHideStateMachine()
    sm.playbackStateChanged(isPlaying: false)
    sm.ornamentVisible = false // Force hidden for test

    sm.handleInteraction()
    try assertTrue(sm.ornamentVisible, "ornament should show on interaction")
    try assertFalse(sm.timerRunning, "timer should NOT start when paused")
}

// Test 7: Completion cancels timer and shows ornament
test("Completion cancels timer and shows ornament") {
    let sm = AutoHideStateMachine()
    sm.playbackStateChanged(isPlaying: true)
    sm.timerFired()
    try assertFalse(sm.ornamentVisible, "should be hidden after timer")

    sm.completionStateChanged(isCompleted: true)
    try assertTrue(sm.ornamentVisible, "ornament should show on completion")
    try assertFalse(sm.timerRunning, "timer should be cancelled on completion")
}

// Test 8: Completion cancels a running timer (before it fires)
test("Completion cancels running timer before it fires") {
    let sm = AutoHideStateMachine()
    sm.playbackStateChanged(isPlaying: true)
    try assertTrue(sm.timerRunning, "timer should be running")

    sm.completionStateChanged(isCompleted: true)
    try assertFalse(sm.timerRunning, "timer should be cancelled by completion")
    try assertTrue(sm.ornamentVisible, "ornament should remain visible")
}

// Test 9: Scrub start cancels timer
test("Scrub start cancels hide timer") {
    let sm = AutoHideStateMachine()
    sm.playbackStateChanged(isPlaying: true)
    try assertTrue(sm.timerRunning, "timer should be running during play")

    sm.scrubbingStateChanged(isScrubbing: true)
    try assertFalse(sm.timerRunning, "timer should be cancelled during scrub")
}

// Test 10: Scrub end restarts timer if playing
test("Scrub end restarts timer if playing") {
    let sm = AutoHideStateMachine()
    sm.playbackStateChanged(isPlaying: true)
    sm.scrubbingStateChanged(isScrubbing: true)
    try assertFalse(sm.timerRunning, "timer paused during scrub")

    sm.scrubbingStateChanged(isScrubbing: false)
    try assertTrue(sm.timerRunning, "timer should restart after scrub while playing")
}

// Test 11: Scrub end does NOT restart timer if paused
test("Scrub end does not restart timer if paused") {
    let sm = AutoHideStateMachine()
    sm.playbackStateChanged(isPlaying: false)
    sm.scrubbingStateChanged(isScrubbing: true)
    sm.scrubbingStateChanged(isScrubbing: false)
    try assertFalse(sm.timerRunning, "timer should NOT restart after scrub when paused")
}

// Test 12: Timer does not fire if already cancelled
test("Timer does not hide if cancelled before firing") {
    let sm = AutoHideStateMachine()
    sm.playbackStateChanged(isPlaying: true)
    sm.cancelHideTimer()
    sm.timerFired()
    try assertTrue(sm.ornamentVisible, "ornament should remain visible when timer was cancelled")
}

// Test 13: Multiple interactions only one timer running
test("Multiple rapid interactions keep ornament visible") {
    let sm = AutoHideStateMachine()
    sm.playbackStateChanged(isPlaying: true)

    // Simulate rapid interactions
    for _ in 0..<5 {
        sm.handleInteraction()
        try assertTrue(sm.ornamentVisible, "ornament should stay visible during interactions")
        try assertTrue(sm.timerRunning, "timer should be (re)started")
    }

    // After last timer fires, should hide
    sm.timerFired()
    try assertFalse(sm.ornamentVisible, "ornament should hide after final timer fires")
}

// Test 14: Full cycle — play, hide, interact, hide, pause, show
test("Full cycle: play → hide → interact → hide → pause → show") {
    let sm = AutoHideStateMachine()

    // Play: timer starts
    sm.playbackStateChanged(isPlaying: true)
    try assertTrue(sm.ornamentVisible)
    try assertTrue(sm.timerRunning)

    // Timer fires: hides
    sm.timerFired()
    try assertFalse(sm.ornamentVisible)

    // Interaction: shows + restarts timer
    sm.handleInteraction()
    try assertTrue(sm.ornamentVisible)
    try assertTrue(sm.timerRunning)

    // Timer fires again: hides
    sm.timerFired()
    try assertFalse(sm.ornamentVisible)

    // Pause: shows + cancels timer
    sm.playbackStateChanged(isPlaying: false)
    try assertTrue(sm.ornamentVisible)
    try assertFalse(sm.timerRunning)
}

// Test 15: Play → scrub → end scrub → timer fires → hides
test("Play → scrub → end scrub → timer fires → hides") {
    let sm = AutoHideStateMachine()

    sm.playbackStateChanged(isPlaying: true)
    sm.scrubbingStateChanged(isScrubbing: true)
    try assertFalse(sm.timerRunning, "timer cancelled during scrub")
    try assertTrue(sm.ornamentVisible, "visible during scrub")

    sm.scrubbingStateChanged(isScrubbing: false)
    try assertTrue(sm.timerRunning, "timer restarted after scrub")

    sm.timerFired()
    try assertFalse(sm.ornamentVisible, "hidden after timer fires post-scrub")
}

// MARK: - Summary

print("\n=== Test Summary ===")
print("Passed: \(testsPassed)")
print("Failed: \(testsFailed)")

if testsFailed > 0 {
    exit(1)
}
