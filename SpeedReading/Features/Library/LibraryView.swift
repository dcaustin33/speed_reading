import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject var router: NavigationRouter
    @StateObject private var viewModel = LibraryViewModel()

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
        .fileImporter(
            isPresented: $viewModel.showingDocumentPicker,
            allowedContentTypes: [.plainText, UTType(filenameExtension: "md") ?? .plainText, .epub],
            onCompletion: { result in
                switch result {
                case .success(let url):
                    viewModel.handleFileSelected(url)
                case .failure:
                    break
                }
            }
        )
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .onAppear {
            viewModel.loadLibrary()
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
                .accessibilityHidden(true)

            Text("Your library is empty")
                .font(.title2)
                .foregroundStyle(Theme.Colors.primaryText)

            Text("Tap the + button to import books from Files")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your library is empty. Tap the plus button to import books from Files.")
    }

    private var libraryGridView: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: LayoutHelper.libraryGridColumns(for: geometry.size.width), spacing: 20) {
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
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    handleBookLongPress(book)
                                }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, viewModel.isEditing ? 100 : 80)
            }
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
        .accessibilityHint("Opens file picker to import a book from Files")
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Importing book, please wait")
            .accessibilityAddTraits(.isStaticText)
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
            .accessibilityLabel("Delete selected books")
            .accessibilityHint(viewModel.hasSelection ? "Double tap to delete \(viewModel.selectedCount) book\(viewModel.selectedCount == 1 ? "" : "s")" : "Select books first to delete")

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
                .accessibilityLabel(viewModel.isEditing ? "Done editing" : "Edit library")
                .accessibilityHint(viewModel.isEditing ? "Exit edit mode" : "Enter edit mode to select and delete books")
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
        .accessibilityLabel("Sort books")
        .accessibilityHint("Currently sorted by \(viewModel.sortOrder == .recent ? "recently opened" : "title")")
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
