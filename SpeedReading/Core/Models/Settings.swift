import Foundation

/// Global app settings (apply to all books)
struct Settings: Codable, Equatable {
    // MARK: - Range Constants

    static let wpmRange = 100...800
    static let paragraphPauseRange = 0.25...3.0
    static let fontSizeRange = 24...96
    static let wordSkipRange = 1...20

    // MARK: - Default Values

    static let defaultWPM = 300
    static let defaultParagraphPause = 1.0
    static let defaultFontSize = 48
    static let defaultWordSkip = 5
    static let defaultLibrarySort = SortOrder.recent

    // MARK: - Properties (with clamping)

    private var _wpm: Int
    private var _paragraphPause: Double
    private var _fontSize: Int
    private var _wordSkip: Int

    /// Words per minute (100-800, default 300)
    var wpm: Int {
        get { _wpm }
        set { _wpm = Self.clamp(newValue, to: Self.wpmRange) }
    }

    /// Pause duration at paragraph ends in seconds (0.25-3.0, default 1.0)
    var paragraphPause: Double {
        get { _paragraphPause }
        set { _paragraphPause = Self.clamp(newValue, to: Self.paragraphPauseRange) }
    }

    /// Font size for ORP display in points (24-96, default 48)
    var fontSize: Int {
        get { _fontSize }
        set { _fontSize = Self.clamp(newValue, to: Self.fontSizeRange) }
    }

    /// Number of words to skip with forward/back buttons (1-20, default 5)
    var wordSkip: Int {
        get { _wordSkip }
        set { _wordSkip = Self.clamp(newValue, to: Self.wordSkipRange) }
    }

    /// Library sorting preference
    var librarySort: SortOrder

    // MARK: - Initialization

    init(
        wpm: Int = defaultWPM,
        paragraphPause: Double = defaultParagraphPause,
        fontSize: Int = defaultFontSize,
        wordSkip: Int = defaultWordSkip,
        librarySort: SortOrder = defaultLibrarySort
    ) {
        self._wpm = Self.clamp(wpm, to: Self.wpmRange)
        self._paragraphPause = Self.clamp(paragraphPause, to: Self.paragraphPauseRange)
        self._fontSize = Self.clamp(fontSize, to: Self.fontSizeRange)
        self._wordSkip = Self.clamp(wordSkip, to: Self.wordSkipRange)
        self.librarySort = librarySort
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case wpm
        case paragraphPause
        case fontSize
        case wordSkip
        case librarySort
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let wpm = try container.decode(Int.self, forKey: .wpm)
        let paragraphPause = try container.decode(Double.self, forKey: .paragraphPause)
        let fontSize = try container.decode(Int.self, forKey: .fontSize)
        let wordSkip = try container.decode(Int.self, forKey: .wordSkip)
        let librarySort = try container.decode(SortOrder.self, forKey: .librarySort)

        self.init(
            wpm: wpm,
            paragraphPause: paragraphPause,
            fontSize: fontSize,
            wordSkip: wordSkip,
            librarySort: librarySort
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(_wpm, forKey: .wpm)
        try container.encode(_paragraphPause, forKey: .paragraphPause)
        try container.encode(_fontSize, forKey: .fontSize)
        try container.encode(_wordSkip, forKey: .wordSkip)
        try container.encode(librarySort, forKey: .librarySort)
    }

    // MARK: - Helpers

    private static func clamp<T: Comparable>(_ value: T, to range: ClosedRange<T>) -> T {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
