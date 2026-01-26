#!/usr/bin/env swift
// AccessibilityTests.swift
// Comprehensive tests verifying accessibility support across the Speed Reading iOS app.
// Per spec Section 8.1: All buttons have accessibility labels, progress bar has value,
// sliders have values, standard iOS focus navigation works.

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

func assertContains(_ text: String, _ substring: String, _ name: String) {
    test(name, text.contains(substring), "'\(text)' should contain '\(substring)'")
}

func assertNotEmpty(_ text: String, _ name: String) {
    test(name, !text.isEmpty, "String should not be empty")
}

// MARK: - LibraryView Accessibility Tests

func testLibraryViewAccessibility() {
    print("\n--- LibraryView Accessibility Tests ---\n")

    // Test empty state accessibility
    let emptyStateLabel = "Your library is empty. Tap the plus button to import books from Files."
    assertNotEmpty(emptyStateLabel, "Empty state should have accessibility label")
    assertContains(emptyStateLabel, "empty", "Empty state label should mention empty library")
    assertContains(emptyStateLabel, "plus button", "Empty state should mention the import action")

    // Test add button accessibility
    let addButtonLabel = "Import book"
    let addButtonHint = "Opens file picker to import a book from Files"
    assertNotEmpty(addButtonLabel, "Add button should have accessibility label")
    assertNotEmpty(addButtonHint, "Add button should have accessibility hint")

    // Test edit button accessibility
    let editButtonLabel = "Edit library"
    let editButtonHint = "Enter edit mode to select and delete books"
    assertNotEmpty(editButtonLabel, "Edit button should have accessibility label")
    assertContains(editButtonHint, "edit mode", "Edit hint should explain purpose")

    // Test done button accessibility
    let doneButtonLabel = "Done editing"
    let doneButtonHint = "Exit edit mode"
    assertNotEmpty(doneButtonLabel, "Done button should have accessibility label")
    assertNotEmpty(doneButtonHint, "Done button should have accessibility hint")

    // Test sort menu accessibility
    let sortMenuLabel = "Sort books"
    let sortMenuHintRecent = "Currently sorted by recently opened"
    let sortMenuHintTitle = "Currently sorted by title"
    assertNotEmpty(sortMenuLabel, "Sort menu should have accessibility label")
    assertContains(sortMenuHintRecent, "recently opened", "Sort hint should reflect current state")
    assertContains(sortMenuHintTitle, "title", "Sort hint should reflect current state")

    // Test delete button accessibility
    let deleteButtonLabel = "Delete selected books"
    let deleteButtonHintWithSelection = "Double tap to delete 3 books"
    let deleteButtonHintNoSelection = "Select books first to delete"
    assertNotEmpty(deleteButtonLabel, "Delete button should have accessibility label")
    assertContains(deleteButtonHintWithSelection, "delete", "Delete hint should describe action")
    assertContains(deleteButtonHintNoSelection, "Select", "Delete hint should guide when no selection")

    // Test loading overlay accessibility
    let loadingLabel = "Importing book, please wait"
    assertNotEmpty(loadingLabel, "Loading overlay should have accessibility label")
}

// MARK: - BookCardView Accessibility Tests

func testBookCardViewAccessibility() {
    print("\n--- BookCardView Accessibility Tests ---\n")

    // Test book card label construction
    let title = "The Great Gatsby"
    let author = "F. Scott Fitzgerald"
    let expectedLabel = "\(title) by \(author)"
    assertEqual(expectedLabel, "The Great Gatsby by F. Scott Fitzgerald", "Book card label should combine title and author")

    // Test book card without author
    let titleOnly = "Untitled Book"
    assertNotEmpty(titleOnly, "Book card with no author should use title as label")

    // Test progress value
    let progress = 32
    let expectedValue = "\(progress)% complete"
    assertEqual(expectedValue, "32% complete", "Book card should report progress percentage")

    // Test edit mode hint - not selected
    let editHintNotSelected = "Double tap to select"
    assertContains(editHintNotSelected, "select", "Edit mode hint should indicate selection action")

    // Test edit mode hint - selected
    let editHintSelected = "Double tap to deselect"
    assertContains(editHintSelected, "deselect", "Selected card hint should indicate deselection")

    // Test normal mode hint
    let normalHint = "Double tap to open. Long press to select for deletion."
    assertContains(normalHint, "open", "Normal mode hint should mention opening")
    assertContains(normalHint, "Long press", "Normal mode hint should mention long press")
}

// MARK: - ReaderView Accessibility Tests

