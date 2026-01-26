import Foundation

/// Key for storing the jump-to word index when navigating back from search
let SearchJumpToIndexKey = "SearchJumpToIndex"
let SearchJumpToBookIdKey = "SearchJumpToBookId"

/// View model for the Search screen.
/// Handles document loading, search execution, and result navigation.
@Observable
@MainActor
class SearchViewModel {
    // MARK: - Dependencies

    private let libraryDataService: LibraryDataService

    // MARK: - State

    let bookId: UUID
    private(set) var document: Document?
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    /// Task reference for document loading (enables cancellation)
    private var loadTask: Task<Void, Never>?

    // MARK: - Search State

    var searchText: String = ""
    private(set) var results: [SearchResult] = []
    private(set) var hasSearched: Bool = false
    private(set) var hasMoreResults: Bool = false

    var resultsCountText: String {
        if hasMoreResults {
            return "Showing first \(SearchService.maxResults) results"
        }
        return "\(results.count) result\(results.count == 1 ? "" : "s")"
    }

    // MARK: - Initialization

    init(bookId: UUID, libraryDataService: LibraryDataService = LibraryDataService()) {
        self.bookId = bookId
        self.libraryDataService = libraryDataService
    }

    // MARK: - Loading

    /// Loads the document for searching
    func loadDocument() {
        // Cancel any existing load operation
        loadTask?.cancel()
        loadTask = Task {
            await performLoadDocument()
        }
    }

    /// Internal async implementation of document loading.
    private func performLoadDocument() async {
        isLoading = true
        errorMessage = nil

        do {
            try libraryDataService.loadLibrary()

            guard let book = libraryDataService.book(for: bookId) else {
                errorMessage = "Book not found."
                isLoading = false
                return
            }

            // Load book content
            let bookFileURL = libraryDataService.bookFileURL(for: book.id, fileType: book.fileType)
            let content = try String(contentsOf: bookFileURL, encoding: .utf8)

            // Tokenize (we don't need chapters for search)
            let document = TokenizerService.tokenize(text: content, chapters: nil)
            self.document = document

            isLoading = false
        } catch {
            errorMessage = "Could not load book: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Cleanup

    /// Called when leaving the search screen
    func cleanup() {
        loadTask?.cancel()
        loadTask = nil
    }

    // MARK: - Search

    /// Executes a search with the current search text
    func performSearch() {
        hasSearched = true

        guard let doc = document else {
            results = []
            hasMoreResults = false
            return
        }

        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            hasMoreResults = false
            return
        }

        let output = SearchService.search(query: trimmed, in: doc)
        results = output.results
        hasMoreResults = output.hasMore
    }

    /// Clears the search state
    func clearSearch() {
        searchText = ""
        results = []
        hasSearched = false
        hasMoreResults = false
    }

    // MARK: - Result Selection

    /// Called when user selects a search result.
    /// Stores the jump position for the ReaderView to pick up.
    func selectResult(_ result: SearchResult) {
        // Store the position to jump to
        UserDefaults.standard.set(result.wordIndex, forKey: SearchJumpToIndexKey)
        UserDefaults.standard.set(bookId.uuidString, forKey: SearchJumpToBookIdKey)
    }

    /// Clears any stored jump position (called by ReaderView after jumping)
    static func clearJumpPosition() {
        UserDefaults.standard.removeObject(forKey: SearchJumpToIndexKey)
        UserDefaults.standard.removeObject(forKey: SearchJumpToBookIdKey)
    }

    /// Gets and clears the stored jump position for a specific book.
    /// Returns nil if no position stored or if for different book.
    static func getAndClearJumpPosition(for bookId: UUID) -> Int? {
        guard let storedBookIdString = UserDefaults.standard.string(forKey: SearchJumpToBookIdKey),
              storedBookIdString == bookId.uuidString else {
            clearJumpPosition()
            return nil
        }

        let index = UserDefaults.standard.integer(forKey: SearchJumpToIndexKey)
        // integer(forKey:) returns 0 if key doesn't exist, so check if key actually exists
        guard UserDefaults.standard.object(forKey: SearchJumpToIndexKey) != nil else {
            clearJumpPosition()
            return nil
        }

        clearJumpPosition()
        return index
    }
}
