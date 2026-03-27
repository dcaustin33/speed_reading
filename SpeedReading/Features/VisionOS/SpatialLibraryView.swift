#if os(visionOS)
import SwiftUI
import RealityKit
import UniformTypeIdentifiers

struct SpatialLibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @Environment(SpatialNavigationState.self) private var spatialNavState

    @State private var shelfRoot = Entity()
    @State private var bookEntities: [UUID: ModelEntity] = [:]
    @State private var previousBookIDs: Set<UUID> = []

    private let bookSpacing: Float = 0.05
    private let maxBooksPerRow = 8
    private let rowSpacing: Float = 0.17

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    bookshelfView
                }

                if viewModel.isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle("Speed Reading")
            .navigationBarTitleDisplayMode(.automatic)
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) {
                if viewModel.isEditing {
                    editModeBar
                }
            }
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            if !viewModel.isEditing {
                importOrnament
            }
        }
        .fileImporter(
            isPresented: $viewModel.showingDocumentPicker,
            allowedContentTypes: [.plainText, UTType(filenameExtension: "md") ?? .plainText, .epub],
            onCompletion: { result in
                if case .success(let url) = result {
                    viewModel.handleFileSelected(url)
                }
            }
        )
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .alert("Delete Books", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("Delete", role: .destructive) { viewModel.deleteSelectedBooks() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \(viewModel.selectedCount) book\(viewModel.selectedCount == 1 ? "" : "s")? This cannot be undone.")
        }
        .onAppear { viewModel.loadLibrary() }
        .task(id: viewModel.sortedBooks.map(\.id)) {
            await rebuildShelf()
        }
    }

    // MARK: - Bookshelf RealityView

    private var bookshelfView: some View {
        RealityView { content, attachments in
            shelfRoot.name = "shelf"
            content.add(shelfRoot)
        } update: { content, attachments in
            // Sync title label attachments to book entities without covers
            for book in viewModel.sortedBooks {
                guard !book.hasCover,
                      let entity = bookEntities[book.id],
                      let attachment = attachments.entity(for: book.id) else { continue }
                if attachment.parent == nil {
                    attachment.position = [0, 0, SpatialBookEntity.bookDepth / 2 + 0.002]
                    entity.addChild(attachment)
                }
            }
        } attachments: {
            ForEach(viewModel.sortedBooks) { book in
                Attachment(id: book.id) {
                    VStack(spacing: 2) {
                        Text(book.title)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .lineLimit(3)
                        if let author = book.author {
                            Text(author)
                                .font(.system(size: 9))
                                .lineLimit(1)
                                .opacity(0.7)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: 60)
                    .multilineTextAlignment(.center)
                }
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    handleEntityTap(value.entity)
                }
        )
    }

    // MARK: - Shelf Management

    @MainActor
    private func rebuildShelf() async {
        let books = viewModel.sortedBooks
        let currentIDs = Set(books.map(\.id))
        let addedIDs = currentIDs.subtracting(previousBookIDs)

        // Clear and rebuild
        for child in shelfRoot.children {
            child.removeFromParent()
        }
        bookEntities.removeAll()

        for (index, book) in books.enumerated() {
            let coverImage = loadCoverUIImage(for: book)
            let entity = await SpatialBookEntity.create(for: book, coverImage: coverImage)
            positionBook(entity, at: index, total: books.count)
            shelfRoot.addChild(entity)
            bookEntities[book.id] = entity

            // Animate newly added books (skip initial load)
            if addedIDs.contains(book.id) && !previousBookIDs.isEmpty {
                SpatialBookEntity.animateAppear(entity)
            }
        }

        previousBookIDs = currentIDs
    }

    private func positionBook(_ entity: Entity, at index: Int, total: Int) {
        let col = index % maxBooksPerRow
        let row = index / maxBooksPerRow
        let booksInRow = min(total - row * maxBooksPerRow, maxBooksPerRow)

        // Center each row horizontally
        let totalWidth = Float(booksInRow - 1) * bookSpacing
        let x = -totalWidth / 2 + Float(col) * bookSpacing
        let y = -Float(row) * rowSpacing

        entity.position = [x, y, 0]
    }

    // MARK: - Interactions

    private func handleEntityTap(_ entity: Entity) {
        guard let bookComp = entity.components[BookComponent.self] else { return }

        if viewModel.isEditing {
            viewModel.toggleSelection(bookComp.bookID)
            let isSelected = viewModel.selectedBookIds.contains(bookComp.bookID)
            let scale: Float = isSelected ? 1.1 : 1.0
            let transform = Transform(
                scale: SIMD3<Float>(repeating: scale),
                rotation: entity.transform.rotation,
                translation: entity.transform.translation
            )
            entity.move(to: transform, relativeTo: entity.parent, duration: 0.15, timingFunction: .easeInOut)
        } else {
            SpatialBookEntity.animateSelectionPulse(entity)
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                spatialNavState.selectBook(bookComp.bookID)
            }
        }
    }

    // MARK: - Cover Image Loading

    private func loadCoverUIImage(for book: Book) -> UIImage? {
        guard book.hasCover else { return nil }
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let coverURL = documentsURL.appendingPathComponent("Covers/\(book.id.uuidString).jpg")
        return UIImage(contentsOfFile: coverURL.path)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Your library is empty")
                .font(.title2)

            Button("Import a Book") {
                viewModel.showingDocumentPicker = true
            }
            .buttonStyle(.borderedProminent)
            .hoverEffect(.highlight)
        }
        .padding(40)
        .glassBackgroundEffect()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your library is empty. Tap Import a Book to get started.")
    }

    // MARK: - Import Ornament

    private var importOrnament: some View {
        Button {
            viewModel.showingDocumentPicker = true
        } label: {
            Label("Import", systemImage: "plus")
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .glassBackgroundEffect()
        .hoverEffect(.highlight)
        .accessibilityLabel("Import book")
        .accessibilityHint("Opens file picker to import a book")
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Importing...")
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .glassBackgroundEffect()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Importing book, please wait")
    }

    // MARK: - Edit Mode Bar

    private var editModeBar: some View {
        HStack {
            Spacer()
            Button(role: .destructive) {
                viewModel.confirmDelete()
            } label: {
                Label("Delete", systemImage: "trash")
                    .foregroundStyle(viewModel.hasSelection ? .red : .secondary)
            }
            .disabled(!viewModel.hasSelection)
            .accessibilityLabel("Delete selected books")
            Spacer()
        }
        .padding(.vertical, 12)
        .glassBackgroundEffect()
    }

    // MARK: - Toolbar

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
                        // Reset entity scales on exit
                        for (_, entity) in bookEntities {
                            let transform = Transform(
                                scale: .one,
                                rotation: entity.transform.rotation,
                                translation: entity.transform.translation
                            )
                            entity.move(to: transform, relativeTo: entity.parent, duration: 0.15, timingFunction: .easeInOut)
                        }
                        viewModel.exitEditMode()
                    } else {
                        viewModel.enterEditMode()
                    }
                }
                .accessibilityLabel(viewModel.isEditing ? "Done editing" : "Edit library")
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
        }
        .accessibilityLabel("Sort books")
    }
}
#endif
