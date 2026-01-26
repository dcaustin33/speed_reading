import Foundation

/// View model for the Reading screen, coordinating between PlaybackEngine and UI.
/// Handles book loading, playback control, scrubbing, and progress tracking.
@Observable
@MainActor
class ReaderViewModel {
    // MARK: - Dependencies

    private let libraryDataService: LibraryDataService
    private let playbackEngine: PlaybackEngine

    // MARK: - Book State

    let bookId: UUID
    private(set) var book: Book?
    private(set) var document: Document?

    // MARK: - Current Display

    /// Current word text to display
    private(set) var currentWord: String = ""

    /// ORP index for current word
    private(set) var currentOrpIndex: Int = 0

    // MARK: - Playback State

    /// Whether playback is currently active
    var isPlaying: Bool { playbackEngine.isPlaying }

    /// Whether playback is paused
    var isPaused: Bool { playbackEngine.isPaused }

    /// Whether playback is stopped
    var isStopped: Bool { playbackEngine.isStopped }

    /// Current word index position
    var currentWordIndex: Int { playbackEngine.currentWordIndex }

    // MARK: - Progress

    /// Progress as a value from 0.0 to 1.0
    var progress: Double {
        if isScrubbing {
            return scrubPosition
        }
        return playbackEngine.progress
    }

    /// Progress as a percentage (0-100)
    var progressPercentage: Int {
        Int(progress * 100)
    }

    /// Formatted time remaining (M:SS or H:MM:SS)
    var remainingTimeFormatted: String {
        playbackEngine.remainingTimeFormatted
    }

    // MARK: - Settings (synced with PlaybackEngine)

    var wpm: Int {
        get { playbackEngine.wpm }
        set {
            playbackEngine.wpm = newValue
            saveSetting { settings in
                settings.wpm = newValue
            }
        }
    }

    var paragraphPause: Double {
        get { playbackEngine.paragraphPause }
        set {
            playbackEngine.paragraphPause = newValue
            saveSetting { settings in
                settings.paragraphPause = newValue
            }
        }
    }

    var fontSize: Double {
        get { Double(libraryDataService.settings.fontSize) }
        set {
            saveSetting { settings in
                settings.fontSize = Int(newValue)
            }
        }
    }

    var wordSkip: Int {
        get { playbackEngine.wordSkip }
        set {
            playbackEngine.wordSkip = newValue
            saveSetting { settings in
                settings.wordSkip = newValue
            }
        }
    }

    // MARK: - Book Info

    var hasTOC: Bool { book?.hasTOC ?? false }

    var bookTitle: String { book?.title ?? "" }

    // MARK: - Loading State

    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    // MARK: - Scrubbing

    private(set) var isScrubbing: Bool = false
    private(set) var scrubPosition: Double = 0

    // MARK: - Completion

    private(set) var isCompleted: Bool = false

    // MARK: - Chapter Overlay State

    /// Whether the chapter overlay is currently visible
    private(set) var isChapterOverlayVisible: Bool = false

    /// Title of the current chapter being displayed in overlay
    private(set) var currentChapterTitle: String = ""

    /// Timer for auto-hiding chapter overlay after 2 seconds
    private var chapterOverlayTimer: Timer?

    /// Tracks whether we've shown the initial chapter (to avoid showing on first load)
    private var hasShownInitialChapter: Bool = false

    /// Task reference for book loading (enables cancellation)
    private var loadTask: Task<Void, Never>?

    // MARK: - Callbacks

    /// Called on sentence boundary for haptic feedback
    var onSentenceBoundary: (() -> Void)?

    // MARK: - Initialization

    init(bookId: UUID, libraryDataService: LibraryDataService = LibraryDataService()) {
        self.bookId = bookId
        self.libraryDataService = libraryDataService
        self.playbackEngine = PlaybackEngine()

        setupCallbacks()
    }

    private func setupCallbacks() {
        playbackEngine.onWordChange = { [weak self] word, index in
            self?.currentWord = word.text
            self?.currentOrpIndex = word.orpIndex
        }

        playbackEngine.onSentenceChange = { [weak self] in
            self?.onSentenceBoundary?()
        }

        playbackEngine.onParagraphChange = { [weak self] in
            // Save progress at every paragraph end per spec (Section 6.3)
            self?.saveProgress()
        }

        playbackEngine.onStateChange = { [weak self] state in
            // Save progress when playback pauses (for any reason)
            if state == .paused {
                self?.saveProgress()
            }
        }

        playbackEngine.onChapterChange = { [weak self] chapter in
            self?.handleChapterChange(chapter)
        }

        playbackEngine.onComplete = { [weak self] in
            self?.handleCompletion()
        }
    }

