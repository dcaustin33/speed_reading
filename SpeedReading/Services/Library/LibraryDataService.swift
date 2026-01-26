import Foundation
import CryptoKit

/// Service for managing the library: importing books, detecting duplicates, deletion, and sorting.
/// This is the main data management layer that coordinates between file import services and storage.
final class LibraryDataService {
    // MARK: - Properties

    private var library: Library
    private let storageURL: URL
    private let booksDirectory: URL
    private let coversDirectory: URL
    private let chaptersDirectory: URL
    private let fileManager = FileManager.default

    // MARK: - Initialization

    /// Create a LibraryDataService with a custom storage directory (mainly for testing)
    init(storageURL: URL) {
        self.storageURL = storageURL
        self.booksDirectory = storageURL.appendingPathComponent("Books")
        self.coversDirectory = storageURL.appendingPathComponent("Covers")
        self.chaptersDirectory = storageURL.appendingPathComponent("Chapters")
        self.library = Library()

        // Create directories if needed
        try? fileManager.createDirectory(at: booksDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: coversDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: chaptersDirectory, withIntermediateDirectories: true)
    }

    /// Create a LibraryDataService using the app's Documents directory
    convenience init() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.init(storageURL: documentsURL)
    }

    // MARK: - Library Persistence

    private var libraryFileURL: URL {
        storageURL.appendingPathComponent("library.json")
    }

    /// Load the library from disk
    func loadLibrary() throws {
        guard fileManager.fileExists(atPath: libraryFileURL.path) else {
            library = Library()
            return
        }
        let data = try Data(contentsOf: libraryFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        library = try decoder.decode(Library.self, from: data)
    }

    /// Save the library to disk
    func saveLibrary() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(library)
        try data.write(to: libraryFileURL, options: .atomic)
    }

    // MARK: - Accessors

    /// All books in the library
    var books: [Book] { library.books }

    /// Global app settings
    var settings: Settings {
        get { library.settings }
        set { library.settings = newValue }
    }

    /// Get a book by its ID
    func book(byId id: UUID) -> Book? {
        library.books.first { $0.id == id }
    }

    // MARK: - Duplicate Detection

    /// Normalizes text for duplicate comparison: lowercase, trimmed.
    private func normalize(_ text: String?) -> String {
        (text ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Checks if a book with the same normalized title+author already exists.
    /// If author is nil/empty, checks title only.
    ///
    /// Per spec: "Duplicate Detection: Based on normalized (lowercased, trimmed) title + author.
    /// If author is missing, title alone is used."
    func isDuplicate(title: String, author: String?) -> Bool {
        let normalizedTitle = normalize(title)
        let normalizedAuthor = normalize(author)

        return library.books.contains { book in
            let bookTitle = normalize(book.title)
            let bookAuthor = normalize(book.author)

            if normalizedAuthor.isEmpty && bookAuthor.isEmpty {
                // Both have no author, compare title only
                return bookTitle == normalizedTitle
            } else if normalizedAuthor.isEmpty || bookAuthor.isEmpty {
                // One has author, one doesn't - compare title only
                return bookTitle == normalizedTitle
            } else {
                // Both have authors, compare both
                return bookTitle == normalizedTitle && bookAuthor == normalizedAuthor
            }
        }
    }

    // MARK: - Book Import

    /// Import a book from parsed content.
    ///
    /// This method:
    /// 1. Checks for duplicates (throws if found)
    /// 2. Tokenizes content to get word count
    /// 3. Saves book file to Books/{uuid}.{ext}
    /// 4. Saves cover to Covers/{uuid}.jpg if provided
    /// 5. Adds book to library and persists
    ///
    /// - Parameters:
    ///   - title: Book title
    ///   - author: Optional author name
    ///   - filename: Original filename
    ///   - fileType: Type of file
    ///   - content: Processed text content (already stripped of markdown/HTML)
    ///   - fileHash: SHA256 hash of original file
    ///   - coverData: Optional cover image data
    ///   - hasTOC: Whether the book has a table of contents
    ///   - chapters: Optional chapter list (for EPUB)
    /// - Returns: The created Book
    /// - Throws: FileImportError.duplicateBook if duplicate detected,
    ///           FileImportError.storageFull if disk is full
    func importBook(
        title: String,
        author: String?,
        filename: String,
        fileType: FileType,
        content: String,
        fileHash: String,
        coverData: Data?,
        hasTOC: Bool,
        chapters: [Chapter]?
    ) throws -> Book {
        // Check for duplicates
        if isDuplicate(title: title, author: author) {
            throw FileImportError.duplicateBook
        }

        // Tokenize to get word count
        let words = tokenize(content)
        let totalWords = words.count

        // Create book with new UUID
        let bookId = UUID()
        let book = Book(
            id: bookId,
            title: title,
            author: author,
            filename: filename,
            fileType: fileType,
            fileHash: fileHash,
            hasCover: coverData != nil,
            dateAdded: Date(),
            dateLastOpened: nil,
            totalWords: totalWords,
            currentWordIndex: 0,
            hasTOC: hasTOC
        )

        do {
            // Save book content to Books/{uuid}.{ext}
            let bookFileURL = booksDirectory.appendingPathComponent("\(bookId.uuidString).\(fileType.fileExtension)")
            try content.write(to: bookFileURL, atomically: true, encoding: .utf8)

            // Save cover if available to Covers/{uuid}.jpg
            if let coverData = coverData {
                let coverURL = coversDirectory.appendingPathComponent("\(bookId.uuidString).jpg")
                try coverData.write(to: coverURL)
            }

            // Save chapters if available to Chapters/{uuid}.json
            if let chapters = chapters, !chapters.isEmpty {
                let chaptersURL = chaptersDirectory.appendingPathComponent("\(bookId.uuidString).json")
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted]
                let chaptersData = try encoder.encode(chapters)
                try chaptersData.write(to: chaptersURL)
            }

            // Add to library and save
            library.books.append(book)
            try saveLibrary()

            return book
        } catch {
            // Clean up any partial files if import fails
            cleanupPartialImport(bookId: bookId, fileType: fileType)

            // Convert storage full errors to FileImportError.storageFull
            if Self.isStorageFullError(error) {
                throw FileImportError.storageFull
            }
            throw error
        }
    }

    /// Checks if an error indicates disk/storage is full
    private static func isStorageFullError(_ error: Error) -> Bool {
        let nsError = error as NSError
        // NSFileWriteOutOfSpaceError (error code 640)
        // NSFileWriteVolumeReadOnlyError (error code 642) - also treated as storage issue
        if nsError.domain == NSCocoaErrorDomain {
            return nsError.code == NSFileWriteOutOfSpaceError || nsError.code == 640
        }
        // POSIX errors
        if nsError.domain == NSPOSIXErrorDomain {
            return nsError.code == ENOSPC || nsError.code == EDQUOT
        }
        return false
    }

    /// Cleans up partially written files if import fails
    private func cleanupPartialImport(bookId: UUID, fileType: FileType) {
        let bookFileURL = booksDirectory.appendingPathComponent("\(bookId.uuidString).\(fileType.fileExtension)")
        let coverURL = coversDirectory.appendingPathComponent("\(bookId.uuidString).jpg")
        let chaptersURL = chaptersDirectory.appendingPathComponent("\(bookId.uuidString).json")

        try? fileManager.removeItem(at: bookFileURL)
        try? fileManager.removeItem(at: coverURL)
        try? fileManager.removeItem(at: chaptersURL)
    }

    /// Simple tokenization for word count (matches TokenizerService behavior)
    private func tokenize(_ text: String) -> [String] {
        // Normalize line endings
        var normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        normalized = normalized.replacingOccurrences(of: "\r", with: "\n")

        // Split into paragraphs
        let paragraphs = normalized.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var words: [String] = []
        for paragraph in paragraphs {
            let rawTokens = paragraph
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }

            for token in rawTokens {
                // Split hyphenated words per spec
                if token.contains("-") {
                    let parts = token.split(separator: "-", omittingEmptySubsequences: false)
                    if !parts.contains(where: { $0.isEmpty }) {
                        words.append(contentsOf: parts.map { String($0) })
                    } else {
                        words.append(token)
                    }
                } else {
                    words.append(token)
                }
            }
        }
        return words
    }

    // MARK: - Book Deletion

    /// Delete a single book from the library.
    ///
    /// Removes:
    /// - The book file from Books/
    /// - The cover from Covers/ (if exists)
    /// - The book entry from library.json
    func deleteBook(_ bookId: UUID) throws {
        guard let bookIndex = library.books.firstIndex(where: { $0.id == bookId }) else {
            return // Book not found, nothing to delete
        }

        let book = library.books[bookIndex]

        // Remove book file
        let bookFileURL = booksDirectory.appendingPathComponent("\(bookId.uuidString).\(book.fileType.fileExtension)")
        try? fileManager.removeItem(at: bookFileURL)

        // Remove cover if exists
        let coverURL = coversDirectory.appendingPathComponent("\(bookId.uuidString).jpg")
        try? fileManager.removeItem(at: coverURL)

        // Remove chapters if exists
        let chaptersURL = chaptersDirectory.appendingPathComponent("\(bookId.uuidString).json")
        try? fileManager.removeItem(at: chaptersURL)

        // Remove from library
        library.books.remove(at: bookIndex)
        try saveLibrary()
    }

    /// Delete multiple books from the library (bulk deletion).
    func deleteBooks(_ bookIds: [UUID]) throws {
        for bookId in bookIds {
            try deleteBook(bookId)
        }
    }

    // MARK: - Book Access and Progress

    /// Open a book, validating the file hash and updating last opened date.
    ///
    /// Per spec (Section 6.4 Progress Recovery):
    /// - If file hash changed (content modified), reset progress to 0
    /// - Updates dateLastOpened
    ///
    /// - Returns: Tuple of (book, hashChanged), or nil if the book file no longer exists
    /// - Note: If file is deleted, removes book from library and returns nil
    func openBook(_ bookId: UUID) throws -> (book: Book, hashChanged: Bool)? {
        guard let bookIndex = library.books.firstIndex(where: { $0.id == bookId }) else {
            return nil
        }

        var book = library.books[bookIndex]
        let bookFileURL = booksDirectory.appendingPathComponent("\(bookId.uuidString).\(book.fileType.fileExtension)")

        // Check if file exists
        guard fileManager.fileExists(atPath: bookFileURL.path) else {
            // File deleted - remove from library per spec
            library.books.remove(at: bookIndex)
            try saveLibrary()
            return nil
        }

        // Calculate current hash
        let currentData = try Data(contentsOf: bookFileURL)
        let currentHash = Self.calculateSHA256(data: currentData)

        var hashChanged = false
        if currentHash != book.fileHash {
            hashChanged = true
            // Hash changed - reset progress to 0 per spec
            let updatedBook = Book(
                id: book.id,
                title: book.title,
                author: book.author,
                filename: book.filename,
                fileType: book.fileType,
                fileHash: currentHash,
                hasCover: book.hasCover,
                dateAdded: book.dateAdded,
                dateLastOpened: Date(),
                totalWords: book.totalWords,
                currentWordIndex: 0,
                hasTOC: book.hasTOC
            )
            library.books[bookIndex] = updatedBook
            book = updatedBook
        } else {
            // Update last opened date
            book.dateLastOpened = Date()
            library.books[bookIndex] = book
        }

        try saveLibrary()
        return (book, hashChanged)
    }

    /// Update reading progress for a book.
    /// Progress is clamped to valid range [0, totalWords-1].
    func updateProgress(bookId: UUID, wordIndex: Int) throws {
        guard let bookIndex = library.books.firstIndex(where: { $0.id == bookId }) else {
            return
        }

        var book = library.books[bookIndex]
        // Clamp to valid range
        book.currentWordIndex = max(0, min(wordIndex, book.totalWords - 1))
        library.books[bookIndex] = book
        try saveLibrary()
    }

    /// Get the file URL for a book's content
    func bookFileURL(for bookId: UUID, fileType: FileType) -> URL {
        booksDirectory.appendingPathComponent("\(bookId.uuidString).\(fileType.fileExtension)")
    }

    /// Get the file URL for a book's cover image
    func coverURL(for bookId: UUID) -> URL {
        coversDirectory.appendingPathComponent("\(bookId.uuidString).jpg")
    }

    /// Get the file URL for a book's chapters
    func chaptersURL(for bookId: UUID) -> URL {
        chaptersDirectory.appendingPathComponent("\(bookId.uuidString).json")
    }

    // MARK: - Chapter Access

    /// Load chapters for a book (EPUB only).
    /// Returns an empty array if the book has no chapters or if the chapters file doesn't exist.
    func loadChapters(for bookId: UUID) -> [Chapter] {
        let chaptersURL = chaptersDirectory.appendingPathComponent("\(bookId.uuidString).json")

        guard fileManager.fileExists(atPath: chaptersURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: chaptersURL)
            let decoder = JSONDecoder()
            return try decoder.decode([Chapter].self, from: data)
        } catch {
            print("Failed to load chapters for book \(bookId): \(error)")
            return []
        }
    }

    /// Get a book by its ID (alias for byId)
    func book(for id: UUID) -> Book? {
        book(byId: id)
    }

    // MARK: - Sorting

    /// Get books sorted according to the current sort preference.
    ///
    /// Per spec (Section 4.1):
    /// - Recent: Most recently opened first; never-opened books last (sorted by date added)
    /// - Title: Alphabetical A-Z
    func sortedBooks() -> [Book] {
        switch library.settings.librarySort {
        case .recent:
            return library.books.sorted { book1, book2 in
                // Books with dateLastOpened sort before those without
                switch (book1.dateLastOpened, book2.dateLastOpened) {
                case (nil, nil):
                    // Both never opened - sort by date added (most recent first)
                    return book1.dateAdded > book2.dateAdded
                case (nil, _):
                    // book1 never opened, goes after
                    return false
                case (_, nil):
                    // book2 never opened, book1 goes before
                    return true
                case let (date1?, date2?):
                    // Both opened - most recent first
                    return date1 > date2
                }
            }
        case .title:
            return library.books.sorted { book1, book2 in
                book1.title.localizedCaseInsensitiveCompare(book2.title) == .orderedAscending
            }
        }
    }

    // MARK: - Helpers

    /// Calculate SHA256 hash of data
    static func calculateSHA256(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
