import Foundation

/// Playback state for the reading engine
enum PlaybackState: Equatable {
    case stopped
    case playing
    case paused
}

/// Core playback engine for managing word-by-word display timing
/// Handles state machine, timing, navigation, and callbacks for the reader
@Observable
@MainActor
class PlaybackEngine {
    // MARK: - State

    private(set) var state: PlaybackState = .stopped
    private(set) var currentWordIndex: Int = 0
    private var document: Document?

    // MARK: - Settings
    // NOTE: Using private backing storage + computed properties because
    // @Observable's withMutation wrapper re-enters on didSet self-assignment,
    // causing infinite recursion / stack overflow.

    private var _wpm: Int = 300
    var wpm: Int {
        get { _wpm }
        set { _wpm = max(100, min(800, newValue)) }
    }

    private var _paragraphPause: Double = 1.0
    var paragraphPause: Double {
        get { _paragraphPause }
        set { _paragraphPause = max(0.25, min(3.0, newValue)) }
    }

    private var _wordSkip: Int = 5
    var wordSkip: Int {
        get { _wordSkip }
        set { _wordSkip = max(1, min(20, newValue)) }
    }

    // MARK: - Callbacks

    var onWordChange: ((Word, Int) -> Void)?
    var onSentenceChange: (() -> Void)?
    var onParagraphChange: (() -> Void)?
    var onChapterChange: ((Chapter) -> Void)?
    var onComplete: (() -> Void)?
    var onStateChange: ((PlaybackState) -> Void)?

    // MARK: - Playback Task

    private var playbackTask: Task<Void, Never>?

    // MARK: - Computed Properties

    var totalWords: Int {
        document?.totalWords ?? 0
    }

    var currentWord: Word? {
        guard let doc = document, currentWordIndex < doc.totalWords else { return nil }
        return doc.words[currentWordIndex]
    }

    var isPlaying: Bool {
        state == .playing
    }

    var isPaused: Bool {
        state == .paused
    }

    var isStopped: Bool {
        state == .stopped
    }

    /// Word delay in milliseconds
    var wordDelayMs: Int {
        guard wpm > 0 else { return 200 }
        return 60000 / wpm
    }

    /// Progress as percentage (0.0 - 1.0)
    var progress: Double {
        guard totalWords > 0 else { return 0 }
        return Double(currentWordIndex) / Double(totalWords)
    }

    /// Remaining time in seconds
    var remainingTime: TimeInterval {
        guard let doc = document else { return 0 }
        let remainingWords = totalWords - currentWordIndex
        guard remainingWords > 0 else { return 0 }

        let wordTime = Double(remainingWords) * (Double(wordDelayMs) / 1000.0)

        // Count remaining paragraph ends
        var remainingParagraphs = 0
        for i in currentWordIndex..<doc.totalWords {
            if doc.words[i].paragraphEnd {
                remainingParagraphs += 1
            }
        }
        let paragraphTime = Double(remainingParagraphs) * paragraphPause

        return wordTime + paragraphTime
    }

