import Foundation
import CryptoKit

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
        var contents: [String: Data] = [:]

        // Use Foundation's ZIP support via FileWrapper for reading
        // Note: This is a simplified extraction - for production, consider using ZIPFoundation
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer {
                try? FileManager.default.removeItem(at: tempDir)
            }

            // Use Process to unzip (available on iOS via Simulator, but not on device)
            // For actual iOS deployment, we'd use a ZIP library
            #if targetEnvironment(simulator) || os(macOS)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-q", "-o", url.path, "-d", tempDir.path]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                throw FileImportError.corruptFile
            }

            // Read all extracted files
            contents = try readDirectory(tempDir, basePath: "")
            #else
            // On actual iOS device, use built-in ZIP reading
            contents = try extractEPUBUsingFoundation(from: url)
            #endif

        } catch let error as FileImportError {
            throw error
        } catch {
            throw FileImportError.corruptFile
        }

        return contents
    }

    /// Read directory contents recursively
    private static func readDirectory(_ directory: URL, basePath: String) throws -> [String: Data] {
        var contents: [String: Data] = [:]

        let fileManager = FileManager.default
        let items = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey])

        for item in items {
            let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey])
            let relativePath = basePath.isEmpty ? item.lastPathComponent : basePath + "/" + item.lastPathComponent

            if resourceValues.isDirectory == true {
                let subContents = try readDirectory(item, basePath: relativePath)
                contents.merge(subContents) { $1 }
            } else {
                contents[relativePath] = try Data(contentsOf: item)
            }
        }

        return contents
    }

    /// Extract EPUB using Foundation's Archive support (iOS 16+)
    private static func extractEPUBUsingFoundation(from url: URL) throws -> [String: Data] {
        // For iOS devices, we need to use the Archive framework or a third-party ZIP library
        // This is a placeholder - in a real implementation, you would:
        // 1. Use Apple's Compression framework with custom ZIP handling
        // 2. Or use a library like ZIPFoundation

        // For now, try to read as-is if it's already extracted
        // or throw an error indicating we need native ZIP support
        throw FileImportError.readError("Native EPUB extraction requires ZIPFoundation or similar library")
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
