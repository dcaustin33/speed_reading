import Foundation

/// Calculates the Optimal Recognition Point (ORP) for words.
/// The ORP is the character position where the eye naturally focuses when reading a word.
enum ORPCalculator {
    /// Calculates the ORP index (0-based) for a given word.
    ///
    /// ORP Position Lookup Table:
    /// - 1 character: index 0
    /// - 2-5 characters: index 1
    /// - 6-9 characters: index 2
    /// - 10-13 characters: index 3
    /// - 14+ characters: index 4
    ///
    /// - Parameter word: The word to calculate ORP for
    /// - Returns: The 0-based index of the ORP character
    static func calculateORPIndex(for word: String) -> Int {
        let length = word.count

        switch length {
        case 0:
            return 0
        case 1:
            return 0
        case 2...5:
            return 1
        case 6...9:
            return 2
        case 10...13:
            return 3
        default: // 14+
            return 4
        }
    }
}
