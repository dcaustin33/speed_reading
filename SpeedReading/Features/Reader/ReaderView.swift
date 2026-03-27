import SwiftUI

/// Main reading screen with ORP display, playback controls, and progress tracking.
struct ReaderView: View {
    @EnvironmentObject var router: NavigationRouter
    @Environment(\.scenePhase) private var scenePhase
    #if os(visionOS)
    @Environment(SpatialNavigationState.self) private var spatialNavState
    @Environment(\.dismissWindow) private var dismissWindow
    #endif
    let bookId: UUID

    @State private var viewModel: ReaderViewModel
    @State private var showMenu = false

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

                // Paragraph preview overlay
                if viewModel.isParagraphPreviewVisible {
                    ParagraphOverlayView(
                        paragraphText: viewModel.paragraphPreviewText,
                        highlightWordIndex: viewModel.paragraphHighlightWordIndex,
                        onDismiss: {
                            viewModel.hideParagraphPreview()
                        }
                    )
                    .animation(.easeInOut(duration: 0.2), value: viewModel.isParagraphPreviewVisible)
                }

                // Completion overlay (per spec Section 3.8)
                // Only dismissal option is the "Return to Library" button
                if viewModel.isCompleted {
                    CompletionOverlayView(
                        bookTitle: viewModel.bookTitle,
                        isVisible: viewModel.isCompleted,
                        onDismiss: {
                            viewModel.dismissCompletion()
                            #if os(visionOS)
                            spatialNavState.closeReader()
                            dismissWindow(id: "reader")
                            #else
                            router.pop()
                            #endif
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
        .onChange(of: showMenu) { _, isShowing in
            if !isShowing {
                viewModel.reloadSettings()
            }
        }
        .task {
            viewModel.loadBook()
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
                #if os(visionOS)
                .foregroundStyle(.red)
                #else
                .foregroundStyle(Theme.Colors.orpHighlight)
                #endif
                .accessibilityHidden(true)

            Text(message)
                .foregroundStyle(Theme.Colors.primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Return to Library") {
                #if os(visionOS)
                spatialNavState.closeReader()
                dismissWindow(id: "reader")
                #else
                router.pop()
                #endif
            }
            #if os(visionOS)
            .buttonStyle(.bordered)
            .hoverEffect(.highlight)
            #else
            .foregroundStyle(Theme.Colors.accent)
            #endif
            .accessibilityLabel("Return to Library")
            .accessibilityHint("Go back to your book list")
        }
        #if os(visionOS)
        .padding(32)
        .glassBackgroundEffect()
        #endif
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error: \(message)")
    }

    // MARK: - Reader Content

    private var readerContent: some View {
        ZStack {
            VStack(spacing: 0) {
                // Main content area - tap to toggle play/pause
                tapArea

                // Menu button area
                menuButtonArea

                // Bottom controls area
                bottomControls
            }

            // Navigation overlay with prev/next sentence and paragraph buttons
            NavigationOverlayView(
                isVisible: viewModel.isNavigationOverlayVisible,
                onPreviousSentence: {
                    viewModel.previousSentence()
                },
                onNextSentence: {
                    viewModel.nextSentence()
                },
                onPreviousParagraph: {
                    viewModel.previousParagraph()
                },
                onNextParagraph: {
                    viewModel.nextParagraph()
                }
            )
        }
    }

    // MARK: - Tap Area (ORP Display)

    private var tapArea: some View {
        GeometryReader { geometry in
            ORPDisplayView(
                word: viewModel.currentWord,
                orpIndex: viewModel.currentOrpIndex,
                fontSize: CGFloat(viewModel.fontSize)
            )
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: Theme.Navigation.minimumSwipeDistance, coordinateSpace: .local)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = value.translation.height
                    // Only trigger if swipe is primarily horizontal
                    if abs(horizontal) > abs(vertical) {
                        if horizontal > 0 {
                            viewModel.previousSentence()
                        } else {
                            viewModel.nextSentence()
                        }
                    }
                }
        )
        .simultaneousGesture(
            TapGesture().onEnded {
                viewModel.toggle()
            }
        )
        .accessibilityLabel(viewModel.isPlaying ? "Pause reading" : "Resume reading")
        .accessibilityHint("Tap to toggle playback. Swipe left or right to navigate sentences.")
    }

    // MARK: - Menu Button

    private var menuButtonArea: some View {
        HStack {
            Spacer()

            // Paragraph preview button
            Button {
                viewModel.showParagraphPreview()
            } label: {
                Image(systemName: "text.justify.left")
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.primaryText)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Show full paragraph")
            .accessibilityHint("Display the current paragraph in traditional reading format")

            // Navigation overlay toggle button
            Button {
                viewModel.toggleNavigationOverlay()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.title2)
                    .foregroundStyle(viewModel.isNavigationOverlayVisible ? Theme.Colors.accent : Theme.Colors.primaryText)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Toggle sentence navigation")
            .accessibilityHint(viewModel.isNavigationOverlayVisible ? "Hide navigation buttons" : "Show navigation buttons")

            // Menu button
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
                progressPercentage: viewModel.progressPercentage,
                chapterTimeRemaining: viewModel.chapterRemainingTimeFormatted
            )
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Back Button

    private var backButton: some View {
        Button {
            #if os(visionOS)
            spatialNavState.closeReader()
            dismissWindow(id: "reader")
            #else
            router.pop()
            #endif
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

}

#Preview {
    NavigationStack {
        ReaderView(bookId: UUID())
            .environmentObject(NavigationRouter())
    }
}
