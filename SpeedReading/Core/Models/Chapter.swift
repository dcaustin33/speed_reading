import Foundation

/// Represents a chapter in an EPUB document
struct Chapter: Equatable, Hashable, Codable {
    /// Chapter title from TOC
    let title: String

    /// Word index where this chapter starts
    let startWordIndex: Int

    init(title: String, startWordIndex: Int) {
        self.title = title
        self.startWordIndex = startWordIndex
    }
}
