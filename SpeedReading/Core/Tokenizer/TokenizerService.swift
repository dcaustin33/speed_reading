import Foundation

/// Service for tokenizing text into Words with ORP indices and boundary flags.
enum TokenizerService {
    // Known abbreviations that don't end sentences
    private static let abbreviations: Set<String> = [
        "dr.", "mr.", "mrs.", "ms.", "jr.", "sr.", "prof.", "gen.", "vs.",
        "etc.", "inc.", "ltd.", "corp.", "co.", "dept.",
        "e.g.", "i.e.", "a.m.", "p.m.",
        "u.s.", "u.k.",
        "st.", "ave.", "blvd.", "rd.", "apt.",
        "no.", "vol.", "pg.", "pp.", "fig.",
        "jan.", "feb.", "mar.", "apr.", "jun.", "jul.", "aug.", "sep.", "sept.", "oct.", "nov.", "dec.",
        "mon.", "tue.", "wed.", "thu.", "fri.", "sat.", "sun."
    ]

    /// Tokenizes text into a Document with Words.
    ///
    /// - Parameter text: The source text to tokenize
    /// - Parameter chapters: Optional chapters for EPUB content
    /// - Returns: A Document containing all words with ORP indices and boundary flags
    static func tokenize(text: String, chapters: [Chapter]? = nil) -> Document {
        // Normalize line endings: \r\n -> \n, \r -> \n
        var normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        normalized = normalized.replacingOccurrences(of: "\r", with: "\n")

        // Split into paragraphs (one or more blank lines)
        let paragraphs = normalized.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var allWords: [Word] = []

        for (paragraphIndex, paragraph) in paragraphs.enumerated() {
            let isLastParagraph = paragraphIndex == paragraphs.count - 1

            // Split paragraph into raw word tokens
            let rawTokens = paragraph
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }

            // Process tokens (split hyphenated words)
            var tokens: [String] = []
            for token in rawTokens {
                let hyphenSplit = splitHyphenatedWord(token)
                tokens.append(contentsOf: hyphenSplit)
            }

            for (tokenIndex, token) in tokens.enumerated() {
                let isLastInParagraph = tokenIndex == tokens.count - 1
                let sentenceEnd = isSentenceEnd(token, isLastWord: isLastInParagraph)
                let paragraphEnd = isLastInParagraph && !isLastParagraph

                // Determine chapter index if chapters are provided
                let chapterIndex = findChapterIndex(
                    wordIndex: allWords.count,
                    chapters: chapters
                )

                let word = Word(
                    text: token,
                    orpIndex: ORPCalculator.calculateORPIndex(for: token),
                    sentenceEnd: sentenceEnd,
                    paragraphEnd: paragraphEnd,
                    chapterIndex: chapterIndex
                )
                allWords.append(word)
            }
        }

        // Mark the very last word as paragraph end too
        if !allWords.isEmpty {
            let lastWord = allWords.removeLast()
            allWords.append(Word(
                text: lastWord.text,
                orpIndex: lastWord.orpIndex,
                sentenceEnd: lastWord.sentenceEnd,
                paragraphEnd: true,
                chapterIndex: lastWord.chapterIndex
            ))
        }

        return Document(words: allWords, chapters: chapters)
    }

    /// Finds the chapter index for a given word position.
    private static func findChapterIndex(wordIndex: Int, chapters: [Chapter]?) -> Int? {
        guard let chapters = chapters, !chapters.isEmpty else { return nil }

        // Find the last chapter that starts at or before this word index
        var chapterIndex: Int? = nil
        for (index, chapter) in chapters.enumerated() {
            if chapter.startWordIndex <= wordIndex {
                chapterIndex = index
            } else {
                break
            }
        }
        return chapterIndex
    }

    /// Splits hyphenated words into separate tokens.
    /// "state-of-the-art" -> ["state", "of", "the", "art"]
    private static func splitHyphenatedWord(_ word: String) -> [String] {
        guard word.contains("-") else { return [word] }

        let parts = word.split(separator: "-", omittingEmptySubsequences: false)

        // If splitting produces empty parts (dash at start/end), keep original
        if parts.contains(where: { $0.isEmpty }) {
            return [word]
        }

        return parts.map { String($0) }
    }

    /// Determines if a word ends a sentence.
    private static func isSentenceEnd(_ word: String, isLastWord: Bool) -> Bool {
        // Strip surrounding quotes/brackets for checking
        let stripped = stripQuotesAndBrackets(word)

        // Check if ends with sentence-ending punctuation
        guard stripped.hasSuffix(".") || stripped.hasSuffix("!") || stripped.hasSuffix("?") else {
            return false
        }

        // Ellipsis is not a sentence end
        if stripped.hasSuffix("...") {
            return false
        }

        // Check if it's an abbreviation
        if abbreviations.contains(stripped.lowercased()) {
            return false
        }

        // Check for single letter + period (initial) - not sentence end unless last word
        if isSingleLetterInitial(stripped) && !isLastWord {
            return false
        }

        return true
    }

    /// Strips surrounding quotes and brackets from a word for punctuation checking.
    private static func stripQuotesAndBrackets(_ word: String) -> String {
        var result = word

        // Opening characters
        let openings = Set<Character>([
            Character("\""),
            Character("'"),
            Character("\u{2018}"), // '
            Character("\u{201C}"), // "
            Character("("),
            Character("["),
            Character("{")
        ])
        while let first = result.first, openings.contains(first) {
            result.removeFirst()
        }

        // Closing characters (strip from end, but keep sentence-ending punctuation)
        let closings = Set<Character>([
            Character("\""),
            Character("'"),
            Character("\u{2019}"), // '
            Character("\u{201D}"), // "
            Character(")"),
            Character("]"),
            Character("}")
        ])
        while result.count > 1,
              let last = result.last,
              closings.contains(last) {
            result.removeLast()
        }

        return result
    }

    /// Checks if word is a single letter initial (e.g., "J." or "A.")
    private static func isSingleLetterInitial(_ word: String) -> Bool {
        guard word.count == 2 else { return false }
        guard word.hasSuffix(".") else { return false }
        guard let firstChar = word.first else { return false }
        return firstChar.isLetter
    }
}
