import SwiftUI
import Combine

/// View model for the Library screen.
/// Manages library state, book loading, sorting, edit mode, and import flow.
@MainActor
final class LibraryViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var books: [Book] = []
    @Published private(set) var isLoading = false
    @Published var isEditing = false
    @Published var selectedBookIds: Set<UUID> = []
    @Published var showingDocumentPicker = false
    @Published var showingDeleteConfirmation = false
    @Published var errorMessage: String?
    @Published var showingError = false

    // MARK: - Settings

    @Published var sortOrder: SortOrder = .recent {
        didSet {
            if sortOrder != oldValue {
                updateSortOrder(sortOrder)
            }
        }
    }

    // MARK: - Dependencies

    private let libraryService: LibraryDataService
    private let fileManager = FileManager.default

    // MARK: - Computed Properties

    var isEmpty: Bool { books.isEmpty }

    var sortedBooks: [Book] {
        switch sortOrder {
        case .recent:
            return books.sorted { book1, book2 in
                switch (book1.dateLastOpened, book2.dateLastOpened) {
                case (nil, nil):
                    return book1.dateAdded > book2.dateAdded
                case (nil, _):
                    return false
                case (_, nil):
                    return true
                case let (date1?, date2?):
                    return date1 > date2
                }
            }
        case .title:
            return books.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
    }

    var hasSelection: Bool { !selectedBookIds.isEmpty }

    var selectedCount: Int { selectedBookIds.count }

    // MARK: - Initialization

    init(libraryService: LibraryDataService = LibraryDataService()) {
        self.libraryService = libraryService
        loadLibrary()
    }

    // MARK: - Library Operations

    func loadLibrary() {
        do {
            try libraryService.loadLibrary()
            books = libraryService.books
            sortOrder = libraryService.settings.librarySort
        } catch {
            showError("Failed to load library: \(error.localizedDescription)")
        }
    }

    func refreshBooks() {
        books = libraryService.books
    }

    private func updateSortOrder(_ order: SortOrder) {
        var settings = libraryService.settings
        settings.librarySort = order
        libraryService.settings = settings
        do {
            try libraryService.saveLibrary()
        } catch {
            showError("Failed to save settings: \(error.localizedDescription)")
        }
    }

    // MARK: - Edit Mode

    func enterEditMode(selecting bookId: UUID? = nil) {
        isEditing = true
        selectedBookIds.removeAll()
        if let bookId = bookId {
            selectedBookIds.insert(bookId)
        }
    }

    func exitEditMode() {
        isEditing = false
        selectedBookIds.removeAll()
    }

    func toggleSelection(_ bookId: UUID) {
        if selectedBookIds.contains(bookId) {
            selectedBookIds.remove(bookId)
        } else {
            selectedBookIds.insert(bookId)
        }
    }

    func selectAll() {
        selectedBookIds = Set(books.map { $0.id })
    }

    func deselectAll() {
        selectedBookIds.removeAll()
    }

    // MARK: - Book Deletion

    func confirmDelete() {
        showingDeleteConfirmation = true
    }

    func deleteSelectedBooks() {
        do {
            try libraryService.deleteBooks(Array(selectedBookIds))
            books = libraryService.books
            selectedBookIds.removeAll()

            // Exit edit mode if no books left
            if books.isEmpty {
                isEditing = false
            }
        } catch {
            showError("Failed to delete books: \(error.localizedDescription)")
        }
    }

    // MARK: - Book Import

    func handleFileSelected(_ url: URL) {
        isLoading = true

        Task {
            do {
                // Validate file type
                let fileType = try FileImportService.validateFileType(url: url)

                // Extract title from filename
                let filename = url.lastPathComponent
                let title = extractTitle(from: filename)

                // Load file content based on type
                switch fileType {
                case .txt:
                    let result = try FileImportService.loadTextFile(from: url)
                    _ = try libraryService.importBook(
                        title: title,
                        author: nil,
                        filename: filename,
                        fileType: fileType,
                        content: result.content,
                        fileHash: result.hash,
                        coverData: nil,
                        hasTOC: false,
                        chapters: nil
                    )

                case .md:
                    let result = try FileImportService.loadMarkdownFile(from: url)
                    _ = try libraryService.importBook(
                        title: title,
                        author: nil,
                        filename: filename,
                        fileType: fileType,
                        content: result.content,
                        fileHash: result.hash,
                        coverData: nil,
                        hasTOC: false,
                        chapters: nil
                    )

                case .epub:
                    let epubResult = try EPUBImportService.loadEPUB(from: url)
                    _ = try libraryService.importBook(
                        title: epubResult.metadata.title,
                        author: epubResult.metadata.author,
                        filename: filename,
                        fileType: fileType,
                        content: epubResult.content,
                        fileHash: epubResult.hash,
                        coverData: epubResult.coverData,
                        hasTOC: epubResult.hasTOC,
                        chapters: epubResult.chapters
                    )
                }

                refreshBooks()
            } catch let error as FileImportError {
                showError(error.localizedDescription)
            } catch {
                showError("Failed to import file: \(error.localizedDescription)")
            }

            isLoading = false
        }
    }

    private func extractTitle(from filename: String) -> String {
        // Remove extension
        let name = (filename as NSString).deletingPathExtension

        // Replace underscores and dashes with spaces
        return name
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Cover Image Loading

    func loadCoverImage(for book: Book) -> Image? {
        guard book.hasCover else { return nil }

        let coverURL = libraryService.coverURL(for: book.id)
        guard fileManager.fileExists(atPath: coverURL.path),
              let uiImage = UIImage(contentsOfFile: coverURL.path) else {
            return nil
        }

        return Image(uiImage: uiImage)
    }

    // MARK: - Error Handling

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}
