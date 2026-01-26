import Foundation

/// Errors that can occur during file import
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

extension FileImportError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Could not access this file"
        case .unsupportedFormat:
            return "This file type is not supported. Please use .txt, .md, or .epub files."
        case .encodingError:
            return "Could not read this file. It may use an unsupported text encoding."
        case .emptyFile:
            return "This file is empty."
        case .readError(let message):
            return "Could not read this file: \(message)"
        case .drmProtected:
            return "This EPUB is DRM protected and cannot be opened."
        case .corruptFile:
            return "This EPUB file appears to be damaged and cannot be opened."
        case .duplicateBook:
            return "This book is already in your library."
        case .storageFull:
            return "Not enough storage space to import this book."
        }
    }
}
