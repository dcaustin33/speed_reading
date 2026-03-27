import SwiftUI

/// Table of Contents screen for EPUB navigation.
/// Displays chapter list with current chapter indicator.
/// Per spec (Section 4.5): Only shown for EPUB files with TOC.
struct TOCView: View {
    @EnvironmentObject var router: NavigationRouter

    let bookId: UUID
    let currentWordIndex: Int

    @State private var viewModel: TOCViewModel?

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            if let viewModel = viewModel {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(Theme.Colors.accent)
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else if viewModel.hasChapters {
                    chapterList(viewModel: viewModel)
                } else {
                    emptyView
                }
            } else {
                ProgressView()
                    .tint(Theme.Colors.accent)
            }
        }
        .navigationTitle("Contents")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    router.pop()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    #if !os(visionOS)
                    .foregroundStyle(Theme.Colors.accent)
                    #endif
                }
                .accessibilityLabel("Back to menu")
            }
        }
        #if !os(visionOS)
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
        .onAppear {
            if viewModel == nil {
                let vm = TOCViewModel(bookId: bookId, currentWordIndex: currentWordIndex)
                viewModel = vm
                vm.loadChapters()
            }
        }
    }

    // MARK: - Chapter List

    @ViewBuilder
    private func chapterList(viewModel: TOCViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                #if os(visionOS)
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.chapters.enumerated()), id: \.offset) { index, chapter in
                        let isCurrent = viewModel.currentChapterIndex == index

                        Button {
                            viewModel.selectChapter(at: index)
                            router.popToRoot()
                            router.navigateTo(.reader(bookId: bookId))
                        } label: {
                            chapterRow(chapter: chapter, isCurrent: isCurrent)
                        }
                        .buttonStyle(.plain)
                        .id(index)
                        .accessibilityLabel("\(chapter.title)\(isCurrent ? ", current chapter" : "")")
                        .accessibilityHint("Double tap to jump to this chapter")

                        if index < viewModel.chapters.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(24)
                #else
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.chapters.enumerated()), id: \.offset) { index, chapter in
                        let isCurrent = viewModel.currentChapterIndex == index

                        Button {
                            viewModel.selectChapter(at: index)
                            router.popToRoot()
                            router.navigateTo(.reader(bookId: bookId))
                        } label: {
                            chapterRow(chapter: chapter, isCurrent: isCurrent)
                        }
                        .id(index)
                        .accessibilityLabel("\(chapter.title)\(isCurrent ? ", current chapter" : "")")
                        .accessibilityHint("Double tap to jump to this chapter")

                        if index < viewModel.chapters.count - 1 {
                            Divider()
                                .background(Theme.Colors.trackGray)
                        }
                    }
                }
                .padding(.top)
                #endif
            }
            .onAppear {
                if let currentIndex = viewModel.currentChapterIndex {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(currentIndex, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func chapterRow(chapter: Chapter, isCurrent: Bool) -> some View {
        HStack {
            Text(chapter.title)
                .font(.body)
                .foregroundStyle(Theme.Colors.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isCurrent {
                Image(systemName: "checkmark")
                    .foregroundStyle(Theme.Colors.accent)
                    .accessibilityHidden(true)
            }
        }
        .padding()
        #if !os(visionOS)
        .background(Theme.Colors.cardBackground)
        #endif
    }

    // MARK: - Empty State

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.secondaryText)

            Text("No chapters found")
                .font(.headline)
                .foregroundStyle(Theme.Colors.primaryText)

            Text("This book does not have a table of contents.")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Error State

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.secondaryText)

            Text("Could not load chapters")
                .font(.headline)
                .foregroundStyle(Theme.Colors.primaryText)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview("With Chapters") {
    NavigationStack {
        TOCView(bookId: UUID(), currentWordIndex: 500)
            .environmentObject(NavigationRouter())
    }
}

#Preview("Empty") {
    NavigationStack {
        TOCView(bookId: UUID(), currentWordIndex: 0)
            .environmentObject(NavigationRouter())
    }
}
