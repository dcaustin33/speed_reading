import SwiftUI

/// Search screen for finding text within a book.
/// Per spec Section 4.4: Case-insensitive exact word sequence match.
struct SearchView: View {
    @EnvironmentObject var router: NavigationRouter
    @FocusState private var isSearchFieldFocused: Bool
    let bookId: UUID

    @State private var viewModel: SearchViewModel

    init(bookId: UUID) {
        self.bookId = bookId
        self._viewModel = State(wrappedValue: SearchViewModel(bookId: bookId))
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
                searchContent
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
        .task {
            viewModel.loadDocument()
            isSearchFieldFocused = true
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.accent))
                .scaleEffect(1.5)

            Text("Loading...")
                .foregroundStyle(Theme.Colors.secondaryText)
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.orpHighlight)

            Text(message)
                .foregroundStyle(Theme.Colors.primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Go Back") {
                router.pop()
            }
            .foregroundStyle(Theme.Colors.accent)
        }
    }

    // MARK: - Search Content

    private var searchContent: some View {
        VStack(spacing: 0) {
            // Search field
            searchField
                .padding()

            // Results area
            if viewModel.hasSearched {
                if viewModel.results.isEmpty {
                    noResultsView
                } else {
                    resultsView
                }
            } else {
                initialStateView
            }
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Colors.secondaryText)

            TextField("Search...", text: $viewModel.searchText)
                .foregroundStyle(Theme.Colors.primaryText)
                .submitLabel(.search)
                .focused($isSearchFieldFocused)
                .onSubmit {
                    viewModel.performSearch()
                }
                .accessibilityLabel("Search text")
                .accessibilityHint("Type a phrase to search in the book")

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.clearSearch()
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
    }

    // MARK: - Initial State View

    private var initialStateView: some View {
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Enter a phrase to search in book")
    }

    // MARK: - No Results View

    private var noResultsView: some View {
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No results found. Try a different search term.")
    }

    // MARK: - Results View

    private var resultsView: some View {
        VStack(spacing: 0) {
            // Results count header
            Text(viewModel.resultsCountText)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 8)

            // Results list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.results) { result in
                        SearchResultRow(result: result) {
                            selectResult(result)
                        }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Result Selection

    private func selectResult(_ result: SearchResult) {
        // Store the jump position
        viewModel.selectResult(result)

        // Per spec: "close search, close menu, stay paused"
        // Pop twice: once for search, once for menu
        // The menu is presented as a sheet, so we need to pop back to the reader
        // and let it handle closing the menu

        // Navigate back to reader (search will pop)
        // The ReaderView will detect the jump position on appear
        router.popToRoot()
        // Push back to reader with the book ID
        router.navigateTo(.reader(bookId: bookId))
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: SearchResult
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Context with highlighted match
                highlightedContext
                    .font(.body)
                    .lineLimit(2)

                // Position percentage
                Text("\(Int(result.percentage))%")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding()
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityLabel("Search result at \(Int(result.percentage)) percent")
        .accessibilityHint("Tap to jump to this position")
    }

    /// Renders the context with the match highlighted in bold white
    private var highlightedContext: some View {
        // Parse the context string which uses ** markers for highlighting
        // Format: "...before **matched text** after..."
        let parts = parseHighlightedText(result.context)

        return parts.reduce(Text("")) { result, part in
            if part.isHighlighted {
                // Per spec: Match highlight is bold white (#FFFFFF)
                return result + Text(part.text)
                    .foregroundColor(Color.white)
                    .bold()
            } else {
                return result + Text(part.text)
                    .foregroundColor(Theme.Colors.primaryText)
            }
        }
    }

    private struct TextPart {
        let text: String
        let isHighlighted: Bool
    }

    private func parseHighlightedText(_ input: String) -> [TextPart] {
        var parts: [TextPart] = []
        var current = input
        var isInHighlight = false

        while !current.isEmpty {
            if let range = current.range(of: "**") {
                // Add text before the marker
                let before = String(current[..<range.lowerBound])
                if !before.isEmpty {
                    parts.append(TextPart(text: before, isHighlighted: isInHighlight))
                }

                // Toggle highlight state
                isInHighlight.toggle()

                // Move past the marker
                current = String(current[range.upperBound...])
            } else {
                // No more markers, add remaining text
                parts.append(TextPart(text: current, isHighlighted: isInHighlight))
                break
            }
        }

        return parts
    }
}

#Preview("Initial State") {
    NavigationStack {
        SearchView(bookId: UUID())
            .environmentObject(NavigationRouter())
    }
}

#Preview("With Results") {
    // Preview with mock results would require setting up mock data
    NavigationStack {
        SearchView(bookId: UUID())
            .environmentObject(NavigationRouter())
    }
}