    /// Formatted remaining time string (MM:SS or H:MM:SS)
    var remainingTimeFormatted: String {
        let seconds = Int(remainingTime)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    // MARK: - Initialization

    init() {}

    // MARK: - Document Management

    /// Loads a document for playback
    /// - Parameters:
    ///   - document: The document to play
    ///   - index: Starting word index (default 0)
    func loadDocument(_ document: Document, startAt index: Int = 0) {
        print("[Engine] loadDocument: totalWords=\(document.totalWords), requestedStart=\(index)")
        stopPlayback()
        self.document = document

        guard document.totalWords > 0 else {
            print("[Engine] WARNING: Document has 0 words! Staying at index 0.")
            self.currentWordIndex = 0
            self.state = .stopped
            self.lastChapterIndex = nil
            onStateChange?(.stopped)
            return
        }

        self.currentWordIndex = max(0, min(index, document.totalWords - 1))
        print("[Engine] Set currentWordIndex=\(self.currentWordIndex)")
        self.state = .stopped
        self.lastChapterIndex = nil
        onStateChange?(.stopped)

        if let word = currentWord {
            onWordChange?(word, currentWordIndex)
            print("[Engine] Initial word emitted: '\(word.text)'")
        } else {
            print("[Engine] WARNING: currentWord is nil after setting index \(currentWordIndex)")
        }

        // Trigger initial chapter check
        checkChapterChange()
    }

    // MARK: - Playback Control

    /// Starts or resumes playback
    func play() {
        print("[Engine] play() called: state=\(state), hasDocument=\(document != nil), totalWords=\(totalWords), currentWordIndex=\(currentWordIndex)")
        guard document != nil, totalWords > 0 else {
            print("[Engine] play() aborted: no document or 0 words")
            return
        }
        guard state != .playing else {
            print("[Engine] play() aborted: already playing")
            return
        }

        // At end, reset to beginning
        if currentWordIndex >= totalWords {
            currentWordIndex = 0
        }

        state = .playing
        onStateChange?(.playing)
        startPlaybackLoop()
    }

    /// Pauses playback
    func pause() {
        guard state == .playing else { return }
        stopPlayback()
        state = .paused
        onStateChange?(.paused)
    }

    /// Toggles between play and pause
    func toggle() {
        switch state {
        case .stopped, .paused:
            play()
        case .playing:
            pause()
        }
    }

    /// Stops playback and resets to beginning
    func stop() {
        stopPlayback()
        currentWordIndex = 0
        state = .stopped
        onStateChange?(.stopped)

        if let word = currentWord {
            onWordChange?(word, currentWordIndex)
        }
    }

    // MARK: - Navigation

    /// Skips forward or backward by specified number of words
    /// - Parameter amount: Number of words to skip (positive = forward, negative = backward)
    func skipWords(_ amount: Int) {
        guard let doc = document, totalWords > 0 else { return }

        let wasPlaying = state == .playing
        if wasPlaying { pause() }

        let newIndex = currentWordIndex + amount
        currentWordIndex = max(0, min(newIndex, totalWords - 1))

        onWordChange?(doc.words[currentWordIndex], currentWordIndex)
        checkChapterChange()
    }

    /// Jumps to the start of the next sentence
    func nextSentence() {
        guard let doc = document, totalWords > 0 else { return }

        let wasPlaying = state == .playing
        if wasPlaying { pause() }

        // Find next sentence start (word after sentence end)
        for i in currentWordIndex..<totalWords {
            if doc.words[i].sentenceEnd && i + 1 < totalWords {
                currentWordIndex = i + 1
                onWordChange?(doc.words[currentWordIndex], currentWordIndex)
                checkChapterChange()
                return
            }
        }
        // No next sentence found - stay at current position
    }

    /// Jumps to the start of the current or previous sentence
    func previousSentence() {
        guard let doc = document, totalWords > 0 else { return }

        let wasPlaying = state == .playing
        if wasPlaying { pause() }

        // Find start of current sentence
        var sentenceStart = 0
        for i in stride(from: currentWordIndex - 1, through: 0, by: -1) {
            if doc.words[i].sentenceEnd {
                sentenceStart = i + 1
                break
            }
        }

        // If we're not at the start of current sentence, go there
        if currentWordIndex > sentenceStart {
            currentWordIndex = sentenceStart
        } else {
            // We're at sentence start, find previous sentence start
            var foundPrevious = false
            for i in stride(from: sentenceStart - 2, through: 0, by: -1) {
                if doc.words[i].sentenceEnd {
                    currentWordIndex = i + 1
                    foundPrevious = true
                    break
                }
            }
            if !foundPrevious && sentenceStart > 0 {
                // No previous sentence end found, go to beginning
                currentWordIndex = 0
            }
        }

        onWordChange?(doc.words[currentWordIndex], currentWordIndex)
        checkChapterChange()
    }

    /// Jumps to the start of the next paragraph
    func nextParagraph() {
        guard let doc = document, totalWords > 0 else { return }

        let wasPlaying = state == .playing
        if wasPlaying { pause() }

        // Find next paragraph start (word after paragraph end)
        for i in currentWordIndex..<totalWords {
            if doc.words[i].paragraphEnd && i + 1 < totalWords {
                currentWordIndex = i + 1
                onWordChange?(doc.words[currentWordIndex], currentWordIndex)
                checkChapterChange()
                return
            }
        }
        // No next paragraph found - stay at current position
    }

    /// Jumps to the start of the current or previous paragraph
    func previousParagraph() {
        guard let doc = document, totalWords > 0 else { return }

        let wasPlaying = state == .playing
        if wasPlaying { pause() }

        // Find start of current paragraph
        var paragraphStart = 0
        for i in stride(from: currentWordIndex - 1, through: 0, by: -1) {
            if doc.words[i].paragraphEnd {
                paragraphStart = i + 1
                break
            }
        }

        // If we're not at the start of current paragraph, go there
        if currentWordIndex > paragraphStart {
            currentWordIndex = paragraphStart
        } else {
            // We're at paragraph start, find previous paragraph start
            for i in stride(from: paragraphStart - 2, through: 0, by: -1) {
                if doc.words[i].paragraphEnd {
                    currentWordIndex = i + 1
                    onWordChange?(doc.words[currentWordIndex], currentWordIndex)
                    checkChapterChange()
                    return
                }
            }
            // No previous paragraph found, go to beginning
            currentWordIndex = 0
        }

        onWordChange?(doc.words[currentWordIndex], currentWordIndex)
        checkChapterChange()
    }

    /// Jumps to a specific word index
    /// - Parameter wordIndex: The word index to jump to
    func jumpTo(wordIndex: Int) {
        guard let doc = document, totalWords > 0 else { return }

        let wasPlaying = state == .playing
        if wasPlaying { pause() }

        currentWordIndex = max(0, min(wordIndex, totalWords - 1))
        onWordChange?(doc.words[currentWordIndex], currentWordIndex)
        checkChapterChange()
    }

    // MARK: - Playback Management

    private func startPlaybackLoop() {
        playbackTask?.cancel()
        playbackTask = Task {
            await playbackLoopIteration()
        }
    }

    private func playbackLoopIteration() async {
        // Check if we should continue
        guard state == .playing, let doc = document else {
            print("[Engine] Loop exit early: state=\(state), hasDocument=\(document != nil)")
            return
        }
        guard currentWordIndex < totalWords else {
            // Reached end
            print("[Engine] Reached end: currentWordIndex=\(currentWordIndex), totalWords=\(totalWords)")
            state = .paused
            onStateChange?(.paused)
            onComplete?()
            return
        }

        // Bounds check before array access
        guard currentWordIndex >= 0, currentWordIndex < doc.words.count else {
            print("[Engine] FATAL: Index out of bounds! currentWordIndex=\(currentWordIndex), words.count=\(doc.words.count)")
            state = .paused
            onStateChange?(.paused)
            return
        }

        let word = doc.words[currentWordIndex]

        // Calculate delay
        var delayMs = wordDelayMs
        if word.paragraphEnd {
            delayMs += Int(paragraphPause * 1000)
        }

        // Fire word change callback
        onWordChange?(word, currentWordIndex)

        // Check for sentence change
        if word.sentenceEnd {
            onSentenceChange?()
        }

        // Check for paragraph change
        if word.paragraphEnd {
            onParagraphChange?()
        }

        // Check for chapter change
        checkChapterChange()

        // Check if this is the last word
        if currentWordIndex >= totalWords - 1 {
            state = .paused
            onStateChange?(.paused)
            onComplete?()
            return
        }

        // Wait for delay
        do {
            try await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
        } catch {
            return // Task was cancelled
        }

        // Move to next word and continue loop
        guard state == .playing else { return }
        currentWordIndex += 1

        // Schedule next iteration
        await playbackLoopIteration()
    }

    private func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
    }

    private var lastChapterIndex: Int? = nil

    private func checkChapterChange() {
        guard let doc = document, let chapters = doc.chapters else { return }
        guard let word = currentWord else { return }
        guard let chapterIndex = word.chapterIndex else { return }

        if chapterIndex != lastChapterIndex {
            print("[Engine] Chapter change: \(lastChapterIndex ?? -1) -> \(chapterIndex), chaptersCount=\(chapters.count)")
            lastChapterIndex = chapterIndex
            if chapterIndex < chapters.count {
                print("[Engine] Firing onChapterChange: '\(chapters[chapterIndex].title)'")
                onChapterChange?(chapters[chapterIndex])
            } else {
                print("[Engine] WARNING: chapterIndex \(chapterIndex) out of bounds (chapters.count=\(chapters.count))")
            }
        }
    }

}
