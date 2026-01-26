import Foundation

/// Service for searching within a book's content.
/// Per spec Section 6.5: Case-insensitive exact word sequence match.
enum SearchService {
    /// Maximum number of results to return
    static let maxResults = 50

    /// Number of words to include before and after match for context
    static let contextWords = 5

    /// Search result container with pagination info
    struct SearchOutput {
        let results: [SearchResult]
        let hasMore: Bool
    }

    /// Searches for a query phrase in a document.
    /// - Parameters:
    ///   - query: The search phrase (can be multiple words)
    ///   - document: The document to search in
    /// - Returns: SearchOutput with results (maximum 50) and hasMore flag
    static func search(query: String, in document: Document) -> SearchOutput {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        guard !trimmedQuery.isEmpty else { return SearchOutput(results: [], hasMore: false) }

        // Split query into words
        let queryWords = trimmedQuery
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }

        guard !queryWords.isEmpty else { return SearchOutput(results: [], hasMore: false) }

        var results: [SearchResult] = []
        var hasMore = false
        let words = document.words
        let totalWords = document.totalWords

        var i = 0
        while i < totalWords {
            // Check for result limit
            if results.count >= maxResults {
                // Check if there are more matches
                while i < totalWords {
                    if matchesAt(index: i, queryWords: queryWords, in: words) {
                        hasMore = true
                        break
                    }
                    i += 1
                }
                break
            }

            // Check if query matches starting at this position
            if matchesAt(index: i, queryWords: queryWords, in: words) {
                let context = buildContext(
                    startIndex: i,
                    matchLength: queryWords.count,
                    in: words
                )

                let percentage = totalWords > 0
                    ? (Double(i) / Double(totalWords)) * 100
                    : 0

                let result = SearchResult(
                    wordIndex: i,
                    context: context,
                    percentage: percentage
                )
                results.append(result)
            }

            i += 1
        }

        return SearchOutput(results: results, hasMore: hasMore)
    }

    /// Checks if query words match document starting at given index.
    /// Per spec: case-insensitive but otherwise strict (no stemming, no fuzzy matching).
    /// "walk" matches "Walk" but NOT "walking" or "walked"
    private static func matchesAt(index: Int, queryWords: [String], in words: [Word]) -> Bool {
        for j in 0..<queryWords.count {
            let wordIndex = index + j
            if wordIndex >= words.count { return false }

            // Case-insensitive comparison of the full word text
            if words[wordIndex].text.lowercased() != queryWords[j] {
                return false
            }
        }
        return true
    }

    /// Builds context string with ~5 words before and after match.
    /// The matched phrase is highlighted with ** markers.
    private static func buildContext(startIndex: Int, matchLength: Int, in words: [Word]) -> String {
        let totalWords = words.count

        // Calculate context range
        let contextBefore = max(0, startIndex - contextWords)
        let endOfMatch = startIndex + matchLength - 1
        let contextAfter = min(totalWords - 1, endOfMatch + contextWords)

        // Build context string
        var contextParts: [String] = []

        // Add "..." if there are words before the context
        if contextBefore > 0 {
            contextParts.append("...")
        }

        // Add words with match highlighted using ** markers
        for i in contextBefore...contextAfter {
            let wordText = words[i].text

            if i == startIndex {
                // Start of match
                contextParts.append("**" + wordText)
            } else if i == endOfMatch {
                // End of match
                contextParts.append(wordText + "**")
            } else if i > startIndex && i < endOfMatch {
                // Middle of match (for multi-word queries)
                contextParts.append(wordText)
            } else {
                // Context word (not part of match)
                contextParts.append(wordText)
            }
        }

        // Add "..." if there are words after the context
        if contextAfter < totalWords - 1 {
            contextParts.append("...")
        }

        // Handle single-word matches (start and end markers on same word)
        var result = contextParts.joined(separator: " ")
        if matchLength == 1 {
            // For single word match, close the ** on the same word
            let matchWord = words[startIndex].text
            result = result.replacingOccurrences(
                of: "**\(matchWord)",
                with: "**\(matchWord)**"
            )
        }

        return result
    }
}
