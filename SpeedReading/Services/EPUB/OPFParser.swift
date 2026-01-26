import Foundation

/// Parsed EPUB metadata from OPF file
struct EPUBMetadata {
    let title: String
    let author: String?
    let coverImagePath: String?
}

/// Parses EPUB OPF (Open Packaging Format) files for metadata and spine order.
enum OPFParser {
    // MARK: - Public Methods

    /// Parse metadata from OPF content
    /// - Parameter opf: The OPF XML content
    /// - Returns: EPUBMetadata if title is found, nil otherwise
    static func parseMetadata(_ opf: String) -> EPUBMetadata? {
        // Parse title (required)
        guard let title = extractDCElement(opf, element: "title") else {
            return nil
        }

        // Parse author (optional)
        let author = extractDCElement(opf, element: "creator")

        // Parse cover image path
        let coverPath = extractCoverImagePath(opf)

        return EPUBMetadata(title: title, author: author, coverImagePath: coverPath)
    }

    /// Parse spine (reading order) from OPF content
    /// - Parameter opf: The OPF XML content
    /// - Returns: Array of file paths in reading order
    static func parseSpine(_ opf: String) -> [String] {
        // First, build a manifest map (id -> href)
        let manifest = parseManifest(opf)

        // Then, parse spine and resolve idrefs to hrefs
        var spine: [String] = []

        // Match itemref elements
        let itemrefPattern = "<itemref[^>]+idref=\"([^\"]+)\"[^>]*/?>"
        guard let regex = try? NSRegularExpression(pattern: itemrefPattern, options: []) else {
            return spine
        }

        let matches = regex.matches(in: opf, options: [], range: NSRange(opf.startIndex..., in: opf))
        for match in matches {
            if let idrefRange = Range(match.range(at: 1), in: opf) {
                let idref = String(opf[idrefRange])
                if let href = manifest[idref] {
                    spine.append(href)
                }
            }
        }

        return spine
    }

    /// Get the path to the TOC NCX file if present
    /// - Parameter opf: The OPF XML content
    /// - Returns: Path to NCX file, or nil if not found
    static func parseTOCPath(_ opf: String) -> String? {
        let manifest = parseManifest(opf)

        // Look for toc attribute in spine element
        if let tocMatch = opf.range(of: "<spine[^>]+toc=\"([^\"]+)\"", options: .regularExpression) {
            let tocContent = opf[tocMatch]
            if let start = tocContent.range(of: "toc=\"")?.upperBound {
                let remaining = tocContent[start...]
                if let end = remaining.range(of: "\"")?.lowerBound {
                    let tocId = String(remaining[..<end])
                    return manifest[tocId]
                }
            }
        }

        // Fallback: look for NCX media type in manifest
        for (id, href) in manifest {
            // Check if this item has NCX media type
            let pattern = "<item[^>]+id=\"\(id)\"[^>]+media-type=\"application/x-dtbncx\\+xml\"[^>]*/?>"
            if opf.range(of: pattern, options: .regularExpression) != nil {
                return href
            }
            // Also check reversed attribute order
            let pattern2 = "<item[^>]+media-type=\"application/x-dtbncx\\+xml\"[^>]+id=\"\(id)\"[^>]*/?>"
            if opf.range(of: pattern2, options: .regularExpression) != nil {
                return href
            }
        }

        return nil
    }

    /// Get the path to the NAV document (EPUB 3) if present
    /// - Parameter opf: The OPF XML content
    /// - Returns: Path to NAV document, or nil if not found
    static func parseNAVPath(_ opf: String) -> String? {
        // Look for nav property in manifest
        let pattern = "<item[^>]+properties=\"[^\"]*nav[^\"]*\"[^>]+href=\"([^\"]+)\"[^>]*/?>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: opf, options: [], range: NSRange(opf.startIndex..., in: opf)),
           let hrefRange = Range(match.range(at: 1), in: opf) {
            return String(opf[hrefRange])
        }

        // Try reversed attribute order
        let pattern2 = "<item[^>]+href=\"([^\"]+)\"[^>]+properties=\"[^\"]*nav[^\"]*\"[^>]*/?>"
        if let regex = try? NSRegularExpression(pattern: pattern2, options: []),
           let match = regex.firstMatch(in: opf, options: [], range: NSRange(opf.startIndex..., in: opf)),
           let hrefRange = Range(match.range(at: 1), in: opf) {
            return String(opf[hrefRange])
        }

        return nil
    }