    // MARK: - Book Loading

    /// Loads the book and prepares it for reading.
    /// Opens at the saved position, aligned to paragraph start.
    /// If coming from search, jumps to the searched position instead.
    func loadBook() {
        // Cancel any existing load operation
        loadTask?.cancel()
        loadTask = Task {
            await performLoadBook()
        }
    }

    /// Internal async implementation of book loading.
    private func performLoadBook() async {
        isLoading = true
        errorMessage = nil

        do {
            try libraryDataService.loadLibrary()

            // Open book (validates hash, updates dateLastOpened)
            guard let openResult = try libraryDataService.openBook(bookId) else {
                errorMessage = "This book is no longer available."
                isLoading = false
                return
            }

            let book = openResult.book
            self.book = book

            // Load settings from library
            let settings = libraryDataService.settings
            playbackEngine.wpm = settings.wpm
            playbackEngine.paragraphPause = settings.paragraphPause
            playbackEngine.wordSkip = settings.wordSkip

            // Load book content
            let bookFileURL = libraryDataService.bookFileURL(for: book.id, fileType: book.fileType)
            let content = try String(contentsOf: bookFileURL, encoding: .utf8)

            // Tokenize with chapter info if EPUB
            let chapters = await loadChapters(for: book, content: content)
            let document = TokenizerService.tokenize(text: content, chapters: chapters)
            self.document = document

            // Check for search or TOC jump position first (takes priority)
            var resumeIndex: Int
            if let searchJumpIndex = SearchViewModel.getAndClearJumpPosition(for: bookId) {
                // Jump directly to searched position (no paragraph alignment per spec)
                resumeIndex = min(searchJumpIndex, max(0, document.totalWords - 1))
            } else if let tocJumpIndex = TOCViewModel.getAndClearJumpPosition(for: bookId) {
                // Jump directly to chapter start (no paragraph alignment needed, it's already at chapter start)
                resumeIndex = min(tocJumpIndex, max(0, document.totalWords - 1))
            } else {
                // Normal resume: use saved position
                resumeIndex = book.currentWordIndex

                // If hash changed, we already reset to 0 in openBook
                if openResult.hashChanged {
                    resumeIndex = 0
                }

                // Find paragraph start per spec (Section 6.4)
                resumeIndex = findParagraphStart(from: resumeIndex, in: document)
            }

            // Load document into playback engine (always starts paused)
            playbackEngine.loadDocument(document, startAt: resumeIndex)

            // Update display
            if let word = playbackEngine.currentWord {
                currentWord = word.text
                currentOrpIndex = word.orpIndex
            }

            isLoading = false

        } catch {
            errorMessage = "Could not load book: \(error.localizedDescription)"
            isLoading = false
        }
    }

    /// Finds the start of the paragraph containing the given word index.
    /// Per spec (Section 6.4): Scan backward from index until paragraph_end = true or index = 0.
    /// Resume from the word after that paragraph end (or 0).
    private func findParagraphStart(from index: Int, in document: Document) -> Int {
        // At start, stay at start
        if index == 0 { return 0 }

        // If at last word (completed), stay there per spec
        if index >= document.totalWords - 1 {
            return document.totalWords - 1
        }

        // Scan backward for paragraph end
        for i in stride(from: index - 1, through: 0, by: -1) {
            if document.words[i].paragraphEnd {
                return i + 1  // Start of next paragraph
            }
        }

        // No paragraph end found before index, start at beginning
        return 0
    }

    /// Loads chapters for EPUB files (placeholder - chapters already in Document)
    private func loadChapters(for book: Book, content: String) async -> [Chapter]? {
        // For now, chapters are handled during initial EPUB import
        // and stored in the tokenized document. This is a placeholder
        // for any additional chapter loading logic if needed.
        return nil
    }

    // MARK: - Playback Control

    /// Toggles play/pause state
    func toggle() {
        playbackEngine.toggle()
    }

    /// Starts playback
    func play() {
        playbackEngine.play()
    }

