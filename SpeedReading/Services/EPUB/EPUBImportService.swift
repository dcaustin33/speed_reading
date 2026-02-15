import Foundation
import CryptoKit
import Compression

/// Result of loading an EPUB file
struct EPUBLoadResult {
    let content: String          // Plain text content (all chapters combined)
    let hash: String             // SHA256 hash of the original EPUB file
    let metadata: EPUBMetadata   // Title, author, cover path
    let chapters: [Chapter]      // Chapter boundaries with word indices
    let coverData: Data?         // Cover image data if available
    let hasTOC: Bool             // Whether the EPUB has a table of contents
}

/// Service for importing and processing EPUB files.
/// Handles ZIP extraction, content parsing, DRM detection, metadata and TOC extraction.
enum EPUBImportService {
    // MARK: - Public Methods

    /// Load an EPUB file and extract its content
    /// - Parameter url: The URL of the EPUB file
    /// - Returns: EPUBLoadResult with content, metadata, and chapters
    /// - Throws: FileImportError if the file cannot be loaded
    static func loadEPUB(from url: URL) throws -> EPUBLoadResult {
        print("[EPUB] Loading EPUB from: \(url.path)")
        print("[EPUB] File exists: \(FileManager.default.fileExists(atPath: url.path))")

        // Start accessing security-scoped resource if available
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Load the raw file data for hash calculation
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileImportError.fileNotFound
        }

        let fileData: Data
        do {
            fileData = try Data(contentsOf: url)
        } catch {
            throw FileImportError.readError(error.localizedDescription)
        }

        let hash = calculateHash(data: fileData)

        // Extract EPUB contents
        let epubContents = try extractEPUB(from: url)
        print("[EPUB] Extracted \(epubContents.count) entries: \(epubContents.keys.sorted())")

        // Check for DRM
        if let encryptionXML = epubContents["META-INF/encryption.xml"] {
            if DRMDetector.hasDRM(encryptionXML: String(data: encryptionXML, encoding: .utf8)) {
                throw FileImportError.drmProtected
            }
        }

        // Find and parse container.xml to locate OPF file
        guard let containerData = epubContents["META-INF/container.xml"],
              let containerXML = String(data: containerData, encoding: .utf8) else {
            throw FileImportError.corruptFile
        }

        guard let opfPath = parseContainerForOPF(containerXML) else {
            throw FileImportError.corruptFile
        }

        // Parse OPF file
        guard let opfData = epubContents[opfPath],
              let opfXML = String(data: opfData, encoding: .utf8) else {
            throw FileImportError.corruptFile
        }

        guard let metadata = OPFParser.parseMetadata(opfXML) else {
            throw FileImportError.corruptFile
        }

        let spine = OPFParser.parseSpine(opfXML)
        print("[EPUB] OPF path: \(opfPath)")
        print("[EPUB] Metadata: title=\(metadata.title), author=\(metadata.author ?? "nil")")
        print("[EPUB] Spine has \(spine.count) documents")

        if spine.isEmpty {
            throw FileImportError.corruptFile
        }

        // Get base path for resolving relative paths in OPF
        let opfBasePath = (opfPath as NSString).deletingLastPathComponent
        let resolvedSpine = spine.map { resolvePath($0, basePath: opfBasePath) }

        // Extract text content from spine documents
        var allText = ""
        var tocEntries: [TOCEntry] = []
        var hasTOC = false

        // Try to parse TOC (prefer NAV over NCX)
        if let navPath = OPFParser.parseNAVPath(opfXML) {
            let resolvedNavPath = resolvePath(navPath, basePath: opfBasePath)
            if let navData = epubContents[resolvedNavPath],
               let navXML = String(data: navData, encoding: .utf8) {
                tocEntries = NAVParser.parse(navXML)
                hasTOC = !tocEntries.isEmpty
            }
        }

        if tocEntries.isEmpty, let ncxPath = OPFParser.parseTOCPath(opfXML) {
            let resolvedNCXPath = resolvePath(ncxPath, basePath: opfBasePath)
            if let ncxData = epubContents[resolvedNCXPath],
               let ncxXML = String(data: ncxData, encoding: .utf8) {
                tocEntries = NCXParser.parse(ncxXML)
                hasTOC = !tocEntries.isEmpty
            }
        }