    // MARK: - Private Methods

    private static func extractDCElement(_ opf: String, element: String) -> String? {
        // Try with namespace prefix
        let pattern1 = "<dc:\(element)[^>]*>([^<]+)</dc:\(element)>"
        if let regex = try? NSRegularExpression(pattern: pattern1, options: .caseInsensitive),
           let match = regex.firstMatch(in: opf, options: [], range: NSRange(opf.startIndex..., in: opf)),
           let valueRange = Range(match.range(at: 1), in: opf) {
            return String(opf[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try without namespace prefix (some EPUBs use default namespace)
        let pattern2 = "<\(element)[^>]*>([^<]+)</\(element)>"
        if let regex = try? NSRegularExpression(pattern: pattern2, options: .caseInsensitive),
           let match = regex.firstMatch(in: opf, options: [], range: NSRange(opf.startIndex..., in: opf)),
           let valueRange = Range(match.range(at: 1), in: opf) {
            return String(opf[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    private static func extractCoverImagePath(_ opf: String) -> String? {
        let manifest = parseManifest(opf)

        // Method 1: meta name="cover" content="[item-id]"
        let metaPattern = "name=\"cover\"\\s+content=\"([^\"]+)\"|content=\"([^\"]+)\"\\s+name=\"cover\""
        if let regex = try? NSRegularExpression(pattern: metaPattern, options: []),
           let match = regex.firstMatch(in: opf, options: [], range: NSRange(opf.startIndex..., in: opf)) {
            for i in 1...2 {
                if let range = Range(match.range(at: i), in: opf), match.range(at: i).location != NSNotFound {
                    let coverId = String(opf[range])
                    if let href = manifest[coverId] {
                        return href
                    }
                }
            }
        }

        // Method 2: Look for item with cover-image property (EPUB 3)
        let coverPattern = "<item[^>]+properties=\"[^\"]*cover-image[^\"]*\"[^>]+href=\"([^\"]+)\"[^>]*/?>"
        if let regex = try? NSRegularExpression(pattern: coverPattern, options: []),
           let match = regex.firstMatch(in: opf, options: [], range: NSRange(opf.startIndex..., in: opf)),
           let hrefRange = Range(match.range(at: 1), in: opf) {
            return String(opf[hrefRange])
        }

        // Method 3: Look for item with id containing "cover" and image media type
        for (id, href) in manifest {
            if id.lowercased().contains("cover") &&
               (href.lowercased().hasSuffix(".jpg") ||
                href.lowercased().hasSuffix(".jpeg") ||
                href.lowercased().hasSuffix(".png") ||
                href.lowercased().hasSuffix(".gif")) {
                return href
            }
        }

        return nil
    }

    private static func parseManifest(_ opf: String) -> [String: String] {
        var manifest: [String: String] = [:]

        // Match item elements with id and href
        let itemPattern = "<item[^>]+>"
        guard let regex = try? NSRegularExpression(pattern: itemPattern, options: []) else {
            return manifest
        }

        let matches = regex.matches(in: opf, options: [], range: NSRange(opf.startIndex..., in: opf))
        for match in matches {
            guard let itemRange = Range(match.range, in: opf) else { continue }
            let item = String(opf[itemRange])

            var id: String?
            var href: String?

            // Extract id
            if let idMatch = item.range(of: "id=\"([^\"]+)\"", options: .regularExpression) {
                let idContent = item[idMatch]
                if let start = idContent.range(of: "\"")?.upperBound {
                    let remaining = idContent[start...]
                    if let end = remaining.range(of: "\"")?.lowerBound {
                        id = String(remaining[..<end])
                    }
                }
            }

            // Extract href
            if let hrefMatch = item.range(of: "href=\"([^\"]+)\"", options: .regularExpression) {
                let hrefContent = item[hrefMatch]
                if let start = hrefContent.range(of: "\"")?.upperBound {
                    let remaining = hrefContent[start...]
                    if let end = remaining.range(of: "\"")?.lowerBound {
                        href = String(remaining[..<end])
                    }
                }
            }

            if let i = id, let h = href {
                manifest[i] = h
            }
        }

        return manifest
    }
}
