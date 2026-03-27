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
    // NOTE: Using private backing storage + computed properties because
    // @Observable's withMutation wrapper re-enters on didSet self-assignment,
    // causing infinite recursion / stack overflow.

    private var _fontSize: Double = 28
    /// Font size for ORP display (24-96pt)
    var fontSize: Double {
        get { _fontSize }
        set {
            _fontSize = newValue
            saveFontSize()
        }
    }

    private var _wordSkip: Double = 5
    /// Word skip amount for navigation buttons (1-20)
    var wordSkip: Double {
        get { _wordSkip }
        set {
            _wordSkip = newValue
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

        // Load current settings (use backing properties to avoid triggering save)
        self._fontSize = Double(libraryDataService.settings.fontSize)
        self._wordSkip = Double(libraryDataService.settings.wordSkip)
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
