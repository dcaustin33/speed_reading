import SwiftUI

struct SearchView: View {
    @EnvironmentObject var router: NavigationRouter
    let bookId: UUID

    @State private var searchText = ""
    @State private var searchResults: [SearchResultPlaceholder] = []
    @State private var hasSearched = false

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.Colors.secondaryText)

                    TextField("Search...", text: $searchText)
                        .foregroundStyle(Theme.Colors.primaryText)
                        .submitLabel(.search)
                        .onSubmit {
                            performSearch()
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                            hasSearched = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding()
                .background(Theme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding()

                if hasSearched {
                    if searchResults.isEmpty {
                        // No results state
                        VStack(spacing: 12) {
                            Spacer()
                            Text("No results found")
                                .font(.headline)
                                .foregroundStyle(Theme.Colors.primaryText)
                            Text("Try a different search term")
                                .font(.subheadline)
                                .foregroundStyle(Theme.Colors.secondaryText)
                            Spacer()
                        }
                    } else {
                        // Results header
                        Text("\(searchResults.count) results")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                        // Results list
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(searchResults) { result in
                                    SearchResultRow(result: result) {
                                        // TODO: Jump to position
                                        router.pop()
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                } else {
                    // Initial state
                    VStack(spacing: 12) {
                        Spacer()
                        Text("Enter a phrase")
                            .font(.headline)
                            .foregroundStyle(Theme.Colors.primaryText)
                        Text("to search in book")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.secondaryText)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    router.pop()
                }
                .foregroundStyle(Theme.Colors.accent)
            }
        }
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func performSearch() {
        hasSearched = true
        // TODO: Implement actual search
        searchResults = []
    }
}

struct SearchResultPlaceholder: Identifiable {
    let id = UUID()
    let context: String
    let matchRange: Range<String.Index>?
    let percentage: Int
}

struct SearchResultRow: View {
    let result: SearchResultPlaceholder
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Text(result.context)
                    .font(.body)
                    .foregroundStyle(Theme.Colors.primaryText)
                    .lineLimit(2)

                Text("\(result.percentage)%")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding()
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

#Preview {
    NavigationStack {
        SearchView(bookId: UUID())
            .environmentObject(NavigationRouter())
    }
}
