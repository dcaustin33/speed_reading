import SwiftUI

/// Displays a word with ORP (Optimal Recognition Point) highlighting.
/// The ORP character is highlighted in red and centered horizontally on screen.
struct ORPDisplayView: View {
    /// The word to display
    let word: String

    /// The ORP index for the word
    let orpIndex: Int

    /// Font size for the display (24-96pt)
    var fontSize: CGFloat = Theme.Layout.defaultFontSize

    /// Callback when chunk changes (for multi-chunk words)
    var onChunkChange: ((Int, Int) -> Void)?

    @State private var chunks: [ORPDisplayLogic.DisplayChunk] = []
    @State private var currentChunkIndex: Int = 0
    @State private var characterWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let currentChunk = chunks.isEmpty ? nil : chunks[min(currentChunkIndex, chunks.count - 1)]

            ZStack {
                #if os(visionOS)
                Color.clear
                #else
                Theme.Colors.background
                #endif

                if let chunk = currentChunk {
                    wordDisplay(chunk: chunk, containerWidth: availableWidth)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                containerWidth = availableWidth
                calculateCharacterWidth()
                updateChunks()
            }
            .onChange(of: word) { _, _ in
                currentChunkIndex = 0
                updateChunks()
            }
            .onChange(of: fontSize) { _, _ in
                calculateCharacterWidth()
                updateChunks()
            }
            .onChange(of: availableWidth) { _, newWidth in
                if abs(newWidth - containerWidth) > 1 {
                    containerWidth = newWidth
                    updateChunks()
                }
            }
        }
    }

    @ViewBuilder
    private func wordDisplay(chunk: ORPDisplayLogic.DisplayChunk, containerWidth: CGFloat) -> some View {
        let parts = chunk.parts
        let offset = calculateOffset(chunk: chunk, containerWidth: containerWidth)

        HStack(spacing: 0) {
            Text(parts.before)
                .foregroundStyle(Theme.Colors.primaryText)

            Text(parts.orp)
                .foregroundStyle(Theme.Colors.orpHighlight)

            Text(parts.after)
                .foregroundStyle(Theme.Colors.primaryText)
        }
        .font(Theme.Fonts.orpDisplay(size: fontSize))
        .offset(x: offset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(word)
        .accessibilityHint("ORP highlighted at position \(orpIndex + 1)")
    }

    private func calculateOffset(chunk: ORPDisplayLogic.DisplayChunk, containerWidth: CGFloat) -> CGFloat {
        guard characterWidth > 0 else { return 0 }

        // Calculate offset to center the ORP character
        let charOffset = ORPDisplayLogic.calculateCenteringOffset(
            wordLength: chunk.text.count,
            orpIndex: chunk.orpIndex
        )

        return CGFloat(charOffset) * characterWidth
    }

    private func calculateCharacterWidth() {
        characterWidth = FontMetrics.monospacedCharacterWidth(fontSize: fontSize)
    }

    private func updateChunks() {
        guard containerWidth > 0, characterWidth > 0 else {
            chunks = [ORPDisplayLogic.DisplayChunk(text: word, orpIndex: orpIndex)]
            return
        }

        // Calculate max characters that fit, leaving some padding
        let padding: CGFloat = 40 // 20pt padding on each side
        let availableWidth = containerWidth - padding
        let maxChars = ORPDisplayLogic.maxCharacters(forWidth: availableWidth, characterWidth: characterWidth)

        chunks = ORPDisplayLogic.chunkWord(word, maxCharacters: maxChars)

        // Notify about chunk info
        if chunks.count > 1 {
            onChunkChange?(currentChunkIndex, chunks.count)
        }
    }

    // MARK: - Public API for chunk navigation

    /// Advances to the next chunk if available
    /// Returns true if there was a next chunk, false if at end
    func advanceChunk() -> Bool {
        guard currentChunkIndex < chunks.count - 1 else { return false }
        currentChunkIndex += 1
        onChunkChange?(currentChunkIndex, chunks.count)
        return true
    }

    /// Resets to the first chunk
    func resetChunks() {
        currentChunkIndex = 0
        if chunks.count > 1 {
            onChunkChange?(0, chunks.count)
        }
    }

    /// Whether there are more chunks to display
    var hasMoreChunks: Bool {
        currentChunkIndex < chunks.count - 1
    }

    /// Current chunk index (0-based)
    var currentChunk: Int {
        currentChunkIndex
    }

    /// Total number of chunks
    var totalChunks: Int {
        chunks.count
    }
}

// MARK: - ORPDisplayViewModel for external state management

/// View model for managing ORP display state, especially for multi-chunk words
@Observable
class ORPDisplayViewModel {
    var word: String = ""
    var orpIndex: Int = 0
    var fontSize: CGFloat = Theme.Layout.defaultFontSize

    private(set) var chunks: [ORPDisplayLogic.DisplayChunk] = []
    private(set) var currentChunkIndex: Int = 0
    private var characterWidth: CGFloat = 0
    private var containerWidth: CGFloat = 0

    /// Updates the word to display
    func setWord(_ newWord: String, orpIndex: Int) {
        self.word = newWord
        self.orpIndex = orpIndex
        self.currentChunkIndex = 0
        recalculateChunks()
    }

    /// Updates the available container width
    func setContainerWidth(_ width: CGFloat) {
        if abs(width - containerWidth) > 1 {
            containerWidth = width
            recalculateChunks()
        }
    }