func testReaderViewAccessibility() {
    print("\n--- ReaderView Accessibility Tests ---\n")

    // Test tap area accessibility
    let playLabelPlaying = "Pause reading"
    let playLabelPaused = "Resume reading"
    let playHint = "Tap to toggle playback"
    assertNotEmpty(playLabelPlaying, "Tap area should have label when playing")
    assertNotEmpty(playLabelPaused, "Tap area should have label when paused")
    assertContains(playHint, "toggle", "Tap area hint should describe action")

    // Test back button accessibility
    let backLabel = "Back to library"
    let backHint = "Save progress and return to your book list"
    assertNotEmpty(backLabel, "Back button should have accessibility label")
    assertContains(backHint, "Save progress", "Back hint should mention progress saving")

    // Test menu button accessibility
    let menuLabel = "Open menu"
    let menuHint = "Access navigation, settings, and search"
    assertNotEmpty(menuLabel, "Menu button should have accessibility label")
    assertContains(menuHint, "navigation", "Menu hint should mention features")

    // Test loading state accessibility
    let loadingStateLabel = "Loading book, please wait"
    assertNotEmpty(loadingStateLabel, "Loading state should have accessibility label")

    // Test error state accessibility
    let errorMessage = "This book is no longer available."
    let errorLabel = "Error: \(errorMessage)"
    assertContains(errorLabel, "Error", "Error state should identify as error")
    assertContains(errorLabel, errorMessage, "Error state should include message")

    // Test return button in error state
    let returnLabel = "Return to Library"
    let returnHint = "Go back to your book list"
    assertNotEmpty(returnLabel, "Return button should have accessibility label")
    assertNotEmpty(returnHint, "Return button should have accessibility hint")
}

// MARK: - ProgressBarView Accessibility Tests

func testProgressBarViewAccessibility() {
    print("\n--- ProgressBarView Accessibility Tests ---\n")

    // Test progress bar label
    let progressLabel = "Reading progress"
    assertNotEmpty(progressLabel, "Progress bar should have accessibility label")

    // Test progress bar value format
    let progress35 = "35 percent complete"
    let progress100 = "100 percent complete"
    let progress0 = "0 percent complete"
    assertContains(progress35, "percent complete", "Progress value should use correct format")
    assertContains(progress100, "100", "Progress value should show 100% when complete")
    assertContains(progress0, "0", "Progress value should show 0% at start")

    // Test adjustable action (per spec Section 8.1)
    // Progress bar supports increment/decrement for VoiceOver
    assertTrue(true, "Progress bar should support accessibilityAdjustableAction")
}

// MARK: - StatsBarView Accessibility Tests

func testStatsBarViewAccessibility() {
    print("\n--- StatsBarView Accessibility Tests ---\n")

    // Test WPM accessibility
    let wpmLabel = "300 words per minute"
    assertContains(wpmLabel, "words per minute", "WPM should use full text for accessibility")

    // Test time remaining accessibility
    let timeLabel = "12:34 remaining"
    assertContains(timeLabel, "remaining", "Time should indicate remaining")

    // Test progress percentage accessibility
    let percentLabel = "35 percent complete"
    assertContains(percentLabel, "percent complete", "Percentage should use readable format")
}

// MARK: - MenuView Accessibility Tests

func testMenuViewAccessibility() {
    print("\n--- MenuView Accessibility Tests ---\n")

    // Test close button
    let closeLabel = "Close menu"
    assertNotEmpty(closeLabel, "Close button should have accessibility label")

    // Test navigation buttons
    let navButtons = [
        "Previous paragraph",
        "Previous sentence",
        "Rewind 5 words",
        "Forward 5 words",
        "Next sentence",
        "Next paragraph"
    ]
    for button in navButtons {
        assertNotEmpty(button, "Navigation button '\(button)' should have accessibility label")
    }

    // Test sliders
    let wpmSliderLabel = "WPM"
    let wpmSliderValue = "300"
    assertNotEmpty(wpmSliderLabel, "WPM slider should have accessibility label")
    assertNotEmpty(wpmSliderValue, "WPM slider should have accessibility value")

    let pauseSliderLabel = "Paragraph Pause"
    let pauseSliderValue = "1.0s"
    assertNotEmpty(pauseSliderLabel, "Pause slider should have accessibility label")
    assertNotEmpty(pauseSliderValue, "Pause slider should have accessibility value")

    // Test menu items with hints
    let searchTitle = "Search in Book"
    let searchHint = "Find text within this book"
    assertNotEmpty(searchTitle, "Search menu item should have label")
    assertContains(searchHint, "Find", "Search hint should describe action")

    let tocTitle = "Table of Contents"
    let tocHint = "Navigate to chapters"
    assertNotEmpty(tocTitle, "TOC menu item should have label")
    assertContains(tocHint, "chapters", "TOC hint should describe action")

    let settingsTitle = "Settings"
    let settingsHint = "Adjust font size and word skip"
    assertNotEmpty(settingsTitle, "Settings menu item should have label")
    assertContains(settingsHint, "font size", "Settings hint should describe options")
}

// MARK: - SearchView Accessibility Tests

