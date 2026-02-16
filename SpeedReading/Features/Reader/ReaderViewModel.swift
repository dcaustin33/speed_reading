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

    /// Formatted chapter time remaining, or nil if no chapters
    var chapterRemainingTimeFormatted: String? {
        playbackEngine.chapterRemainingTimeFormatted
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

    /// Task reference for book loading (enables cancellation)
    private var loadTask: Task<Void, Never>?

    // MARK: - Paragraph Preview State

    /// Whether the paragraph preview overlay is currently visible
    private(set) var isParagraphPreviewVisible: Bool = false

    /// The text of the current paragraph for the preview overlay
    private(set) var paragraphPreviewText: String = ""

    /// The index of the current word within the paragraph (for highlighting)
    private(set) var paragraphHighlightWordIndex: Int = 0

    // MARK: - Navigation Overlay State

    /// Whether the navigation overlay is currently visible
    private(set) var isNavigationOverlayVisible: Bool = false

    /// Timer for auto-hiding navigation overlay after 2 seconds
    private var navigationOverlayTimer: Timer?

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
        print("[Reader] performLoadBook started for bookId=\(bookId)")

        do {
            try libraryDataService.loadLibrary()
            print("[Reader] Library loaded OK")

            // Open book (validates hash, updates dateLastOpened)
            guard let openResult = try libraryDataService.openBook(bookId) else {
                print("[Reader] openBook returned nil — book not found or file deleted")
                errorMessage = "This book is no longer available."
                isLoading = false
                return
            }

            let book = openResult.book
            self.book = book
            print("[Reader] Book opened: '\(book.title)', fileType=\(book.fileType), totalWords=\(book.totalWords), currentWordIndex=\(book.currentWordIndex), hashChanged=\(openResult.hashChanged)")

            // Load settings from library
            let settings = libraryDataService.settings
            playbackEngine.wpm = settings.wpm
            playbackEngine.paragraphPause = settings.paragraphPause
            playbackEngine.wordSkip = settings.wordSkip
            print("[Reader] Settings applied: wpm=\(settings.wpm), paragraphPause=\(settings.paragraphPause), wordSkip=\(settings.wordSkip)")

            // Load book content
            let bookFileURL = libraryDataService.bookFileURL(for: book.id, fileType: book.fileType)
            print("[Reader] Book file URL: \(bookFileURL.path)")
            print("[Reader] File exists: \(FileManager.default.fileExists(atPath: bookFileURL.path))")
            let content = try String(contentsOf: bookFileURL, encoding: .utf8)
            print("[Reader] Content loaded, length=\(content.count) chars")

            // Tokenize with chapter info if EPUB
            let chapters = await loadChapters(for: book, content: content)
            print("[Reader] Chapters loaded: \(chapters?.count ?? 0) chapters (isNil=\(chapters == nil))")
            let document = TokenizerService.tokenize(text: content, chapters: chapters)
            self.document = document
            print("[Reader] Tokenized: \(document.totalWords) words, docChapters=\(document.chapters?.count ?? 0)")

            // Check for search or TOC jump position first (takes priority)
            var resumeIndex: Int
            if let searchJumpIndex = SearchViewModel.getAndClearJumpPosition(for: bookId) {
                // Jump directly to searched position (no paragraph alignment per spec)
                resumeIndex = min(searchJumpIndex, max(0, document.totalWords - 1))
                print("[Reader] Resuming from search jump: requested=\(searchJumpIndex), clamped=\(resumeIndex)")
            } else if let tocJumpIndex = TOCViewModel.getAndClearJumpPosition(for: bookId) {
                // Jump directly to chapter start (no paragraph alignment needed, it's already at chapter start)
                resumeIndex = min(tocJumpIndex, max(0, document.totalWords - 1))
                print("[Reader] Resuming from TOC jump: requested=\(tocJumpIndex), clamped=\(resumeIndex)")
            } else {
                // Normal resume: use saved position
                resumeIndex = book.currentWordIndex
                print("[Reader] Normal resume: savedIndex=\(book.currentWordIndex)")

                // If hash changed, we already reset to 0 in openBook
                if openResult.hashChanged {
                    resumeIndex = 0
                    print("[Reader] Hash changed, reset to 0")
                }

                // Find paragraph start per spec (Section 6.4)
                let beforeAlign = resumeIndex
                resumeIndex = findParagraphStart(from: resumeIndex, in: document)
                print("[Reader] Paragraph alignment: \(beforeAlign) -> \(resumeIndex)")
            }

            print("[Reader] Final resumeIndex=\(resumeIndex), totalWords=\(document.totalWords)")

            // Load document into playback engine (always starts paused)
            playbackEngine.loadDocument(document, startAt: resumeIndex)
            print("[Reader] Document loaded into engine, engineWordIndex=\(playbackEngine.currentWordIndex)")

            // Update display
            if let word = playbackEngine.currentWord {
                currentWord = word.text
                currentOrpIndex = word.orpIndex
                print("[Reader] Initial display word: '\(word.text)', orpIndex=\(word.orpIndex)")
            } else {
                print("[Reader] WARNING: currentWord is nil after loadDocument!")
            }

            isLoading = false
            print("[Reader] performLoadBook completed successfully")

        } catch {
            print("[Reader] ERROR in performLoadBook: \(error)")
            print("[Reader] Error type: \(type(of: error))")
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

    /// Loads chapters for EPUB files from persisted chapter data
    private func loadChapters(for book: Book, content: String) async -> [Chapter]? {
        guard book.fileType == .epub else { return nil }
        let chapters = libraryDataService.loadChapters(for: book.id)
        return chapters.isEmpty ? nil : chapters
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
        resetNavigationOverlayTimerIfVisible()
    }

    /// Jump to previous sentence
    func previousSentence() {
        playbackEngine.previousSentence()
        resetNavigationOverlayTimerIfVisible()
    }

    /// Jump to next paragraph
    func nextParagraph() {
        playbackEngine.nextParagraph()
        resetNavigationOverlayTimerIfVisible()
    }

    /// Jump to previous paragraph
    func previousParagraph() {
        playbackEngine.previousParagraph()
        resetNavigationOverlayTimerIfVisible()
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

    // MARK: - Navigation Overlay

    /// Shows the navigation overlay and starts the auto-hide timer
    func showNavigationOverlay() {
        isNavigationOverlayVisible = true
        resetNavigationOverlayTimer()
    }

    /// Hides the navigation overlay and invalidates the timer
    func hideNavigationOverlay() {
        isNavigationOverlayVisible = false
        navigationOverlayTimer?.invalidate()
        navigationOverlayTimer = nil
    }

    /// Toggles the navigation overlay visibility
    func toggleNavigationOverlay() {
        if isNavigationOverlayVisible {
            hideNavigationOverlay()
        } else {
            showNavigationOverlay()
        }
    }

    /// Resets the navigation overlay timer (called when overlay is shown or navigation occurs)
    private func resetNavigationOverlayTimer() {
        navigationOverlayTimer?.invalidate()
        navigationOverlayTimer = Timer.scheduledTimer(
            withTimeInterval: Theme.Animation.navigationOverlayDuration,
            repeats: false
        ) { [weak self] _ in
            self?.hideNavigationOverlay()
        }
    }

    /// Resets the timer only if the overlay is currently visible
    private func resetNavigationOverlayTimerIfVisible() {
        if isNavigationOverlayVisible {
            resetNavigationOverlayTimer()
        }
    }

    // MARK: - Paragraph Preview

    /// Shows the paragraph preview overlay with the current paragraph text
    func showParagraphPreview() {
        guard let result = playbackEngine.currentParagraphText() else { return }
        if isPlaying { pause() }
        paragraphPreviewText = result.text
        paragraphHighlightWordIndex = result.highlightWordIndex
        isParagraphPreviewVisible = true
    }

    /// Hides the paragraph preview overlay
    func hideParagraphPreview() {
        isParagraphPreviewVisible = false
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

    // MARK: - Completion

    private func handleCompletion() {
        isCompleted = true
        saveProgress()
    }

    /// Resets completion state (for dismissing completion overlay)
    func dismissCompletion() {
        isCompleted = false
    }

    // MARK: - Settings Reload

    /// Reloads settings from disk. Call when returning from settings to pick up changes
    /// made by SettingsViewModel's separate LibraryDataService instance.
    func reloadSettings() {
        try? libraryDataService.loadLibrary()
        let settings = libraryDataService.settings
        playbackEngine.wordSkip = settings.wordSkip
        // fontSize reads directly from libraryDataService.settings, so it updates automatically
    }

    // MARK: - Cleanup

    /// Called when leaving the reader screen
    func onDisappear() {
        // Cancel any pending load task
        loadTask?.cancel()
        loadTask = nil

        playbackEngine.pause()
        saveProgress()
        navigationOverlayTimer?.invalidate()
        navigationOverlayTimer = nil
    }
}
