import SwiftUI

struct TOCView: View {
    @EnvironmentObject var router: NavigationRouter
    let bookId: UUID

    // Placeholder chapters
    @State private var chapters: [ChapterPlaceholder] = [
        ChapterPlaceholder(title: "Cover", isCurrent: false),
        ChapterPlaceholder(title: "Chapter 1: The Beginning", isCurrent: false),
        ChapterPlaceholder(title: "Chapter 2: Rising Action", isCurrent: true),
        ChapterPlaceholder(title: "Chapter 3: The Climax", isCurrent: false),
        ChapterPlaceholder(title: "Chapter 4: Resolution", isCurrent: false),
        ChapterPlaceholder(title: "Epilogue", isCurrent: false),
    ]

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(chapters) { chapter in
                        Button {
                            // TODO: Jump to chapter
                            router.pop()
                        } label: {
                            HStack {
                                Text(chapter.title)
                                    .font(.body)
                                    .foregroundStyle(Theme.Colors.primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if chapter.isCurrent {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.Colors.accent)
                                }
                            }
                            .padding()
                            .background(Theme.Colors.cardBackground)
                        }

                        Divider()
                            .background(Theme.Colors.trackGray)
                    }
                }
                .padding(.top)
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
                    .foregroundStyle(Theme.Colors.accent)
                }
            }
        }
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct ChapterPlaceholder: Identifiable {
    let id = UUID()
    let title: String
    let isCurrent: Bool
}

#Preview {
    NavigationStack {
        TOCView(bookId: UUID())
            .environmentObject(NavigationRouter())
    }
}
