import Foundation

/// View model for the Settings screen.
/// Manages font size and word skip settings with immediate persistence.
/// All settings are global (apply to all books) per spec.
@Observable
@MainActor
class SettingsViewModel {
    // MARK: - Dependencies

    private let libraryDataService: LibraryDataService

    // MARK: - State

    /// Font size for ORP display (24-96pt)
    var fontSize: Double {
        didSet {
            saveFontSize()
        }
    }

    /// Word skip amount for navigation buttons (1-20)
    var wordSkip: Double {
        didSet {
            saveWordSkip()
        }
    }

    // MARK: - Formatted Values

    /// Font size formatted for display (e.g., "48pt")
    var fontSizeFormatted: String {
        "\(Int(fontSize))pt"
    }

    /// Word skip formatted for display (e.g., "5 words")
    var wordSkipFormatted: String {
        let count = Int(wordSkip)
        return count == 1 ? "1 word" : "\(count) words"
    }

    // MARK: - Initialization

    init(libraryDataService: LibraryDataService = LibraryDataService()) {
        self.libraryDataService = libraryDataService

        // Load library to ensure we have current settings
        try? libraryDataService.loadLibrary()

        // Load current settings
        self.fontSize = Double(libraryDataService.settings.fontSize)
        self.wordSkip = Double(libraryDataService.settings.wordSkip)
    }

    // MARK: - Persistence

    private func saveFontSize() {
        var settings = libraryDataService.settings
        settings.fontSize = Int(fontSize)
        libraryDataService.settings = settings
        try? libraryDataService.saveLibrary()
    }

    private func saveWordSkip() {
        var settings = libraryDataService.settings
        settings.wordSkip = Int(wordSkip)
        libraryDataService.settings = settings
        try? libraryDataService.saveLibrary()
    }
}
