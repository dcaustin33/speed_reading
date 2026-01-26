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
class PlaybackEngine {
    // MARK: - State

    private(set) var state: PlaybackState = .stopped
    private(set) var currentWordIndex: Int = 0
    private var document: Document?

    // MARK: - Settings

    var wpm: Int = 300 {
        didSet {
            wpm = max(100, min(800, wpm))
        }
    }

    var paragraphPause: Double = 1.0 {
        didSet {
            paragraphPause = max(0.25, min(3.0, paragraphPause))
        }
    }

    var wordSkip: Int = 5 {
        didSet {
            wordSkip = max(1, min(20, wordSkip))
        }
    }

    // MARK: - Callbacks

    var onWordChange: ((Word, Int) -> Void)?
    var onSentenceChange: (() -> Void)?
    var onParagraphChange: (() -> Void)?
    var onChapterChange: ((Chapter) -> Void)?
    var onComplete: (() -> Void)?
    var onStateChange: ((PlaybackState) -> Void)?

    // MARK: - Timer

    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.speedreading.playback", qos: .userInteractive)

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
        stopTimer()
        self.document = document
        self.currentWordIndex = max(0, min(index, document.totalWords - 1))
        self.state = .stopped
        self.lastChapterIndex = nil
        onStateChange?(.stopped)

        if let word = currentWord {
            onWordChange?(word, currentWordIndex)
        }

        // Trigger initial chapter check
        checkChapterChange()
    }

    // MARK: - Playback Control

    /// Starts or resumes playback
    func play() {
        guard document != nil, totalWords > 0 else { return }
        guard state != .playing else { return }

        // At end, reset to beginning
        if currentWordIndex >= totalWords {
            currentWordIndex = 0
        }

        state = .playing
        onStateChange?(.playing)
        scheduleNextWord()
    }

    /// Pauses playback
    func pause() {
        guard state == .playing else { return }
        stopTimer()
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
        stopTimer()
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

    // MARK: - Timer Management

    private func scheduleNextWord() {
        guard state == .playing, let doc = document else { return }
        guard currentWordIndex < totalWords else {
            // Reached end
            state = .paused
            onStateChange?(.paused)
            onComplete?()
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

        // Schedule next word
        timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer?.schedule(deadline: .now() + .milliseconds(delayMs))
        timer?.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, self.state == .playing else { return }
                self.currentWordIndex += 1
                self.scheduleNextWord()
            }
        }
        timer?.resume()
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private var lastChapterIndex: Int? = nil

    private func checkChapterChange() {
        guard let doc = document, let chapters = doc.chapters else { return }
        guard let word = currentWord else { return }
        guard let chapterIndex = word.chapterIndex else { return }

        if chapterIndex != lastChapterIndex {
            lastChapterIndex = chapterIndex
            if chapterIndex < chapters.count {
                onChapterChange?(chapters[chapterIndex])
            }
        }
    }

    deinit {
        stopTimer()
    }
}
