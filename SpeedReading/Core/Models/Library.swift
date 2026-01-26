import Foundation

/// Root data model for the library.json file
struct Library: Codable {
    /// All imported books
    var books: [Book]

    /// Global app settings
    var settings: Settings

    init(books: [Book] = [], settings: Settings = Settings()) {
        self.books = books
        self.settings = settings
    }
}
