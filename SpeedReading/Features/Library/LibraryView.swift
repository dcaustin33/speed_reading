import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var router: NavigationRouter
    @StateObject private var viewModel = LibraryViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            if viewModel.isEmpty {
                emptyStateView
            } else {
                libraryGridView
            }

            // Floating action button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    addButton
                        .padding(.trailing, 24)
                        .padding(.bottom, viewModel.isEditing ? 80 : 24)
                }
            }

            // Loading overlay
            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .navigationTitle("Speed Reading")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            if viewModel.isEditing {
                editModeToolbar
            }
        }
        .documentPicker(
            isPresented: $viewModel.showingDocumentPicker,
            onSelect: { url in
                viewModel.handleFileSelected(url)
            }
        )
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .alert("Delete Books", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                viewModel.deleteSelectedBooks()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \(viewModel.selectedCount) book\(viewModel.selectedCount == 1 ? "" : "s")? This cannot be undone.")
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.Colors.secondaryText)

            Text("Your library is empty")
                .font(.title2)
                .foregroundStyle(Theme.Colors.primaryText)

            Text("Tap the + button to import books from Files")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var libraryGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(viewModel.sortedBooks) { book in
                    BookCardView(
                        book: book,
                        isSelected: viewModel.selectedBookIds.contains(book.id),
                        isEditing: viewModel.isEditing,
                        coverImage: viewModel.loadCoverImage(for: book)
                    )
                    .onTapGesture {
                        handleBookTap(book)
                    }
                    .onLongPressGesture {
                        handleBookLongPress(book)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, viewModel.isEditing ? 100 : 80)
        }
    }

    private var addButton: some View {
        Button {
            viewModel.showingDocumentPicker = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Theme.Colors.accent)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        }
        .accessibilityLabel("Import book")
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primaryText))
                    .scaleEffect(1.5)

                Text("Importing...")
                    .foregroundStyle(Theme.Colors.primaryText)
            }
            .padding(32)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var editModeToolbar: some View {
        HStack {
            Spacer()

            Button(role: .destructive) {
                viewModel.confirmDelete()
            } label: {
                Label("Delete", systemImage: "trash")
                    .foregroundStyle(viewModel.hasSelection ? .red : Theme.Colors.secondaryText)
            }
            .disabled(!viewModel.hasSelection)

            Spacer()
        }
        .padding(.vertical, 12)
        .background(Theme.Colors.cardBackground)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if !viewModel.isEmpty {
                sortMenu
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            if !viewModel.isEmpty {
                Button(viewModel.isEditing ? "Done" : "Edit") {
                    if viewModel.isEditing {
                        viewModel.exitEditMode()
                    } else {
                        viewModel.enterEditMode()
                    }
                }
                .foregroundStyle(Theme.Colors.accent)
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Button {
                viewModel.sortOrder = .recent
            } label: {
                Label("Recently Opened", systemImage: viewModel.sortOrder == .recent ? "checkmark" : "")
            }

            Button {
                viewModel.sortOrder = .title
            } label: {
                Label("Title", systemImage: viewModel.sortOrder == .title ? "checkmark" : "")
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
                .foregroundStyle(Theme.Colors.accent)
        }
    }

    // MARK: - Actions

    private func handleBookTap(_ book: Book) {
        if viewModel.isEditing {
            viewModel.toggleSelection(book.id)
        } else {
            router.navigateTo(.reader(bookId: book.id))
        }
    }

    private func handleBookLongPress(_ book: Book) {
        if !viewModel.isEditing {
            viewModel.enterEditMode(selecting: book.id)
        }
    }
}

#Preview("Empty Library") {
    NavigationStack {
        LibraryView()
            .environmentObject(NavigationRouter())
    }
}
