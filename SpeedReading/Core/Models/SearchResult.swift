import Foundation

/// Represents a search result within a book
struct SearchResult: Identifiable, Equatable, Hashable {
    /// Unique ID for SwiftUI lists
    let id = UUID()

    /// Word index where the match starts
    let wordIndex: Int

    /// Context string with surrounding words
    let context: String

    /// Position in book as percentage (0-100)
    let percentage: Double

    init(wordIndex: Int, context: String, percentage: Double) {
        self.wordIndex = wordIndex
        self.context = context
        self.percentage = percentage
    }
}
