import SwiftUI

/// A card component displaying a book in the library grid.
/// Shows cover/placeholder, title (max 2 lines), author (max 1 line), and progress bar.
struct BookCardView: View {
    let book: Book
    let isSelected: Bool
    let isEditing: Bool
    let coverImage: Image?

    init(book: Book, isSelected: Bool = false, isEditing: Bool = false, coverImage: Image? = nil) {
        self.book = book
        self.isSelected = isSelected
        self.isEditing = isEditing
        self.coverImage = coverImage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover or placeholder
            ZStack(alignment: .topLeading) {
                coverView
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .background(Theme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Selection indicator in edit mode
                if isEditing {
                    selectionIndicator
                        .padding(6)
                }
            }

            // Book info
            VStack(alignment: .leading, spacing: 4) {
                // Title - max 2 lines
                Text(book.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.Colors.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Author - max 1 line, only if present
                if let author = book.author, !author.isEmpty {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .lineLimit(1)
                }

                // Progress bar
                progressBar
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var coverView: some View {
        if let image = coverImage {
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            // Placeholder
            VStack {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var selectionIndicator: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Theme.Colors.accent : Theme.Colors.cardBackground.opacity(0.8))
                .frame(width: 24, height: 24)

            Circle()
                .stroke(isSelected ? Theme.Colors.accent : Theme.Colors.secondaryText, lineWidth: 2)
                .frame(width: 24, height: 24)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.Colors.trackGray)
                    .frame(height: 4)

                // Fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.Colors.accent)
                    .frame(width: geometry.size.width * book.progressPercentage, height: 4)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var label = book.title
        if let author = book.author, !author.isEmpty {
            label += " by \(author)"
        }
        return label
    }

    private var accessibilityValue: String {
        let progress = Int(book.progressPercentage * 100)
        return "\(progress)% complete"
    }
}

// MARK: - Preview

#Preview("Book with cover") {
    let book = Book(
        title: "The Great Gatsby",
        author: "F. Scott Fitzgerald",
        filename: "gatsby.epub",
        fileType: .epub,
        fileHash: "abc123",
        hasCover: true,
        totalWords: 47094,
        currentWordIndex: 15000,
        hasTOC: true
    )

    return ZStack {
        Theme.Colors.background.ignoresSafeArea()
        BookCardView(book: book)
            .frame(width: 110)
            .padding()
    }
}

#Preview("Book without cover") {
    let book = Book(
        title: "A Very Long Title That Should Be Truncated After Two Lines",
        author: nil,
        filename: "book.txt",
        fileType: .txt,
        fileHash: "abc123",
        hasCover: false,
        totalWords: 10000,
        currentWordIndex: 0,
        hasTOC: false
    )

    return ZStack {
        Theme.Colors.background.ignoresSafeArea()
        BookCardView(book: book)
            .frame(width: 110)
            .padding()
    }
}

#Preview("Book in edit mode - selected") {
    let book = Book(
        title: "Test Book",
        author: "Test Author",
        filename: "test.md",
        fileType: .md,
        fileHash: "abc123",
        hasCover: false,
        totalWords: 5000,
        currentWordIndex: 2500,
        hasTOC: false
    )

    return ZStack {
        Theme.Colors.background.ignoresSafeArea()
        BookCardView(book: book, isSelected: true, isEditing: true)
            .frame(width: 110)
            .padding()
    }
}
