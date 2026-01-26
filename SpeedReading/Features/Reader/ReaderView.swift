import SwiftUI
import UIKit

/// Main reading screen with ORP display, playback controls, and progress tracking.
struct ReaderView: View {
    @EnvironmentObject var router: NavigationRouter
    @Environment(\.scenePhase) private var scenePhase
    let bookId: UUID

    @State private var viewModel: ReaderViewModel
    @State private var showMenu = false

    // Haptic feedback generator for sentence boundaries
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)

    init(bookId: UUID) {
        self.bookId = bookId
        self._viewModel = State(wrappedValue: ReaderViewModel(bookId: bookId))
    }

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else {
                readerContent

                // Chapter transition overlay (per spec Section 3.7)
                // Displayed on top of reader content, playback continues behind it
                ChapterOverlayView(
                    chapterTitle: viewModel.currentChapterTitle,
                    isVisible: viewModel.isChapterOverlayVisible
                )

                // Completion overlay (per spec Section 3.8)
                // Only dismissal option is the "Return to Library" button
                if viewModel.isCompleted {
                    CompletionOverlayView(
                        bookTitle: viewModel.bookTitle,
                        isVisible: viewModel.isCompleted,
                        onDismiss: {
                            viewModel.dismissCompletion()
                            router.pop()
                        }
                    )
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                backButton
            }
        }
        .sheet(isPresented: $showMenu) {
            MenuView(bookId: bookId, showMenu: $showMenu, viewModel: viewModel)
        }
        .task {
            viewModel.loadBook()
            hapticGenerator.prepare()
            setupHapticCallback()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.accent))
                .scaleEffect(1.5)

            Text("Loading book...")
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading book, please wait")
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.orpHighlight)
                .accessibilityHidden(true)

            Text(message)
                .foregroundStyle(Theme.Colors.primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Return to Library") {
                router.pop()
            }
            .foregroundStyle(Theme.Colors.accent)
            .accessibilityLabel("Return to Library")
            .accessibilityHint("Go back to your book list")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error: \(message)")
    }

    // MARK: - Reader Content

    private var readerContent: some View {
        VStack(spacing: 0) {
            // Main content area - tap to toggle play/pause
            tapArea

            // Menu button area
            menuButtonArea

            // Bottom controls area
            bottomControls
        }
    }

    // MARK: - Tap Area (ORP Display)

    private var tapArea: some View {
        Button {
            viewModel.toggle()
        } label: {
            GeometryReader { geometry in
                ORPDisplayView(
                    word: viewModel.currentWord,
                    orpIndex: viewModel.currentOrpIndex,
                    fontSize: CGFloat(viewModel.fontSize)
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.isPlaying ? "Pause reading" : "Resume reading")
        .accessibilityHint("Tap to toggle playback")
    }

    // MARK: - Menu Button

    private var menuButtonArea: some View {
        HStack {
            Spacer()
            Button {
                viewModel.pause()
                showMenu = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.primaryText)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Open menu")
            .accessibilityHint("Access navigation, settings, and search")
        }
        .padding(.trailing, 8)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 8) {
            // Progress bar
            ProgressBarView(
                progress: viewModel.progress,
                isScrubbing: viewModel.isScrubbing,
                onScrubStart: {
                    viewModel.startScrubbing()
                },
                onScrubChange: { position in
                    viewModel.updateScrubPosition(position)
                },
                onScrubEnd: {
                    viewModel.endScrubbing()
                }
            )

            // Stats bar
            StatsBarView(
                wpm: viewModel.wpm,
                timeRemaining: viewModel.remainingTimeFormatted,
                progressPercentage: viewModel.progressPercentage
            )
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Back Button

    private var backButton: some View {
        Button {
            viewModel.onDisappear()
            router.pop()
        } label: {
            Image(systemName: "chevron.left")
                .foregroundStyle(Theme.Colors.primaryText)
        }
        .accessibilityLabel("Back to library")
        .accessibilityHint("Save progress and return to your book list")
    }

    // MARK: - Scene Phase Handling

    /// Handles app lifecycle changes per spec Section 3.9
    /// Auto-pauses playback when app goes to background or system overlays appear
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        // Per spec Section 3.9: Pause triggers
        // - App moves to background
        // - Screen locks
        // - Incoming phone call
        // - Control Center or Notification Center opens
        // - Any system overlay appears

        guard viewModel.isPlaying else { return }

        switch newPhase {
        case .inactive:
            // System overlay appeared (Control Center, Notification Center, incoming call)
            viewModel.pause()
            viewModel.saveProgress()
        case .background:
            // App moved to background or screen locked
            viewModel.pause()
            viewModel.saveProgress()
        case .active:
            // Returning to app - per spec, "Playback does NOT auto-resume"
            // Do nothing
            break
        @unknown default:
            break
        }
    }

    // MARK: - Haptic Feedback Setup

    /// Sets up haptic feedback callback for sentence boundaries
    private func setupHapticCallback() {
        viewModel.onSentenceBoundary = { [hapticGenerator] in
            // Respect system haptics setting via UIFeedbackGenerator
            // UIImpactFeedbackGenerator automatically respects system settings
            hapticGenerator.impactOccurred()
        }
    }
}

#Preview {
    NavigationStack {
        ReaderView(bookId: UUID())
            .environmentObject(NavigationRouter())
    }
}
