import Foundation
import CryptoKit

/// Handles all file system operations for the app
/// - Manages library.json for book metadata and settings
/// - Handles book file storage in Books/ directory
/// - Handles cover image storage in Covers/ directory
final class StorageService {
    // MARK: - Constants

    private static let libraryFileName = "library.json"
    private static let booksDirectoryName = "Books"
    private static let coversDirectoryName = "Covers"

    // MARK: - Properties

    private let baseDirectory: URL
    private let fileManager = FileManager.default

    private var libraryFileURL: URL {
        baseDirectory.appendingPathComponent(Self.libraryFileName)
    }

    private var booksDirectory: URL {
        baseDirectory.appendingPathComponent(Self.booksDirectoryName)
    }

    private var coversDirectory: URL {
        baseDirectory.appendingPathComponent(Self.coversDirectoryName)
    }

    // MARK: - Initialization

    /// Create a StorageService with a custom base directory (mainly for testing)
    init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
    }

    /// Create a StorageService using the app's Documents directory
    convenience init() {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Unable to access Documents directory - this should never happen on iOS")
        }
        self.init(baseDirectory: documentsURL)
    }

    // MARK: - Directory Management

    /// Creates the necessary directory structure if it doesn't exist
    func initializeStorage() throws {
        try fileManager.createDirectory(at: booksDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: coversDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Library Operations

    /// Load the library from disk, or return a default empty library if file doesn't exist
    func loadLibrary() throws -> Library {
        guard fileManager.fileExists(atPath: libraryFileURL.path) else {
            return Library()
        }

        let data = try Data(contentsOf: libraryFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Library.self, from: data)
    }

    /// Save the library to disk
    func saveLibrary(_ library: Library) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(library)
        try data.write(to: libraryFileURL, options: .atomic)
    }

    // MARK: - Book File Operations

    /// Get the URL for a book file
    func bookFileURL(id: UUID, fileType: FileType) -> URL {
        booksDirectory.appendingPathComponent("\(id.uuidString).\(fileType.fileExtension)")
    }

    /// Save book file data to disk
    func saveBookFile(id: UUID, fileType: FileType, data: Data) throws {
        let url = bookFileURL(id: id, fileType: fileType)
        try data.write(to: url, options: .atomic)
    }

    /// Load book file data from disk
    func loadBookFile(id: UUID, fileType: FileType) throws -> Data {
        let url = bookFileURL(id: id, fileType: fileType)
        return try Data(contentsOf: url)
    }

    /// Delete a book file from disk
    func deleteBookFile(id: UUID, fileType: FileType) throws {
        let url = bookFileURL(id: id, fileType: fileType)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    /// Check if a book file exists
    func bookFileExists(id: UUID, fileType: FileType) -> Bool {
        let url = bookFileURL(id: id, fileType: fileType)
        return fileManager.fileExists(atPath: url.path)
    }

    // MARK: - Cover Image Operations

    /// Get the URL for a cover image
    func coverURL(id: UUID) -> URL {
        coversDirectory.appendingPathComponent("\(id.uuidString).jpg")
    }

    /// Save cover image data to disk
    func saveCover(id: UUID, data: Data) throws {
        let url = coverURL(id: id)
        try data.write(to: url, options: .atomic)
    }

    /// Load cover image data from disk
    func loadCover(id: UUID) throws -> Data {
        let url = coverURL(id: id)
        return try Data(contentsOf: url)
    }

    /// Delete a cover image from disk
    func deleteCover(id: UUID) throws {
        let url = coverURL(id: id)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    /// Check if a cover image exists
    func coverExists(id: UUID) -> Bool {
        let url = coverURL(id: id)
        return fileManager.fileExists(atPath: url.path)
    }

    // MARK: - Hash Calculation

    /// Calculate SHA256 hash of data
    static func calculateSHA256(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
