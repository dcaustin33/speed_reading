#!/usr/bin/env swift

// Test suite for LibraryDataService
// Run with: swift Tests/LibraryDataServiceTests.swift

import Foundation
import CryptoKit

// ============================================================================
// MARK: - Test Infrastructure
// ============================================================================

struct TestResult {
    let name: String
    let passed: Bool
    let message: String?
}

var testResults: [TestResult] = []

func test(_ name: String, _ block: () throws -> Bool) {
    do {
        let passed = try block()
        testResults.append(TestResult(name: name, passed: passed, message: passed ? nil : "Test assertion failed"))
    } catch {
        testResults.append(TestResult(name: name, passed: false, message: "Exception: \(error)"))
    }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "") -> Bool {
    if a != b {
        print("  assertEqual failed: '\(a)' != '\(b)' \(message)")
        return false
    }
    return true
}

func assertTrue(_ condition: Bool, _ message: String = "") -> Bool {
    if !condition {
        print("  assertTrue failed \(message)")
        return false
    }
    return true
}

func assertFalse(_ condition: Bool, _ message: String = "") -> Bool {
    if condition {
        print("  assertFalse failed \(message)")
        return false
    }
    return true
}

func assertNil<T>(_ value: T?, _ message: String = "") -> Bool {
    if value != nil {
        print("  assertNil failed: value is \(value!) \(message)")
        return false
    }
    return true
}

func assertNotNil<T>(_ value: T?, _ message: String = "") -> Bool {
    if value == nil {
        print("  assertNotNil failed: value is nil \(message)")
        return false
    }
    return true
}

func assertThrows<E: Error & Equatable>(_ expectedError: E, _ block: () throws -> Void) -> Bool {
    do {
        try block()
        print("  assertThrows failed: no error thrown")
        return false
    } catch let error as E {
        if error != expectedError {
            print("  assertThrows failed: expected \(expectedError) but got \(error)")
            return false
        }
        return true
    } catch {
        print("  assertThrows failed: wrong error type: \(error)")
        return false
    }
}

// ============================================================================
// MARK: - Models (duplicated for standalone testing)
// ============================================================================

enum FileType: String, Codable {
    case txt
    case md
    case epub

    var fileExtension: String { rawValue }

    static func from(extension ext: String) -> FileType? {
        switch ext.lowercased() {
        case "txt": return .txt
        case "md": return .md
        case "epub": return .epub
        default: return nil
        }
    }
}

struct Book: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let author: String?
    let filename: String
    let fileType: FileType
    let fileHash: String
    let hasCover: Bool
    let dateAdded: Date
    var dateLastOpened: Date?
    let totalWords: Int
    var currentWordIndex: Int
    let hasTOC: Bool

    var progressPercentage: Double {
        guard totalWords > 0 else { return 0.0 }
        return Double(currentWordIndex) / Double(totalWords)
    }
}

struct Chapter: Codable, Equatable {
    let title: String
    let startWordIndex: Int
}

struct Word: Codable, Equatable {
    let text: String
    let orpIndex: Int
    let sentenceEnd: Bool
    let paragraphEnd: Bool
    let chapterIndex: Int?
}

struct Document: Codable, Equatable {
    let words: [Word]
    let chapters: [Chapter]?

    var totalWords: Int { words.count }

    init(words: [Word], chapters: [Chapter]? = nil) {
        self.words = words
        self.chapters = chapters
    }
}

enum SortOrder: String, Codable {
    case recent
    case title
}

struct Settings: Codable, Equatable {
    var wpm: Int = 300
    var paragraphPause: Double = 1.0
    var fontSize: Int = 48
    var wordSkip: Int = 5
    var librarySort: SortOrder = .recent
}

struct Library: Codable {
    var books: [Book]
    var settings: Settings

    init(books: [Book] = [], settings: Settings = Settings()) {
        self.books = books
        self.settings = settings
    }
}