    /// Updates the font size and recalculates
    func setFontSize(_ size: CGFloat) {
        fontSize = size
        recalculateCharacterWidth()
        recalculateChunks()
    }

    /// Advances to the next chunk
    /// Returns true if there was a next chunk
    func advanceChunk() -> Bool {
        guard currentChunkIndex < chunks.count - 1 else { return false }
        currentChunkIndex += 1
        return true
    }

    /// Resets to first chunk
    func resetChunks() {
        currentChunkIndex = 0
    }

    /// Whether there are more chunks
    var hasMoreChunks: Bool {
        currentChunkIndex < chunks.count - 1
    }

    /// Current chunk to display
    var currentDisplayChunk: ORPDisplayLogic.DisplayChunk? {
        guard !chunks.isEmpty, currentChunkIndex < chunks.count else { return nil }
        return chunks[currentChunkIndex]
    }

    /// Chunk delay calculation
    func chunkDelay(forWordDelay wordDelay: TimeInterval) -> TimeInterval {
        ORPDisplayLogic.chunkDelay(totalWordDelay: wordDelay, chunkCount: chunks.count)
    }

    private func recalculateCharacterWidth() {
        characterWidth = FontMetrics.monospacedCharacterWidth(fontSize: fontSize)
    }

    private func recalculateChunks() {
        if characterWidth == 0 {
            recalculateCharacterWidth()
        }

        guard containerWidth > 0, characterWidth > 0 else {
            chunks = [ORPDisplayLogic.DisplayChunk(text: word, orpIndex: orpIndex)]
            return
        }

        let padding: CGFloat = 40
        let availableWidth = containerWidth - padding
        let maxChars = ORPDisplayLogic.maxCharacters(forWidth: availableWidth, characterWidth: characterWidth)

        chunks = ORPDisplayLogic.chunkWord(word, maxCharacters: maxChars)
    }
}

// MARK: - View using ViewModel

/// ORPDisplayView that uses a view model for external state management
struct ORPDisplayViewWithViewModel: View {
    @Bindable var viewModel: ORPDisplayViewModel

    var body: some View {
        GeometryReader { geometry in
            let chunk = viewModel.currentDisplayChunk

            ZStack {
                Theme.Colors.background

                if let chunk = chunk {
                    wordDisplay(chunk: chunk, containerWidth: geometry.size.width)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                viewModel.setContainerWidth(geometry.size.width)
            }
            .onChange(of: geometry.size.width) { _, newWidth in
                viewModel.setContainerWidth(newWidth)
            }
        }
    }

    @ViewBuilder
    private func wordDisplay(chunk: ORPDisplayLogic.DisplayChunk, containerWidth: CGFloat) -> some View {
        let parts = chunk.parts
        let offset = calculateOffset(chunk: chunk, containerWidth: containerWidth)

        HStack(spacing: 0) {
            Text(parts.before)
                .foregroundStyle(Theme.Colors.primaryText)

            Text(parts.orp)
                .foregroundStyle(Theme.Colors.orpHighlight)

            Text(parts.after)
                .foregroundStyle(Theme.Colors.primaryText)
        }
        .font(Theme.Fonts.orpDisplay(size: viewModel.fontSize))
        .offset(x: offset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(viewModel.word)
    }

    private func calculateOffset(chunk: ORPDisplayLogic.DisplayChunk, containerWidth: CGFloat) -> CGFloat {
        let characterWidth = FontMetrics.monospacedCharacterWidth(fontSize: viewModel.fontSize)

        let charOffset = ORPDisplayLogic.calculateCenteringOffset(
            wordLength: chunk.text.count,
            orpIndex: chunk.orpIndex
        )

        return CGFloat(charOffset) * characterWidth
    }
}

// MARK: - Previews

#Preview("Single Word") {
    ORPDisplayView(word: "hello", orpIndex: 1)
        .frame(height: 200)
}

#Preview("Long Word") {
    ORPDisplayView(word: "extraordinary", orpIndex: 3)
        .frame(height: 200)
}

#Preview("Very Long Word") {
    ORPDisplayView(word: "supercalifragilisticexpialidocious", orpIndex: 4)
        .frame(height: 200)
}

#Preview("Single Character") {
    ORPDisplayView(word: "I", orpIndex: 0)
        .frame(height: 200)
}

#Preview("Different Font Sizes") {
    VStack(spacing: 40) {
        ORPDisplayView(word: "reading", orpIndex: 2, fontSize: 24)
            .frame(height: 60)

        ORPDisplayView(word: "reading", orpIndex: 2, fontSize: 48)
            .frame(height: 80)

        ORPDisplayView(word: "reading", orpIndex: 2, fontSize: 72)
            .frame(height: 100)

        ORPDisplayView(word: "reading", orpIndex: 2, fontSize: 96)
            .frame(height: 120)
    }
    .background(Theme.Colors.background)
}

#Preview("With ViewModel") {
    struct PreviewContainer: View {
        @State var viewModel = ORPDisplayViewModel()

        var body: some View {
            VStack {
                ORPDisplayViewWithViewModel(viewModel: viewModel)
                    .frame(height: 200)

                Button("Change Word") {
                    let words = ["hello", "world", "extraordinary", "I", "test"]
                    guard let word = words.randomElement() else { return }
                    viewModel.setWord(word, orpIndex: ORPCalculator.calculateORPIndex(for: word))
                }
            }
            .onAppear {
                viewModel.setWord("hello", orpIndex: 1)
            }
        }
    }
    return PreviewContainer()
}