        // Build chapter mapping: href -> TOCEntry
        var chapterMap: [String: TOCEntry] = [:]
        for entry in tocEntries {
            // Normalize the href for comparison
            let normalizedHref = resolvePath(entry.href, basePath: opfBasePath)
            chapterMap[normalizedHref] = entry
            // Also store without base path for matching
            chapterMap[entry.href] = entry
        }

        // Process each spine document
        var chapters: [Chapter] = []
        var currentWordCount = 0

        for spinePath in resolvedSpine {
            guard let docData = epubContents[spinePath],
                  let docHTML = String(data: docData, encoding: .utf8) else {
                continue
            }

            // Check if this document starts a chapter
            if let tocEntry = chapterMap[spinePath] ?? chapterMap[(spinePath as NSString).lastPathComponent] {
                chapters.append(Chapter(title: tocEntry.title, startWordIndex: currentWordCount))
            }

            // Strip HTML and add to content
            let plainText = HTMLStripper.strip(docHTML)
            if !plainText.isEmpty {
                if !allText.isEmpty {
                    allText += "\n\n"  // Paragraph break between documents
                }
                allText += plainText

                // Count words for next chapter's start index
                let wordCount = plainText.components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                    .count
                currentWordCount += wordCount
            }
        }

        print("[EPUB] Content extraction done: textLength=\(allText.count), chapters=\(chapters.count), wordCount=\(currentWordCount)")