    /// Pauses playback
    func pause() {
        playbackEngine.pause()
    }

    // MARK: - Navigation

    /// Jumps to a specific word index
    func jumpTo(wordIndex: Int) {
        playbackEngine.jumpTo(wordIndex: wordIndex)
    }

    /// Skips forward by word skip amount
    func skipForward() {
        playbackEngine.skipWords(wordSkip)
    }

    /// Skips backward by word skip amount
    func skipBackward() {
        playbackEngine.skipWords(-wordSkip)
    }

    /// Jump to next sentence
    func nextSentence() {
        playbackEngine.nextSentence()
    }

    /// Jump to previous sentence
    func previousSentence() {
        playbackEngine.previousSentence()
    }

    /// Jump to next paragraph
    func nextParagraph() {
        playbackEngine.nextParagraph()
    }

    /// Jump to previous paragraph
    func previousParagraph() {
        playbackEngine.previousParagraph()
    }

    // MARK: - Scrubbing

    /// Begins scrubbing (user started dragging progress bar)
    func startScrubbing() {
        if playbackEngine.isPlaying {
            playbackEngine.pause()
        }
        isScrubbing = true
        scrubPosition = playbackEngine.progress
    }

    /// Updates scrub position during drag (live preview)
    func updateScrubPosition(_ position: Double) {
        guard isScrubbing, let doc = document else { return }
        scrubPosition = max(0, min(1, position))

        // Live preview: show word at scrub position
        let wordIndex = Int(scrubPosition * Double(max(1, doc.totalWords - 1)))
        let clampedIndex = max(0, min(wordIndex, doc.totalWords - 1))
        let word = doc.words[clampedIndex]
        currentWord = word.text
        currentOrpIndex = word.orpIndex
    }

    /// Ends scrubbing (user released progress bar)
    func endScrubbing() {
        guard isScrubbing, let doc = document else { return }

        // Jump to final position
        let wordIndex = Int(scrubPosition * Double(max(1, doc.totalWords - 1)))
        let clampedIndex = max(0, min(wordIndex, doc.totalWords - 1))
        playbackEngine.jumpTo(wordIndex: clampedIndex)

        isScrubbing = false
        // Stay paused per spec
    }

    // MARK: - Progress Saving

    /// Saves current reading progress
    func saveProgress() {
        guard book != nil else { return }

        do {
            try libraryDataService.updateProgress(
                bookId: bookId,
                wordIndex: playbackEngine.currentWordIndex
            )
        } catch {
            print("Failed to save progress: \(error)")
        }
    }

    /// Saves a setting change to persistent storage
    private func saveSetting(_ update: (inout Settings) -> Void) {
        var settings = libraryDataService.settings
        update(&settings)
        libraryDataService.settings = settings
        try? libraryDataService.saveLibrary()
    }

    // MARK: - Chapter Transitions

    /// Handles chapter change during playback.
    /// Per spec (Section 3.7): Show overlay for 2 seconds, playback continues behind it.
    private func handleChapterChange(_ chapter: Chapter) {
        // Skip showing overlay on initial load
        guard hasShownInitialChapter else {
            hasShownInitialChapter = true
            return
        }

        // Show chapter overlay
        currentChapterTitle = chapter.title
        isChapterOverlayVisible = true

        // Cancel any existing timer
        chapterOverlayTimer?.invalidate()

        // Auto-hide after 2 seconds per spec
        chapterOverlayTimer = Timer.scheduledTimer(
            withTimeInterval: Theme.Animation.chapterOverlayDuration,
            repeats: false
        ) { [weak self] _ in
            self?.hideChapterOverlay()
        }
    }

    /// Hides the chapter overlay
    private func hideChapterOverlay() {
        isChapterOverlayVisible = false
        chapterOverlayTimer?.invalidate()
        chapterOverlayTimer = nil
    }

    // MARK: - Completion

    private func handleCompletion() {
        isCompleted = true
        saveProgress()
    }

    /// Resets completion state (for dismissing completion overlay)
    func dismissCompletion() {
        isCompleted = false
    }

    // MARK: - Cleanup

    /// Called when leaving the reader screen
    func onDisappear() {
        // Cancel any pending load task
        loadTask?.cancel()
        loadTask = nil

        playbackEngine.pause()
        saveProgress()
        chapterOverlayTimer?.invalidate()
        chapterOverlayTimer = nil
    }
}
