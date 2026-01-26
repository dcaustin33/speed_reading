import Foundation
import CryptoKit

/// Result of loading a text file
struct FileLoadResult {
    let content: String
    let hash: String
}

/// Service for importing and processing text files (.txt, .md)
/// EPUB support is provided by EPUBImportService (Task 5)
enum FileImportService {
    // MARK: - Public Methods

    /// Load a plain text (.txt) file from a URL
    /// - Parameter url: The URL of the file to load
    /// - Returns: FileLoadResult with content and SHA256 hash
    /// - Throws: FileImportError if the file cannot be loaded
    static func loadTextFile(from url: URL) throws -> FileLoadResult {
        let data = try loadFileData(from: url)
        let content = try decodeText(from: data)

        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FileImportError.emptyFile
        }

        let hash = calculateHash(data: data)
        return FileLoadResult(content: content, hash: hash)
    }

    /// Load a markdown (.md) file from a URL, stripping markdown syntax
    /// - Parameter url: The URL of the file to load
    /// - Returns: FileLoadResult with stripped content and SHA256 hash of original data
    /// - Throws: FileImportError if the file cannot be loaded
    static func loadMarkdownFile(from url: URL) throws -> FileLoadResult {
        let data = try loadFileData(from: url)
        let rawContent = try decodeText(from: data)
        let strippedContent = MarkdownStripper.strip(rawContent)

        guard !strippedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FileImportError.emptyFile
        }

        // Hash is calculated from original data, not stripped content
        let hash = calculateHash(data: data)
        return FileLoadResult(content: strippedContent, hash: hash)
    }

    /// Load a file based on its type
    /// - Parameters:
    ///   - url: The URL of the file to load
    ///   - fileType: The type of file being loaded
    /// - Returns: FileLoadResult with content and hash
    /// - Throws: FileImportError if the file cannot be loaded or type is unsupported
    static func loadFile(from url: URL, fileType: FileType) throws -> FileLoadResult {
        switch fileType {
        case .txt:
            return try loadTextFile(from: url)
        case .md:
            return try loadMarkdownFile(from: url)
        case .epub:
            let result = try EPUBImportService.loadEPUB(from: url)
            return FileLoadResult(content: result.content, hash: result.hash)
        }
    }

    /// Determine the file type from a URL's extension
    /// - Parameter url: The URL to check
    /// - Returns: The FileType if supported, nil otherwise
    static func fileType(from url: URL) -> FileType? {
        let ext = url.pathExtension.lowercased()
        return FileType.from(extension: ext)
    }

    /// Validate that a URL points to a supported file type
    /// - Parameter url: The URL to validate
    /// - Returns: The FileType if valid
    /// - Throws: FileImportError.unsupportedFormat if not a supported type
    static func validateFileType(url: URL) throws -> FileType {
        guard let type = fileType(from: url) else {
            throw FileImportError.unsupportedFormat
        }
        return type
    }

    // MARK: - Private Methods

    private static func loadFileData(from url: URL) throws -> Data {
        // Start accessing security-scoped resource if available
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileImportError.fileNotFound
        }

        do {
            return try Data(contentsOf: url)
        } catch {
            throw FileImportError.readError(error.localizedDescription)
        }
    }

    private static func decodeText(from data: Data) throws -> String {
        // Try UTF-8 first (most common for modern files)
        if let text = String(data: data, encoding: .utf8) {
            return text
        }

        // Try single-byte encodings before UTF-16
        // (UTF-16 can falsely decode random bytes as CJK characters)
        let singleByteEncodings: [String.Encoding] = [
            .isoLatin1,
            .windowsCP1252,
            .ascii
        ]

        for encoding in singleByteEncodings {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }

        // Try UTF-16 variants last
        let utf16Encodings: [String.Encoding] = [
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian
        ]

        for encoding in utf16Encodings {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }

        throw FileImportError.encodingError
    }

    private static func calculateHash(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