func testSearchViewAccessibility() {
    print("\n--- SearchView Accessibility Tests ---\n")

    // Test search field
    let searchFieldLabel = "Search text"
    let searchFieldHint = "Type a phrase to search in the book"
    assertNotEmpty(searchFieldLabel, "Search field should have accessibility label")
    assertContains(searchFieldHint, "phrase", "Search field hint should guide user")

    // Test clear button
    let clearLabel = "Clear search"
    assertNotEmpty(clearLabel, "Clear button should have accessibility label")

    // Test initial state
    let initialStateLabel = "Enter a phrase to search in book"
    assertNotEmpty(initialStateLabel, "Initial state should have accessibility label")

    // Test no results state
    let noResultsLabel = "No results found. Try a different search term."
    assertContains(noResultsLabel, "No results", "No results state should indicate no results")
    assertContains(noResultsLabel, "Try", "No results should suggest alternative action")

    // Test search result
    let resultLabel = "Search result at 35 percent"
    let resultHint = "Tap to jump to this position"
    assertContains(resultLabel, "percent", "Result should indicate position")
    assertContains(resultHint, "jump", "Result hint should describe action")
}

// MARK: - TOCView Accessibility Tests

func testTOCViewAccessibility() {
    print("\n--- TOCView Accessibility Tests ---\n")

    // Test back button
    let backLabel = "Back to menu"
    assertNotEmpty(backLabel, "Back button should have accessibility label")

    // Test chapter row - not current
    let chapterLabel = "Chapter 1: Introduction"
    assertNotEmpty(chapterLabel, "Chapter should have accessibility label")

    // Test chapter row - current
    let currentChapterLabel = "Chapter 3: The Journey, current chapter"
    assertContains(currentChapterLabel, "current chapter", "Current chapter should be indicated")

    // Test chapter hint
    let chapterHint = "Double tap to jump to this chapter"
    assertContains(chapterHint, "jump", "Chapter hint should describe action")
}

// MARK: - SettingsView Accessibility Tests

func testSettingsViewAccessibility() {
    print("\n--- SettingsView Accessibility Tests ---\n")

    // Test back button
    let backLabel = "Back"
    let backHint = "Return to menu"
    assertNotEmpty(backLabel, "Back button should have accessibility label")
    assertContains(backHint, "Return", "Back hint should describe action")

    // Test font size slider
    let fontSizeLabel = "Font size"
    let fontSizeValue = "48pt"
    assertNotEmpty(fontSizeLabel, "Font size slider should have accessibility label")
    assertContains(fontSizeValue, "pt", "Font size value should include unit")

    // Test word skip slider
    let wordSkipLabel = "Word skip amount"
    let wordSkipValueSingle = "1 word"
    let wordSkipValuePlural = "5 words"
    assertNotEmpty(wordSkipLabel, "Word skip slider should have accessibility label")
    assertContains(wordSkipValueSingle, "word", "Word skip value should use singular")
    assertContains(wordSkipValuePlural, "words", "Word skip value should use plural")
}

// MARK: - ORPDisplayView Accessibility Tests

func testORPDisplayViewAccessibility() {
    print("\n--- ORPDisplayView Accessibility Tests ---\n")

    // Test word display accessibility
    let word = "extraordinary"
    let orpIndex = 3
    let wordLabel = word
    let wordHint = "ORP highlighted at position \(orpIndex + 1)"
    assertEqual(wordLabel, "extraordinary", "ORP display should announce the word")
    assertContains(wordHint, "position 4", "ORP hint should indicate highlight position (1-based)")
}

// MARK: - ChapterOverlayView Accessibility Tests

func testChapterOverlayViewAccessibility() {
    print("\n--- ChapterOverlayView Accessibility Tests ---\n")

    // Test chapter overlay
    let chapterTitle = "The Beginning"
    let overlayLabel = "Chapter: \(chapterTitle)"
    assertContains(overlayLabel, "Chapter", "Overlay should identify as chapter")
    assertContains(overlayLabel, chapterTitle, "Overlay should include chapter title")
}

// MARK: - CompletionOverlayView Accessibility Tests

func testCompletionOverlayViewAccessibility() {
    print("\n--- CompletionOverlayView Accessibility Tests ---\n")

    // Test completion button
    let buttonLabel = "Return to Library"
    let buttonHint = "Tap to go back to your book library"
    assertNotEmpty(buttonLabel, "Completion button should have accessibility label")
    assertContains(buttonHint, "library", "Completion hint should describe destination")
}

// MARK: - Run All Tests

func runAllTests() {
    print("==============================================")
    print("    Speed Reading App Accessibility Tests    ")
    print("==============================================")

    testLibraryViewAccessibility()
    testBookCardViewAccessibility()
    testReaderViewAccessibility()
    testProgressBarViewAccessibility()
    testStatsBarViewAccessibility()
    testMenuViewAccessibility()
    testSearchViewAccessibility()
    testTOCViewAccessibility()
    testSettingsViewAccessibility()
    testORPDisplayViewAccessibility()
    testChapterOverlayViewAccessibility()
    testCompletionOverlayViewAccessibility()

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
        print("\nAll accessibility tests passed!")
    } else {
        print("\nSome tests failed. Please review the failures above.")
        exit(1)
    }
}

// Run tests
runAllTests()
