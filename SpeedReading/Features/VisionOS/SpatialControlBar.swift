#if os(visionOS)
import SwiftUI

/// Immersive playback controls for the spatial reader.
/// Designed to be used as a RealityView Attachment below the ORP word.
struct SpatialControlBar: View {
    @State var viewModel: ReaderViewModel
    var onMenuTapped: () -> Void = {}

    @State private var ornamentVisible: Bool = true
    @State private var ornamentHideTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 8) {
            // Row 1: Playback controls
            HStack(spacing: 12) {
                TooltipButton(title: "Paragraph", systemImage: "backward.end.fill") {
                    handleInteraction()
                    viewModel.previousParagraph()
                }

                TooltipButton(title: "Sentence", systemImage: "backward.fill") {
                    handleInteraction()
                    viewModel.previousSentence()
                }

                TooltipButton(
                    title: viewModel.isPlaying ? "Pause" : "Play",
                    systemImage: viewModel.isPlaying ? "pause.fill" : "play.fill",
                    iconFont: .title3
                ) {
                    handleInteraction()
                    viewModel.toggle()
                }

                TooltipButton(title: "Sentence", systemImage: "forward.fill") {
                    handleInteraction()
                    viewModel.nextSentence()
                }

                TooltipButton(title: "Paragraph", systemImage: "forward.end.fill") {
                    handleInteraction()
                    viewModel.nextParagraph()
                }

                TooltipButton(title: "More", systemImage: "ellipsis") {
                    handleInteraction()
                    viewModel.pause()
                    onMenuTapped()
                }
            }

            // Row 2: Progress bar & stats
            VStack(spacing: 4) {
                ProgressBarView(
                    progress: viewModel.progress,
                    isScrubbing: viewModel.isScrubbing,
                    onScrubStart: {
                        handleInteraction()
                        viewModel.startScrubbing()
                    },
                    onScrubChange: { position in
                        viewModel.updateScrubPosition(position)
                    },
                    onScrubEnd: {
                        viewModel.endScrubbing()
                    }
                )

                StatsBarView(
                    wpm: viewModel.wpm,
                    timeRemaining: viewModel.remainingTimeFormatted,
                    progressPercentage: viewModel.progressPercentage,
                    chapterTimeRemaining: viewModel.chapterRemainingTimeFormatted
                )
            }
            .frame(width: 320)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassBackgroundEffect()
        .opacity(ornamentVisible ? 1 : 0)
        .allowsHitTesting(ornamentVisible)
        .animation(.easeInOut(duration: Theme.Animation.navigationOverlayFadeDuration), value: ornamentVisible)
        .onChange(of: viewModel.isPlaying) { _, isPlaying in
            if isPlaying {
                startHideTimer()
            } else {
                cancelHideTimer()
                withAnimation(.easeInOut(duration: Theme.Animation.navigationOverlayFadeDuration)) {
                    ornamentVisible = true
                }
            }
        }
        .onChange(of: viewModel.isCompleted) { _, isCompleted in
            if isCompleted {
                cancelHideTimer()
                withAnimation(.easeInOut(duration: Theme.Animation.navigationOverlayFadeDuration)) {
                    ornamentVisible = true
                }
            }
        }
        .onChange(of: viewModel.isScrubbing) { _, isScrubbing in
            if isScrubbing {
                cancelHideTimer()
            } else if viewModel.isPlaying {
                startHideTimer()
            }
        }
        .onDisappear {
            ornamentHideTask?.cancel()
        }
    }

    // MARK: - Auto-hide State Machine

    private func handleInteraction() {
        withAnimation(.easeInOut(duration: Theme.Animation.navigationOverlayFadeDuration)) {
            ornamentVisible = true
        }
        if viewModel.isPlaying {
            startHideTimer()
        }
    }

    private func startHideTimer() {
        ornamentHideTask?.cancel()
        ornamentHideTask = Task {
            try? await Task.sleep(for: .seconds(Theme.Animation.ornamentHideDelay))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: Theme.Animation.navigationOverlayFadeDuration)) {
                ornamentVisible = false
            }
        }
    }

    private func cancelHideTimer() {
        ornamentHideTask?.cancel()
        ornamentHideTask = nil
    }
}
#endif
