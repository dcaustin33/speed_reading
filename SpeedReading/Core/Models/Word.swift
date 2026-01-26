import Foundation

/// Represents a single word token in a document
struct Word: Equatable, Hashable {
    /// The word text (with attached punctuation)
    let text: String

    /// Index of the ORP (Optimal Recognition Point) character (0-based)
    let orpIndex: Int

    /// Whether this word ends a sentence
    let sentenceEnd: Bool

    /// Whether this word ends a paragraph
    let paragraphEnd: Bool

    /// Chapter index this word belongs to (EPUB only)
    let chapterIndex: Int?

    init(
        text: String,
        orpIndex: Int,
        sentenceEnd: Bool = false,
        paragraphEnd: Bool = false,
        chapterIndex: Int? = nil
    ) {
        self.text = text
        self.orpIndex = orpIndex
        self.sentenceEnd = sentenceEnd
        self.paragraphEnd = paragraphEnd
        self.chapterIndex = chapterIndex
    }
}
