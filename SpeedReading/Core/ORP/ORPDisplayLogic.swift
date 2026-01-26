import Foundation

/// Business logic for the ORP Display component
enum ORPDisplayLogic {
    /// Represents a word chunk for display
    struct DisplayChunk: Equatable {
        let text: String
        let orpIndex: Int

        /// Parts of the chunk for display
        var parts: (before: String, orp: String, after: String) {
            ORPDisplayLogic.splitWord(text, orpIndex: orpIndex)
        }
    }

    /// Splits a word into three parts: before ORP, ORP character, after ORP
    static func splitWord(_ word: String, orpIndex: Int) -> (before: String, orp: String, after: String) {
        guard !word.isEmpty else {
            return ("", "", "")
        }

        let clampedIndex = max(0, min(orpIndex, word.count - 1))
        let orpCharIndex = word.index(word.startIndex, offsetBy: clampedIndex)

        let before = String(word[..<orpCharIndex])
        let orp = String(word[orpCharIndex])
        let after = String(word[word.index(after: orpCharIndex)...])

        return (before, orp, after)
    }

    /// Calculates the horizontal offset needed to center the ORP character.
    /// Returns the offset in terms of character widths (for monospace font).
    /// Negative value means shift left, positive means shift right.
    static func calculateCenteringOffset(wordLength: Int, orpIndex: Int) -> Double {
        // For a word at position [0, 1, 2, ..., n-1], the ORP is at position orpIndex.
        // We want the ORP character to be at the horizontal center.
        // The offset shifts the word so the ORP character's center aligns with screen center.
        return -Double(orpIndex) - 0.5
    }

    /// Determines if a word needs to be chunked based on available width.
    /// Returns an array of chunks with their ORP indices.
    static func chunkWord(_ word: String, maxCharacters: Int) -> [DisplayChunk] {
        guard maxCharacters > 0 else { return [] }
        guard word.count > maxCharacters else {
            return [DisplayChunk(text: word, orpIndex: ORPCalculator.calculateORPIndex(for: word))]
        }

        var chunks: [DisplayChunk] = []
        var remaining = word

        while !remaining.isEmpty {
            let chunkLength = min(remaining.count, maxCharacters)
            let endIndex = remaining.index(remaining.startIndex, offsetBy: chunkLength)
            let chunk = String(remaining[..<endIndex])
            let orpIndex = ORPCalculator.calculateORPIndex(for: chunk)
            chunks.append(DisplayChunk(text: chunk, orpIndex: orpIndex))
            remaining = String(remaining[endIndex...])
        }

        return chunks
    }

    /// Calculates delay per chunk when a word is split into multiple display chunks.
    static func chunkDelay(totalWordDelay: TimeInterval, chunkCount: Int) -> TimeInterval {
        guard chunkCount > 0 else { return totalWordDelay }
        return totalWordDelay / Double(chunkCount)
    }

    /// Calculates the number of characters that can fit given available width and character width.
    static func maxCharacters(forWidth availableWidth: CGFloat, characterWidth: CGFloat) -> Int {
        guard characterWidth > 0 else { return Int.max }
        return max(1, Int(availableWidth / characterWidth))
    }
}
