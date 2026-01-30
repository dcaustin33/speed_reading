import Foundation

/// Keys for storing the jump-to word index when navigating back from TOC
let TOCJumpToIndexKey = "TOCJumpToIndex"
let TOCJumpToBookIdKey = "TOCJumpToBookId"

/// View model for the Table of Contents screen.
/// Handles chapter loading, current chapter detection, and navigation.
@Observable
@MainActor
class TOCViewModel {
    // MARK: - Dependencies

    private let libraryDataService: LibraryDataService

    // MARK: - State

    let bookId: UUID
    private(set) var chapters: [Chapter] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    /// The current word index for determining which chapter is current
    var currentWordIndex: Int = 0

    // MARK: - Computed Properties

    /// Index of the chapter containing the current word position
    var currentChapterIndex: Int? {
        findCurrentChapterIndex(wordIndex: currentWordIndex, chapters: chapters)
    }

    /// Whether the book has chapters to display
    var hasChapters: Bool {
        !chapters.isEmpty
    }

    // MARK: - Initialization

    init(bookId: UUID, currentWordIndex: Int, libraryDataService: LibraryDataService = LibraryDataService()) {
        self.bookId = bookId
        self.currentWordIndex = currentWordIndex
        self.libraryDataService = libraryDataService
    }

    // MARK: - Loading

    /// Loads chapters for the book
    func loadChapters() {
        isLoading = true
        errorMessage = nil

        do {
            try libraryDataService.loadLibrary()
            chapters = libraryDataService.loadChapters(for: bookId)
            isLoading = false
        } catch {
            errorMessage = "Could not load chapters: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Navigation

    /// Called when user selects a chapter.
    /// Stores the jump position for the ReaderView to pick up.
    func selectChapter(_ chapter: Chapter) {
        UserDefaults.standard.set(chapter.startWordIndex, forKey: TOCJumpToIndexKey)
        UserDefaults.standard.set(bookId.uuidString, forKey: TOCJumpToBookIdKey)
    }

    /// Called when user selects a chapter by index.
    func selectChapter(at index: Int) {
        guard index >= 0 && index < chapters.count else { return }
        selectChapter(chapters[index])
    }

    // MARK: - Static Methods for Jump Position

    /// Clears any stored jump position
    static func clearJumpPosition() {
        UserDefaults.standard.removeObject(forKey: TOCJumpToIndexKey)
        UserDefaults.standard.removeObject(forKey: TOCJumpToBookIdKey)
    }

    /// Gets and clears the stored jump position for a specific book.
    /// Returns nil if no position stored or if for different book.
    static func getAndClearJumpPosition(for bookId: UUID) -> Int? {
        guard let storedBookIdString = UserDefaults.standard.string(forKey: TOCJumpToBookIdKey),
              storedBookIdString == bookId.uuidString else {
            clearJumpPosition()
            return nil
        }

        // integer(forKey:) returns 0 if key doesn't exist, so check if key actually exists
        guard UserDefaults.standard.object(forKey: TOCJumpToIndexKey) != nil else {
            clearJumpPosition()
            return nil
        }

        let index = UserDefaults.standard.integer(forKey: TOCJumpToIndexKey)
        clearJumpPosition()
        return index
    }

    // MARK: - Private Helpers

    /// Finds the index of the current chapter based on word position.
    /// Returns the index of the chapter containing the given word index,
    /// or nil if no chapters exist.
    private func findCurrentChapterIndex(wordIndex: Int, chapters: [Chapter]) -> Int? {
        guard !chapters.isEmpty else { return nil }

        // Find the last chapter whose startWordIndex <= wordIndex
        var currentIndex = 0
        for (index, chapter) in chapters.enumerated() {
            if chapter.startWordIndex <= wordIndex {
                currentIndex = index
            } else {
                break
            }
        }

        return currentIndex
    }
}
