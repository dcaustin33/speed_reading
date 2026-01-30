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
        // The HStack is already centered in the ZStack, so the word's midpoint
        // is at the screen center. We need to shift so the ORP character's center
        // lands at screen center instead.
        //
        // Word midpoint is at wordLength/2 chars from left edge.
        // ORP character center is at (orpIndex + 0.5) chars from left edge.
        // Shift = midpoint - orpCenter = wordLength/2 - orpIndex - 0.5
        let wordCenter = Double(wordLength) / 2.0
        return wordCenter - Double(orpIndex) - 0.5
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
