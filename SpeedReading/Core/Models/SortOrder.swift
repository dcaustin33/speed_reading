import Foundation

/// Library sorting options
enum SortOrder: String, Codable, Hashable, CaseIterable {
    /// Sort by most recently opened (most recent first)
    case recent

    /// Sort alphabetically by title (A-Z)
    case title
}
