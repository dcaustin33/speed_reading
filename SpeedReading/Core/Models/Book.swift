import Foundation

/// Represents a book in the user's library
struct Book: Identifiable, Codable, Hashable {
    /// Unique identifier for the book
    let id: UUID

    /// Book title (from EPUB metadata or filename)
    let title: String

    /// Author name (from EPUB metadata, optional for txt/md)
    let author: String?

    /// Original filename when imported
    let filename: String

    /// Type of file (.txt, .md, .epub)
    let fileType: FileType

    /// SHA256 hash of file content for change detection
    let fileHash: String

    /// Whether a cover image is available
    let hasCover: Bool

    /// When the book was imported
    let dateAdded: Date

    /// When the book was last opened for reading
    var dateLastOpened: Date?

    /// Total number of words in the book
    let totalWords: Int

    /// Current reading position (0-based word index)
    var currentWordIndex: Int

    /// Whether the book has a table of contents (EPUB only)
    let hasTOC: Bool

    /// Reading progress as a percentage (0.0 to 1.0)
    var progressPercentage: Double {
        guard totalWords > 0 else { return 0.0 }
        return Double(currentWordIndex) / Double(totalWords)
    }

    /// Create a new book
    init(
        id: UUID = UUID(),
        title: String,
        author: String?,
        filename: String,
        fileType: FileType,
        fileHash: String,
        hasCover: Bool,
        dateAdded: Date = Date(),
        dateLastOpened: Date? = nil,
        totalWords: Int,
        currentWordIndex: Int = 0,
        hasTOC: Bool
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.filename = filename
        self.fileType = fileType
        self.fileHash = fileHash
        self.hasCover = hasCover
        self.dateAdded = dateAdded
        self.dateLastOpened = dateLastOpened
        self.totalWords = totalWords
        self.currentWordIndex = currentWordIndex
        self.hasTOC = hasTOC
    }
}