        // Validate we got some content
        guard !allText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FileImportError.emptyFile
        }

        // Extract cover image if available
        var coverData: Data?
        if let coverPath = metadata.coverImagePath {
            let resolvedCoverPath = resolvePath(coverPath, basePath: opfBasePath)
            coverData = epubContents[resolvedCoverPath]
        }

        return EPUBLoadResult(
            content: allText,
            hash: hash,
            metadata: metadata,
            chapters: chapters,
            coverData: coverData,
            hasTOC: hasTOC
        )
    }

    // MARK: - Private Methods

    /// Extract EPUB (ZIP) contents into a dictionary
    private static func extractEPUB(from url: URL) throws -> [String: Data] {
        // EPUB files are ZIP archives - parse them directly
        let fileData = try Data(contentsOf: url)
        return try parseZIP(data: fileData)
    }

    /// Entry from the ZIP Central Directory with reliable file sizes
    private struct ZIPCentralDirectoryEntry {
        let compressionMethod: UInt16
        let compressedSize: UInt32
        let uncompressedSize: UInt32
        let localHeaderOffset: UInt32
    }

    /// Simple ZIP parser for EPUB files
    /// EPUBs use the ZIP format with stored or deflate compression
    private static func parseZIP(data: Data) throws -> [String: Data] {
        var contents: [String: Data] = [:]

        // Parse Central Directory first for reliable sizes.
        // Local headers with data descriptor flag (bit 3) have sizes set to 0,
        // but the Central Directory always has correct values.
        let centralDirectory = parseCentralDirectory(data: data)

        if !centralDirectory.isEmpty {
            let localFileSignature: [UInt8] = [0x50, 0x4b, 0x03, 0x04]

            for (fileName, entry) in centralDirectory {
                guard !fileName.hasSuffix("/") else { continue }

                let localOffset = Int(entry.localHeaderOffset)
                guard localOffset + 30 <= data.count else { continue }

                // Verify local header signature
                let sig = [UInt8](data[localOffset..<localOffset + 4])
                guard sig == localFileSignature else { continue }

                // Read variable-length fields from local header to find data start
                let fileNameLength = Int(UInt16(data[localOffset + 26]) | (UInt16(data[localOffset + 27]) << 8))
                let extraFieldLength = Int(UInt16(data[localOffset + 28]) | (UInt16(data[localOffset + 29]) << 8))

                let dataStart = localOffset + 30 + fileNameLength + extraFieldLength
                let dataEnd = dataStart + Int(entry.compressedSize)

                guard dataEnd <= data.count else { continue }

                let compressedData = data[dataStart..<dataEnd]

                if entry.compressionMethod == 0 {
                    contents[fileName] = Data(compressedData)
                } else if entry.compressionMethod == 8 {
                    if let decompressed = decompressDeflate(Data(compressedData), uncompressedSize: Int(entry.uncompressedSize)) {
                        contents[fileName] = decompressed
                    }
                }
            }
        } else {
            // Fallback: sequential local header parsing for ZIPs without a Central Directory
            var offset = 0
            let localFileSignature: [UInt8] = [0x50, 0x4b, 0x03, 0x04]

            while offset + 30 < data.count {
                let sig = [UInt8](data[offset..<offset + 4])
                guard sig == localFileSignature else { break }

                let compressionMethod = UInt16(data[offset + 8]) | (UInt16(data[offset + 9]) << 8)
                let compressedSize = UInt32(data[offset + 18]) | (UInt32(data[offset + 19]) << 8) | (UInt32(data[offset + 20]) << 16) | (UInt32(data[offset + 21]) << 24)
                let uncompressedSize = UInt32(data[offset + 22]) | (UInt32(data[offset + 23]) << 8) | (UInt32(data[offset + 24]) << 16) | (UInt32(data[offset + 25]) << 24)
                let fileNameLength = UInt16(data[offset + 26]) | (UInt16(data[offset + 27]) << 8)
                let extraFieldLength = UInt16(data[offset + 28]) | (UInt16(data[offset + 29]) << 8)

                let fileNameStart = offset + 30
                let fileNameEnd = fileNameStart + Int(fileNameLength)

                guard fileNameEnd <= data.count else {
                    throw FileImportError.corruptFile
                }

                let fileNameData = data[fileNameStart..<fileNameEnd]
                guard let fileName = String(data: fileNameData, encoding: .utf8) else {
                    offset = fileNameEnd + Int(extraFieldLength) + Int(compressedSize)
                    continue
                }

                let dataStart = fileNameEnd + Int(extraFieldLength)
                let dataEnd = dataStart + Int(compressedSize)

                guard dataEnd <= data.count else {
                    throw FileImportError.corruptFile
                }

                if !fileName.hasSuffix("/") {
                    let compressedData = data[dataStart..<dataEnd]

                    if compressionMethod == 0 {
                        contents[fileName] = Data(compressedData)
                    } else if compressionMethod == 8 {
                        if let decompressed = decompressDeflate(Data(compressedData), uncompressedSize: Int(uncompressedSize)) {
                            contents[fileName] = decompressed
                        }
                    }
                }

                offset = dataEnd
            }
        }

        if contents.isEmpty {
            throw FileImportError.corruptFile
        }

        return contents
    }

    /// Parse the ZIP Central Directory to get reliable file sizes
    private static func parseCentralDirectory(data: Data) -> [String: ZIPCentralDirectoryEntry] {
        var entries: [String: ZIPCentralDirectoryEntry] = [:]

        // Find End of Central Directory record (search backwards)
        // EOCD signature: 0x06054b50 (little-endian: 50 4b 05 06)
        let eocdSignature: [UInt8] = [0x50, 0x4b, 0x05, 0x06]
        let searchStart = max(0, data.count - 65557) // EOCD + max comment size
        var eocdOffset = -1

        for i in stride(from: data.count - 22, through: searchStart, by: -1) {
            guard i + 4 <= data.count else { continue }
            if [UInt8](data[i..<i + 4]) == eocdSignature {
                eocdOffset = i
                break
            }
        }

        guard eocdOffset >= 0, eocdOffset + 22 <= data.count else { return entries }

        let cdOffset = Int(
            UInt32(data[eocdOffset + 16]) |
            (UInt32(data[eocdOffset + 17]) << 8) |
            (UInt32(data[eocdOffset + 18]) << 16) |
            (UInt32(data[eocdOffset + 19]) << 24)
        )

        // Parse Central Directory entries (signature: 0x02014b50)
        let cdSignature: [UInt8] = [0x50, 0x4b, 0x01, 0x02]
        var offset = cdOffset

        while offset + 46 <= data.count {
            let sig = [UInt8](data[offset..<offset + 4])
            guard sig == cdSignature else { break }

            let compressionMethod = UInt16(data[offset + 10]) | (UInt16(data[offset + 11]) << 8)
            let compressedSize = UInt32(data[offset + 20]) | (UInt32(data[offset + 21]) << 8) | (UInt32(data[offset + 22]) << 16) | (UInt32(data[offset + 23]) << 24)
            let uncompressedSize = UInt32(data[offset + 24]) | (UInt32(data[offset + 25]) << 8) | (UInt32(data[offset + 26]) << 16) | (UInt32(data[offset + 27]) << 24)
            let fileNameLength = Int(UInt16(data[offset + 28]) | (UInt16(data[offset + 29]) << 8))
            let extraFieldLength = Int(UInt16(data[offset + 30]) | (UInt16(data[offset + 31]) << 8))
            let fileCommentLength = Int(UInt16(data[offset + 32]) | (UInt16(data[offset + 33]) << 8))
            let localHeaderOffset = UInt32(data[offset + 42]) | (UInt32(data[offset + 43]) << 8) | (UInt32(data[offset + 44]) << 16) | (UInt32(data[offset + 45]) << 24)

            let fileNameStart = offset + 46
            let fileNameEnd = fileNameStart + fileNameLength

            if fileNameEnd <= data.count,
               let fileName = String(data: data[fileNameStart..<fileNameEnd], encoding: .utf8) {
                entries[fileName] = ZIPCentralDirectoryEntry(
                    compressionMethod: compressionMethod,
                    compressedSize: compressedSize,
                    uncompressedSize: uncompressedSize,
                    localHeaderOffset: localHeaderOffset
                )
            }

            offset = fileNameEnd + extraFieldLength + fileCommentLength
        }

        return entries
    }

    /// Decompress deflate-compressed data using Compression framework
    private static func decompressDeflate(_ data: Data, uncompressedSize: Int) -> Data? {
        // Use zlib decompression (raw deflate)
        let bufferSize = max(uncompressedSize, 1024)
        var decompressed = Data(count: bufferSize)

        let result = decompressed.withUnsafeMutableBytes { destBuffer in
            data.withUnsafeBytes { srcBuffer in
                guard let destPtr = destBuffer.bindMemory(to: UInt8.self).baseAddress,
                      let srcPtr = srcBuffer.bindMemory(to: UInt8.self).baseAddress else {
                    return 0
                }
                return compression_decode_buffer(
                    destPtr, bufferSize,
                    srcPtr, data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard result > 0 else { return nil }
        decompressed.count = result
        return decompressed
    }

    /// Parse container.xml to find the OPF file path
    private static func parseContainerForOPF(_ containerXML: String) -> String? {
        // Look for rootfile with media-type="application/oebps-package+xml"
        let pattern = "<rootfile[^>]+full-path=\"([^\"]+)\"[^>]+media-type=\"application/oebps-package\\+xml\"[^>]*/>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: containerXML, options: [], range: NSRange(containerXML.startIndex..., in: containerXML)),
           let pathRange = Range(match.range(at: 1), in: containerXML) {
            return String(containerXML[pathRange])
        }

        // Try with attributes in different order
        let pattern2 = "<rootfile[^>]+media-type=\"application/oebps-package\\+xml\"[^>]+full-path=\"([^\"]+)\"[^>]*/>"
        if let regex = try? NSRegularExpression(pattern: pattern2, options: []),
           let match = regex.firstMatch(in: containerXML, options: [], range: NSRange(containerXML.startIndex..., in: containerXML)),
           let pathRange = Range(match.range(at: 1), in: containerXML) {
            return String(containerXML[pathRange])
        }

        // Simplified fallback: just find any full-path attribute
        let pattern3 = "full-path=\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: pattern3, options: []),
           let match = regex.firstMatch(in: containerXML, options: [], range: NSRange(containerXML.startIndex..., in: containerXML)),
           let pathRange = Range(match.range(at: 1), in: containerXML) {
            return String(containerXML[pathRange])
        }

        return nil
    }

    /// Resolve a relative path against a base path
    private static func resolvePath(_ path: String, basePath: String) -> String {
        if basePath.isEmpty || path.hasPrefix("/") {
            return path
        }

        // Handle ../ in path
        var components = basePath.components(separatedBy: "/")
        let pathComponents = path.components(separatedBy: "/")

        for component in pathComponents {
            if component == ".." {
                if !components.isEmpty {
                    components.removeLast()
                }
            } else if component != "." && !component.isEmpty {
                components.append(component)
            }
        }

        return components.joined(separator: "/")
    }

    private static func calculateHash(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - FileImportService Extension

extension FileImportService {
    /// Load an EPUB file
    /// - Parameter url: The URL of the EPUB file
    /// - Returns: FileLoadResult with content and hash
    /// - Throws: FileImportError if the file cannot be loaded
    static func loadEPUBFile(from url: URL) throws -> (result: FileLoadResult, chapters: [Chapter], metadata: EPUBMetadata, coverData: Data?, hasTOC: Bool) {
        let epubResult = try EPUBImportService.loadEPUB(from: url)
        let fileResult = FileLoadResult(content: epubResult.content, hash: epubResult.hash)
        return (fileResult, epubResult.chapters, epubResult.metadata, epubResult.coverData, epubResult.hasTOC)
    }
}
