import Foundation

/// Represents a table of contents entry
struct TOCEntry {
    let title: String
    let href: String
    let level: Int  // Nesting level (0 = top level)

    init(title: String, href: String, level: Int = 0) {
        self.title = title
        self.href = href
        self.level = level
    }
}

/// Parses EPUB 2 NCX (Navigation Control file for XML applications) documents
enum NCXParser {
    /// Parse NCX document for TOC entries
    /// - Parameter ncx: The NCX XML content
    /// - Returns: Array of TOCEntry in reading order
    static func parse(_ ncx: String) -> [TOCEntry] {
        var entries: [TOCEntry] = []
        parseNavPoints(ncx, entries: &entries, level: 0)
        return entries
    }

    // MARK: - Private Methods

    private static func parseNavPoints(_ content: String, entries: inout [TOCEntry], level: Int) {
        // Find navPoint elements at current level
        // This is simplified - for deeply nested structures, a proper XML parser would be better
        let pattern = "<navPoint[^>]*>[\\s\\S]*?<navLabel>\\s*<text>([^<]+)</text>\\s*</navLabel>\\s*<content\\s+src=\"([^\"]+)\"[^>]*/>"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return
        }

        let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))

        for match in matches {
            guard let titleRange = Range(match.range(at: 1), in: content),
                  let hrefRange = Range(match.range(at: 2), in: content) else {
                continue
            }

            let title = String(content[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            var href = String(content[hrefRange])

            // Remove fragment identifier for now (we'll map to word indices later)
            if let hashIndex = href.firstIndex(of: "#") {
                href = String(href[..<hashIndex])
            }

            entries.append(TOCEntry(title: title, href: href, level: level))
        }

        // If the simple pattern didn't match, try a more flexible approach
        if entries.isEmpty {
            parseNavPointsFlexible(content, entries: &entries, level: level)
        }
    }

    private static func parseNavPointsFlexible(_ content: String, entries: inout [TOCEntry], level: Int) {
        // Find navLabel/text and content src pairs
        let navPointPattern = "<navPoint[^>]*>([\\s\\S]*?)</navPoint>"

        guard let regex = try? NSRegularExpression(pattern: navPointPattern, options: []) else {
            return
        }

        let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))

        for match in matches {
            guard let navPointRange = Range(match.range(at: 1), in: content) else {
                continue
            }

            let navPointContent = String(content[navPointRange])

            // Extract title from <text> element
            var title: String?
            if let textMatch = navPointContent.range(of: "<text>([^<]+)</text>", options: .regularExpression) {
                let textContent = navPointContent[textMatch]
                if let start = textContent.range(of: ">")?.upperBound,
                   let end = textContent.range(of: "</")?.lowerBound {
                    title = String(textContent[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            // Extract href from <content src="..."/>
            var href: String?
            if let srcMatch = navPointContent.range(of: "src=\"([^\"]+)\"", options: .regularExpression) {
                let srcContent = navPointContent[srcMatch]
                if let start = srcContent.range(of: "\"")?.upperBound {
                    let remaining = srcContent[start...]
                    if let end = remaining.range(of: "\"")?.lowerBound {
                        href = String(remaining[..<end])
                    }
                }
            }

            if let t = title, var h = href {
                // Remove fragment identifier
                if let hashIndex = h.firstIndex(of: "#") {
                    h = String(h[..<hashIndex])
                }
                entries.append(TOCEntry(title: t, href: h, level: level))
            }
        }
    }
}

/// Parses EPUB 3 NAV (Navigation Document) HTML files
enum NAVParser {
    /// Parse NAV document for TOC entries
    /// - Parameter nav: The NAV HTML content
    /// - Returns: Array of TOCEntry in reading order
    static func parse(_ nav: String) -> [TOCEntry] {
        var entries: [TOCEntry] = []

        // Find the nav element with epub:type="toc"
        let navPattern = "<nav[^>]*epub:type=\"[^\"]*toc[^\"]*\"[^>]*>([\\s\\S]*?)</nav>"

        guard let regex = try? NSRegularExpression(pattern: navPattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: nav, options: [], range: NSRange(nav.startIndex..., in: nav)),
              let tocRange = Range(match.range(at: 1), in: nav) else {
            // Try without namespace
            return parseWithoutNamespace(nav)
        }

        let tocContent = String(nav[tocRange])
        parseOLEntries(tocContent, entries: &entries, level: 0)

        return entries
    }

    // MARK: - Private Methods

    private static func parseWithoutNamespace(_ nav: String) -> [TOCEntry] {
        var entries: [TOCEntry] = []

        // Look for any nav element containing "toc" in type
        let navPattern = "<nav[^>]*type=\"[^\"]*toc[^\"]*\"[^>]*>([\\s\\S]*?)</nav>"

        if let regex = try? NSRegularExpression(pattern: navPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: nav, options: [], range: NSRange(nav.startIndex..., in: nav)),
           let tocRange = Range(match.range(at: 1), in: nav) {
            let tocContent = String(nav[tocRange])
            parseOLEntries(tocContent, entries: &entries, level: 0)
        }

        // Fallback: just find all anchors in OL/LI structure
        if entries.isEmpty {
            parseAnchors(nav, entries: &entries)
        }

        return entries
    }

    private static func parseOLEntries(_ content: String, entries: inout [TOCEntry], level: Int) {
        // Find <a href="...">title</a> patterns within the content
        let anchorPattern = "<a[^>]+href=\"([^\"]+)\"[^>]*>([^<]+)</a>"

        guard let regex = try? NSRegularExpression(pattern: anchorPattern, options: []) else {
            return
        }

        let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))

        for match in matches {
            guard let hrefRange = Range(match.range(at: 1), in: content),
                  let titleRange = Range(match.range(at: 2), in: content) else {
                continue
            }

            var href = String(content[hrefRange])
            let title = String(content[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            // Remove fragment identifier
            if let hashIndex = href.firstIndex(of: "#") {
                href = String(href[..<hashIndex])
            }

            if !title.isEmpty && !href.isEmpty {
                entries.append(TOCEntry(title: title, href: href, level: level))
            }
        }
    }

    private static func parseAnchors(_ nav: String, entries: inout [TOCEntry]) {
        // Simple fallback: find all anchors with href
        let anchorPattern = "<a[^>]+href=\"([^\"]+)\"[^>]*>([^<]+)</a>"

        guard let regex = try? NSRegularExpression(pattern: anchorPattern, options: []) else {
            return
        }

        let matches = regex.matches(in: nav, options: [], range: NSRange(nav.startIndex..., in: nav))

        for match in matches {
            guard let hrefRange = Range(match.range(at: 1), in: nav),
                  let titleRange = Range(match.range(at: 2), in: nav) else {
                continue
            }

            var href = String(nav[hrefRange])
            let title = String(nav[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            // Remove fragment identifier
            if let hashIndex = href.firstIndex(of: "#") {
                href = String(href[..<hashIndex])
            }

            if !title.isEmpty && !href.isEmpty {
                entries.append(TOCEntry(title: title, href: href, level: 0))
            }
        }
    }
}
