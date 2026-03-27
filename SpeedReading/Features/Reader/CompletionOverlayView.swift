import SwiftUI

/// Overlay displayed when the user finishes reading a book.
/// Per spec (Section 3.8):
/// - Shows book emoji icon
/// - "Finished!" title
/// - "You completed [Book Title]" message
/// - "Return to Library" button (only dismissal option)
/// - On dismiss: keep progress at 100%, navigate to Library
struct CompletionOverlayView: View {
    let bookTitle: String
    let isVisible: Bool
    let onDismiss: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        ZStack {
            #if !os(visionOS)
            // Full screen background
            Theme.Colors.background
                .ignoresSafeArea()
            #endif

            // Completion content centered
            VStack(spacing: 24) {
                // Book emoji icon
                Text("📖")
                    .font(.system(size: 64))

                // "Finished!" title
                Text("Finished!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.Colors.primaryText)

                // "You completed [Book Title]" message
                Text("You completed \"\(bookTitle)\"")
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
                    .frame(height: 16)

                // Return to Library button
                #if os(visionOS)
                Button("Return to Library") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Return to Library")
                .accessibilityHint("Tap to go back to your book library")
                #else
                Button {
                    onDismiss()
                } label: {
                    Text("Return to Library")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 16)
                        .background(Theme.Colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel("Return to Library")
                .accessibilityHint("Tap to go back to your book library")
                #endif
            }
            #if os(visionOS)
            .padding(40)
            .glassBackgroundEffect()
            #else
            .padding(.top, LayoutHelper.completionOverlayTopPadding(isCompactHeight: verticalSizeClass == .compact))
            #endif
        }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .accessibilityElement(children: .contain)
    }
}

#Preview("Completion Overlay - Visible") {
    CompletionOverlayView(
        bookTitle: "The Great Gatsby",
        isVisible: true,
        onDismiss: { print("Dismissed") }
    )
}

#Preview("Completion Overlay - Long Title") {
    CompletionOverlayView(
        bookTitle: "A Tale of Two Cities: The Revolutionary Story of Love and Sacrifice",
        isVisible: true,
        onDismiss: { print("Dismissed") }
    )
}

#Preview("Completion Overlay - Hidden") {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        Text("This text is visible when overlay is hidden")
            .foregroundStyle(Theme.Colors.primaryText)

        CompletionOverlayView(
            bookTitle: "Test Book",
            isVisible: false,
            onDismiss: {}
        )
    }
}
