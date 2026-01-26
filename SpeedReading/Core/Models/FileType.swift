import Foundation

/// Supported file types for imported books
enum FileType: String, Codable, Hashable, CaseIterable {
    case txt
    case md
    case epub

    /// The file extension for this type
    var fileExtension: String {
        rawValue
    }

    /// Create a FileType from a file extension (case-insensitive)
    static func from(extension ext: String) -> FileType? {
        FileType(rawValue: ext.lowercased())
    }
}
