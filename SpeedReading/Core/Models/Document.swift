import Foundation

/// Represents a tokenized document ready for playback
struct Document {
    /// All words in reading order
    let words: [Word]

    /// Chapters from EPUB TOC (nil for txt/md)
    let chapters: [Chapter]?

    /// Total number of words in the document
    var totalWords: Int {
        words.count
    }

    init(words: [Word], chapters: [Chapter]? = nil) {
        self.words = words
        self.chapters = chapters
    }
}