enum FileImportError: Error, Equatable {
    case fileNotFound
    case unsupportedFormat
    case encodingError
    case emptyFile
    case readError(String)
    case drmProtected
    case corruptFile
    case duplicateBook
    case storageFull
}

// ============================================================================
// MARK: - LibraryDataService (implementation to test)
// ============================================================================

/// Service for managing the library: importing books, detecting duplicates, deletion, and sorting.
final class LibraryDataService {
    private var library: Library
    private let storageURL: URL
    private let booksDirectory: URL
    private let coversDirectory: URL
    private let fileManager = FileManager.default

    init(storageURL: URL) {
        self.storageURL = storageURL
        self.booksDirectory = storageURL.appendingPathComponent("Books")
        self.coversDirectory = storageURL.appendingPathComponent("Covers")
        self.library = Library()

        // Create directories if needed
        try? fileManager.createDirectory(at: booksDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: coversDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Library Persistence

    private var libraryFileURL: URL {
        storageURL.appendingPathComponent("library.json")
    }

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

    func saveLibrary() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(library)
        try data.write(to: libraryFileURL, options: .atomic)
    }

    // MARK: - Accessors

    var books: [Book] { library.books }
    var settings: Settings {
        get { library.settings }
        set { library.settings = newValue }
    }

    // MARK: - Duplicate Detection

    /// Normalizes text for duplicate comparison: lowercase, trimmed.
    private func normalize(_ text: String?) -> String {
        (text ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Checks if a book with the same normalized title+author already exists.
    /// If author is nil, checks title only.
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
    /// - Parameters:
    ///   - title: Book title
    ///   - author: Optional author name
    ///   - filename: Original filename
    ///   - fileType: Type of file
    ///   - content: Processed text content
    ///   - fileHash: SHA256 hash of original file
    ///   - coverData: Optional cover image data
    ///   - hasTOC: Whether the book has a table of contents
    ///   - chapters: Optional chapter list
    /// - Returns: The created Book
    /// - Throws: FileImportError.duplicateBook if duplicate detected
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

        // Save book file to Books/{uuid}.{ext}
        let bookFileURL = booksDirectory.appendingPathComponent("\(bookId.uuidString).\(fileType.fileExtension)")
        try content.write(to: bookFileURL, atomically: true, encoding: .utf8)

        // Save cover if available
        if let coverData = coverData {
            let coverURL = coversDirectory.appendingPathComponent("\(bookId.uuidString).jpg")
            try coverData.write(to: coverURL)
        }

        // Add to library and save
        library.books.append(book)
        try saveLibrary()

        return book
    }

    /// Simple tokenization for word count (matches TokenizerService behavior)
    private func tokenize(_ text: String) -> [String] {
        var normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        normalized = normalized.replacingOccurrences(of: "\r", with: "\n")

        let paragraphs = normalized.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var words: [String] = []
        for paragraph in paragraphs {
            let rawTokens = paragraph
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }

            for token in rawTokens {
                // Split hyphenated words
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

        // Remove from library
        library.books.remove(at: bookIndex)
        try saveLibrary()
    }

    /// Delete multiple books from the library.
    func deleteBooks(_ bookIds: [UUID]) throws {
        for bookId in bookIds {
            try deleteBook(bookId)
        }
    }

    // MARK: - Book Access and Progress

    /// Open a book, validating the file hash and updating last opened date.
    /// Returns nil if the book file no longer exists.
    /// Resets progress to 0 if hash has changed.
    func openBook(_ bookId: UUID) throws -> (book: Book, hashChanged: Bool)? {
        guard let bookIndex = library.books.firstIndex(where: { $0.id == bookId }) else {
            return nil
        }

        var book = library.books[bookIndex]
        let bookFileURL = booksDirectory.appendingPathComponent("\(bookId.uuidString).\(book.fileType.fileExtension)")

        // Check if file exists
        guard fileManager.fileExists(atPath: bookFileURL.path) else {
            // File deleted - remove from library
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
            // Hash changed - create new book with reset progress
            // We need to update the stored book
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
    func updateProgress(bookId: UUID, wordIndex: Int) throws {
        guard let bookIndex = library.books.firstIndex(where: { $0.id == bookId }) else {
            return
        }

        var book = library.books[bookIndex]
        book.currentWordIndex = max(0, min(wordIndex, book.totalWords - 1))
        library.books[bookIndex] = book
        try saveLibrary()
    }

    // MARK: - Sorting

    /// Get books sorted according to the current sort preference.
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

    static func calculateSHA256(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Get a book by ID
    func book(byId id: UUID) -> Book? {
        library.books.first { $0.id == id }
    }
}

// ============================================================================
// MARK: - Tests
// ============================================================================

// Create a temp directory for testing
let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("LibraryDataServiceTests_\(UUID().uuidString)")
try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

defer {
    try? FileManager.default.removeItem(at: tempDir)
}

// ============================================================================
// MARK: - Duplicate Detection Tests
// ============================================================================

test("isDuplicate returns false for empty library") {
    let service = LibraryDataService(storageURL: tempDir.appendingPathComponent("test1"))
    return assertFalse(service.isDuplicate(title: "Test Book", author: "Author"))
}

test("isDuplicate returns true for exact match title+author") {
    let service = LibraryDataService(storageURL: tempDir.appendingPathComponent("test2"))
    _ = try service.importBook(
        title: "Test Book",
        author: "Test Author",
        filename: "test.txt",
        fileType: .txt,
        content: "This is test content with enough words.",
        fileHash: "abc123",
        coverData: nil,
        hasTOC: false,
        chapters: nil
    )
    return assertTrue(service.isDuplicate(title: "Test Book", author: "Test Author"))
}

test("isDuplicate is case insensitive") {
    let service = LibraryDataService(storageURL: tempDir.appendingPathComponent("test3"))
    _ = try service.importBook(
        title: "Test Book",
        author: "Test Author",
        filename: "test.txt",
        fileType: .txt,
        content: "This is test content.",
        fileHash: "abc123",
        coverData: nil,
        hasTOC: false,
        chapters: nil
    )
    return assertTrue(service.isDuplicate(title: "TEST BOOK", author: "TEST AUTHOR"))
}

test("isDuplicate trims whitespace") {
    let service = LibraryDataService(storageURL: tempDir.appendingPathComponent("test4"))
    _ = try service.importBook(
        title: "Test Book",
        author: "Test Author",
        filename: "test.txt",
        fileType: .txt,
        content: "This is test content.",
        fileHash: "abc123",
        coverData: nil,
        hasTOC: false,
        chapters: nil
    )
    return assertTrue(service.isDuplicate(title: "  Test Book  ", author: "  Test Author  "))
}

test("isDuplicate with nil author matches title only") {
    let service = LibraryDataService(storageURL: tempDir.appendingPathComponent("test5"))
    _ = try service.importBook(
        title: "Test Book",
        author: nil,
        filename: "test.txt",
        fileType: .txt,
        content: "This is test content.",
        fileHash: "abc123",
        coverData: nil,
        hasTOC: false,
        chapters: nil
    )
    return assertTrue(service.isDuplicate(title: "Test Book", author: nil))
}

test("isDuplicate different author is not duplicate") {
    let service = LibraryDataService(storageURL: tempDir.appendingPathComponent("test6"))
    _ = try service.importBook(
        title: "Test Book",
        author: "Author One",
        filename: "test.txt",
        fileType: .txt,
        content: "This is test content.",
        fileHash: "abc123",
        coverData: nil,
        hasTOC: false,
        chapters: nil
    )
    return assertFalse(service.isDuplicate(title: "Test Book", author: "Author Two"))
}

test("isDuplicate nil author matches book without author but same title") {
    let service = LibraryDataService(storageURL: tempDir.appendingPathComponent("test7"))
    _ = try service.importBook(
        title: "Test Book",
        author: nil,
        filename: "test.txt",
        fileType: .txt,
        content: "This is test content.",
        fileHash: "abc123",
        coverData: nil,
        hasTOC: false,
        chapters: nil
    )
    // When checking with nil author, it should match any book with same title regardless of their author
    return assertTrue(service.isDuplicate(title: "Test Book", author: nil))
}

test("isDuplicate existing nil author vs checking with author - matches title") {
    let service = LibraryDataService(storageURL: tempDir.appendingPathComponent("test8"))
    _ = try service.importBook(
        title: "Test Book",
        author: nil,
        filename: "test.txt",
        fileType: .txt,
        content: "This is test content.",
        fileHash: "abc123",
        coverData: nil,
        hasTOC: false,
        chapters: nil
    )
    // Per spec: "If author is missing, title alone is used"
    // When existing book has no author, a new book with same title should be duplicate
    return assertTrue(service.isDuplicate(title: "Test Book", author: "Some Author"))
}

// ============================================================================
// MARK: - Book Import Tests
// ============================================================================

test("importBook creates book with correct properties") {
    let service = LibraryDataService(storageURL: tempDir.appendingPathComponent("test9"))
    let book = try service.importBook(
        title: "My Book",
        author: "Jane Doe",
        filename: "mybook.epub",
        fileType: .epub,
        content: "Word one two three four five.",
        fileHash: "hash123",
        coverData: nil,
        hasTOC: true,
        chapters: nil
    )

    return assertEqual(book.title, "My Book") &&
           assertEqual(book.author, "Jane Doe") &&
           assertEqual(book.filename, "mybook.epub") &&
           assertEqual(book.fileType, .epub) &&
           assertEqual(book.fileHash, "hash123") &&
           assertEqual(book.hasCover, false) &&
           assertEqual(book.hasTOC, true) &&
           assertEqual(book.currentWordIndex, 0) &&
           assertNil(book.dateLastOpened)
}

test("importBook calculates totalWords correctly") {
    let service = LibraryDataService(storageURL: tempDir.appendingPathComponent("test10"))
    let book = try service.importBook(
        title: "Test",
        author: nil,
        filename: "test.txt",
        fileType: .txt,
        content: "One two three four five six seven eight nine ten.",
        fileHash: "hash",
        coverData: nil,
        hasTOC: false,
        chapters: nil
    )
    return assertEqual(book.totalWords, 10)
}

test("importBook handles hyphenated words in word count") {
    let service = LibraryDataService(storageURL: tempDir.appendingPathComponent("test11"))
    let book = try service.importBook(
        title: "Test",
        author: nil,
        filename: "test.txt",
        fileType: .txt,
        content: "This is state-of-the-art technology.", // 2 + 4 + 1 = 7 words
        fileHash: "hash",
        coverData: nil,
        hasTOC: false,
        chapters: nil
    )
    return assertEqual(book.totalWords, 7)
}

test("importBook saves book file to disk") {
    let testDir = tempDir.appendingPathComponent("test12")
    let service = LibraryDataService(storageURL: testDir)
    let book = try service.importBook(
        title: "Test",
        author: nil,
        filename: "test.txt",
        fileType: .txt,
        content: "Test content here.",
        fileHash: "hash",
        coverData: nil,
        hasTOC: false,
        chapters: nil
    )

    let bookFileURL = testDir.appendingPathComponent("Books/\(book.id.uuidString).txt")
    return assertTrue(FileManager.default.fileExists(atPath: bookFileURL.path))
}

test("importBook saves cover file when provided") {
    let testDir = tempDir.appendingPathComponent("test13")
    let service = LibraryDataService(storageURL: testDir)
    let coverData = Data([0xFF, 0xD8, 0xFF]) // JPEG magic bytes
    let book = try service.importBook(
        title: "Test",
        author: nil,
        filename: "test.epub",
        fileType: .epub,
        content: "Test content.",
        fileHash: "hash",
        coverData: coverData,
        hasTOC: false,
        chapters: nil
    )

    let coverURL = testDir.appendingPathComponent("Covers/\(book.id.uuidString).jpg")
    return assertTrue(FileManager.default.fileExists(atPath: coverURL.path)) &&
           assertEqual(book.hasCover, true)
}

test("importBook throws duplicateBook for duplicate") {
    let service = LibraryDataService(storageURL: tempDir.appendingPathComponent("test14"))
    _ = try service.importBook(
        title: "Test Book",
        author: "Author",
        filename: "test1.txt",
        fileType: .txt,
        content: "Content one.",
        fileHash: "hash1",
        coverData: nil,
        hasTOC: false,
        chapters: nil
    )

    return assertThrows(FileImportError.duplicateBook) {
        _ = try service.importBook(
            title: "Test Book",
            author: "Author",
            filename: "test2.txt",
            fileType: .txt,
            content: "Content two.",
            fileHash: "hash2",
            coverData: nil,
            hasTOC: false,
            chapters: nil
        )
    }
}

test("importBook persists to library.json") {
    let testDir = tempDir.appendingPathComponent("test15")
    let service = LibraryDataService(storageURL: testDir)
    _ = try service.importBook(
        title: "Persisted Book",
        author: nil,
        filename: "test.txt",
        fileType: .txt,
        content: "Test content.",
        fileHash: "hash",
        coverData: nil,
        hasTOC: false,
        chapters: nil
    )

    // Create new service and load
    let service2 = LibraryDataService(storageURL: testDir)
    try service2.loadLibrary()

    return assertEqual(service2.books.count, 1) &&
           assertEqual(service2.books[0].title, "Persisted Book")
}

// ============================================================================
// MARK: - Book Deletion Tests
// ============================================================================

test("deleteBook removes book from library") {
    let service = LibraryDataService(storageURL: tempDir.appendingPathComponent("test16"))
    let book = try service.importBook(
        title: "To Delete",
        author: nil,
        filename: "test.txt",
        fileType: .txt,
        content: "Content.",
        fileHash: "hash",
        coverData: nil,
        hasTOC: false,
        chapters: nil
    )

    assertEqual(service.books.count, 1)
    try service.deleteBook(book.id)
    return assertEqual(service.books.count, 0)
}

test("deleteBook removes book file from disk") {
    let testDir = tempDir.appendingPathComponent("test17")
    let service = LibraryDataService(storageURL: testDir)
    let book = try service.importBook(
        title: "To Delete",
        author: nil,
        filename: "test.txt",
        fileType: .txt,
        content: "Content.",
        fileHash: "hash",
        coverData: nil,
        hasTOC: false,
        chapters: nil
    )

    let bookFileURL = testDir.appendingPathComponent("Books/\(book.id.uuidString).txt")
    assertTrue(FileManager.default.fileExists(atPath: bookFileURL.path))

    try service.deleteBook(book.id)
    return assertFalse(FileManager.default.fileExists(atPath: bookFileURL.path))
}

test("deleteBook removes cover file from disk") {
    let testDir = tempDir.appendingPathComponent("test18")
    let service = LibraryDataService(storageURL: testDir)
    let coverData = Data([0xFF, 0xD8, 0xFF])
    let book = try service.importBook(
        title: "To Delete",
        author: nil,
        filename: "test.epub",
        fileType: .epub,
        content: "Content.",
        fileHash: "hash",
        coverData: coverData,
        hasTOC: false,
        chapters: nil
    )

    let coverURL = testDir.appendingPathComponent("Covers/\(book.id.uuidString).jpg")
    assertTrue(FileManager.default.fileExists(atPath: coverURL.path))

    try service.deleteBook(book.id)
    return assertFalse(FileManager.default.fileExists(atPath: coverURL.path))
}

test("deleteBooks supports bulk deletion") {
    let service = LibraryDataService(storageURL: tempDir.appendingPathComponent("test19"))
    let book1 = try service.importBook(title: "Book 1", author: nil, filename: "1.txt", fileType: .txt, content: "A", fileHash: "h1", coverData: nil, hasTOC: false, chapters: nil)
    let book2 = try service.importBook(title: "Book 2", author: nil, filename: "2.txt", fileType: .txt, content: "B", fileHash: "h2", coverData: nil, hasTOC: false, chapters: nil)
    let book3 = try service.importBook(title: "Book 3", author: nil, filename: "3.txt", fileType: .txt, content: "C", fileHash: "h3", coverData: nil, hasTOC: false, chapters: nil)

    assertEqual(service.books.count, 3)
    try service.deleteBooks([book1.id, book3.id])

    return assertEqual(service.books.count, 1) &&
           assertEqual(service.books[0].title, "Book 2")
}

test("deleteBook does nothing for non-existent book") {
    let service = LibraryDataService(storageURL: tempDir.appendingPathComponent("test20"))
    _ = try service.importBook(title: "Book", author: nil, filename: "1.txt", fileType: .txt, content: "A", fileHash: "h1", coverData: nil, hasTOC: false, chapters: nil)

    try service.deleteBook(UUID()) // Random UUID
    return assertEqual(service.books.count, 1)
}

// ============================================================================
// MARK: - File Hash Validation Tests
// ============================================================================

test("openBook returns book with hashChanged false when hash matches") {
    let testDir = tempDir.appendingPathComponent("test21")
    let service = LibraryDataService(storageURL: testDir)
    let content = "Test content for hashing."
    let hash = LibraryDataService.calculateSHA256(data: content.data(using: .utf8)!)

    let book = try service.importBook(
        title: "Test",
        author: nil,
        filename: "test.txt",
        fileType: .txt,
        content: content,
        fileHash: hash,
        coverData: nil,
        hasTOC: false,
        chapters: nil
    )

    let result = try service.openBook(book.id)
    return assertNotNil(result) &&
           assertFalse(result!.hashChanged)
}

test("openBook returns hashChanged true when content modified") {
    let testDir = tempDir.appendingPathComponent("test22")
    let service = LibraryDataService(storageURL: testDir)

    let book = try service.importBook(
        title: "Test",
        author: nil,
        filename: "test.txt",
        fileType: .txt,
        content: "Original content.",
        fileHash: "original_hash",
        coverData: nil,
        hasTOC: false,
        chapters: nil
    )

    // Modify the file on disk
    let bookFileURL = testDir.appendingPathComponent("Books/\(book.id.uuidString).txt")
    try "Modified content.".write(to: bookFileURL, atomically: true, encoding: .utf8)

    let result = try service.openBook(book.id)
    return assertNotNil(result) &&
           assertTrue(result!.hashChanged)
}

test("openBook resets progress to 0 when hash changed") {
    let testDir = tempDir.appendingPathComponent("test23")
    let service = LibraryDataService(storageURL: testDir)

    var book = try service.importBook(
        title: "Test",
        author: nil,
        filename: "test.txt",
        fileType: .txt,
        content: "One two three four five.",
        fileHash: "original_hash",
        coverData: nil,
        hasTOC: false,
        chapters: nil
    )

    // Set some progress
    try service.updateProgress(bookId: book.id, wordIndex: 3)
    book = service.book(byId: book.id)!
    assertEqual(book.currentWordIndex, 3)

    // Modify the file on disk
    let bookFileURL = testDir.appendingPathComponent("Books/\(book.id.uuidString).txt")
    try "Modified content here.".write(to: bookFileURL, atomically: true, encoding: .utf8)

    let result = try service.openBook(book.id)
    return assertEqual(result?.book.currentWordIndex, 0)
}

test("openBook returns nil and removes book when file deleted") {
    let testDir = tempDir.appendingPathComponent("test24")
    let service = LibraryDataService(storageURL: testDir)

    let book = try service.importBook(
        title: "Test",
        author: nil,
        filename: "test.txt",
        fileType: .txt,
        content: "Content.",
        fileHash: "hash",
        coverData: nil,
        hasTOC: false,
        chapters: nil
    )

    assertEqual(service.books.count, 1)

    // Delete the file manually
    let bookFileURL = testDir.appendingPathComponent("Books/\(book.id.uuidString).txt")
    try FileManager.default.removeItem(at: bookFileURL)

    let result = try service.openBook(book.id)
    return assertNil(result) &&
           assertEqual(service.books.count, 0)
}

test("openBook updates dateLastOpened") {
    let testDir = tempDir.appendingPathComponent("test25")
    let service = LibraryDataService(storageURL: testDir)
    let content = "Content here."
    let hash = LibraryDataService.calculateSHA256(data: content.data(using: .utf8)!)

    let book = try service.importBook(
        title: "Test",
        author: nil,
        filename: "test.txt",
        fileType: .txt,
        content: content,
        fileHash: hash,
        coverData: nil,
        hasTOC: false,
        chapters: nil
    )

    assertNil(book.dateLastOpened)

    let result = try service.openBook(book.id)
    return assertNotNil(result?.book.dateLastOpened)
}

// ============================================================================
// MARK: - Sorting Tests
// ============================================================================

test("sortedBooks by recent puts most recently opened first") {
    let service = LibraryDataService(storageURL: tempDir.appendingPathComponent("test26"))
    let content = "Content."
    let hash = LibraryDataService.calculateSHA256(data: content.data(using: .utf8)!)

    let book1 = try service.importBook(title: "Book A", author: nil, filename: "a.txt", fileType: .txt, content: content, fileHash: hash + "1", coverData: nil, hasTOC: false, chapters: nil)
    let book2 = try service.importBook(title: "Book B", author: nil, filename: "b.txt", fileType: .txt, content: content, fileHash: hash + "2", coverData: nil, hasTOC: false, chapters: nil)
    let book3 = try service.importBook(title: "Book C", author: nil, filename: "c.txt", fileType: .txt, content: content, fileHash: hash + "3", coverData: nil, hasTOC: false, chapters: nil)

    // Open books in order: book2, then book3
    _ = try service.openBook(book2.id)
    Thread.sleep(forTimeInterval: 0.01)
    _ = try service.openBook(book3.id)

    service.settings.librarySort = .recent
    let sorted = service.sortedBooks()

    // book3 was opened most recently, then book2, then book1 (never opened)
    return assertEqual(sorted[0].id, book3.id) &&
           assertEqual(sorted[1].id, book2.id) &&
           assertEqual(sorted[2].id, book1.id)
}

test("sortedBooks by recent puts never-opened books last") {
    let service = LibraryDataService(storageURL: tempDir.appendingPathComponent("test27"))
    let content = "Content."
    let hash = LibraryDataService.calculateSHA256(data: content.data(using: .utf8)!)

    let book1 = try service.importBook(title: "Book A", author: nil, filename: "a.txt", fileType: .txt, content: content, fileHash: hash + "1", coverData: nil, hasTOC: false, chapters: nil)
    let book2 = try service.importBook(title: "Book B", author: nil, filename: "b.txt", fileType: .txt, content: content, fileHash: hash + "2", coverData: nil, hasTOC: false, chapters: nil)

    _ = try service.openBook(book2.id)

    service.settings.librarySort = .recent
    let sorted = service.sortedBooks()

    return assertEqual(sorted[0].id, book2.id) &&
           assertEqual(sorted[1].id, book1.id)
}

test("sortedBooks by title sorts alphabetically A-Z") {
    let service = LibraryDataService(storageURL: tempDir.appendingPathComponent("test28"))

    _ = try service.importBook(title: "Zebra", author: nil, filename: "z.txt", fileType: .txt, content: "C", fileHash: "h3", coverData: nil, hasTOC: false, chapters: nil)
    _ = try service.importBook(title: "Apple", author: nil, filename: "a.txt", fileType: .txt, content: "C", fileHash: "h1", coverData: nil, hasTOC: false, chapters: nil)
    _ = try service.importBook(title: "Mango", author: nil, filename: "m.txt", fileType: .txt, content: "C", fileHash: "h2", coverData: nil, hasTOC: false, chapters: nil)

    service.settings.librarySort = .title
    let sorted = service.sortedBooks()

    return assertEqual(sorted[0].title, "Apple") &&
           assertEqual(sorted[1].title, "Mango") &&
           assertEqual(sorted[2].title, "Zebra")
}

test("sortedBooks by title is case insensitive") {
    let service = LibraryDataService(storageURL: tempDir.appendingPathComponent("test29"))

    _ = try service.importBook(title: "zebra", author: nil, filename: "z.txt", fileType: .txt, content: "C", fileHash: "h3", coverData: nil, hasTOC: false, chapters: nil)
    _ = try service.importBook(title: "APPLE", author: nil, filename: "a.txt", fileType: .txt, content: "C", fileHash: "h1", coverData: nil, hasTOC: false, chapters: nil)
    _ = try service.importBook(title: "Mango", author: nil, filename: "m.txt", fileType: .txt, content: "C", fileHash: "h2", coverData: nil, hasTOC: false, chapters: nil)

    service.settings.librarySort = .title
    let sorted = service.sortedBooks()

    return assertEqual(sorted[0].title, "APPLE") &&
           assertEqual(sorted[1].title, "Mango") &&
           assertEqual(sorted[2].title, "zebra")
}

// ============================================================================
// MARK: - Progress Update Tests
// ============================================================================

test("updateProgress clamps to valid range") {
    let service = LibraryDataService(storageURL: tempDir.appendingPathComponent("test30"))
    let book = try service.importBook(
        title: "Test",
        author: nil,
        filename: "test.txt",
        fileType: .txt,
        content: "One two three four five.", // 5 words
        fileHash: "hash",
        coverData: nil,
        hasTOC: false,
        chapters: nil
    )

    // Try to set beyond bounds
    try service.updateProgress(bookId: book.id, wordIndex: 100)
    var updated = service.book(byId: book.id)!
    assertEqual(updated.currentWordIndex, 4) // max is totalWords - 1

    // Try negative
    try service.updateProgress(bookId: book.id, wordIndex: -5)
    updated = service.book(byId: book.id)!
    return assertEqual(updated.currentWordIndex, 0)
}

test("updateProgress persists to disk") {
    let testDir = tempDir.appendingPathComponent("test31")
    let service = LibraryDataService(storageURL: testDir)
    let book = try service.importBook(
        title: "Test",
        author: nil,
        filename: "test.txt",
        fileType: .txt,
        content: "One two three four five.",
        fileHash: "hash",
        coverData: nil,
        hasTOC: false,
        chapters: nil
    )

    try service.updateProgress(bookId: book.id, wordIndex: 3)

    // Load in new service
    let service2 = LibraryDataService(storageURL: testDir)
    try service2.loadLibrary()

    return assertEqual(service2.book(byId: book.id)?.currentWordIndex, 3)
}

// ============================================================================
// MARK: - Run Tests
// ============================================================================

print("Running LibraryDataService tests...")
print("")

var passed = 0
var failed = 0

for result in testResults {
    if result.passed {
        print("✓ \(result.name)")
        passed += 1
    } else {
        print("✗ \(result.name)")
        if let message = result.message {
            print("  \(message)")
        }
        failed += 1
    }
}

print("")
print("Results: \(passed) passed, \(failed) failed")

if failed > 0 {
    exit(1)
}
