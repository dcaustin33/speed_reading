import SwiftUI

/// Overlay that displays the full paragraph text in traditional reading format.
/// The current word is highlighted so the reader knows where they are.
struct ParagraphOverlayView: View {
    let paragraphText: String
    let highlightWordIndex: Int
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Dimmed background - tap to dismiss
            #if os(visionOS)
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }
            #else
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }
            #endif

            VStack(spacing: 0) {
                // Dismiss button row
                HStack {
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                    #if os(visionOS)
                    .hoverEffect(.highlight)
                    #endif
                    .accessibilityLabel("Close paragraph preview")
                }
                .padding(.bottom, 12)

                // Scrollable paragraph text
                ScrollView(.vertical, showsIndicators: true) {
                    highlightedText
                        .padding(.horizontal, 4)
                        .padding(.bottom, 16)
                }
            }
            .padding(20)
            #if os(visionOS)
            .glassBackgroundEffect()
            #else
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.Colors.cardBackground)
            )
            #endif
            .padding(.horizontal, 24)
            .padding(.top, 60)
            .padding(.bottom, 40)
        }
        .transition(.opacity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Paragraph preview")
    }

    private var highlightedText: some View {
        let words = paragraphText.split(separator: " ", omittingEmptySubsequences: true).map(String.init)

        return words.indices.reduce(Text("")) { result, i in
            let separator = i == 0 ? Text("") : Text(" ")
            if i == highlightWordIndex {
                return result + separator + Text(words[i])
                    .foregroundColor(Theme.Colors.orpHighlight)
                    .fontWeight(.bold)
            } else {
                return result + separator + Text(words[i])
                    .foregroundColor(Theme.Colors.primaryText)
            }
        }
        .font(.system(size: 18, design: .serif))
        .lineSpacing(8)
    }
}

#Preview("Paragraph Preview") {
    ZStack {
        Theme.Colors.background.ignoresSafeArea()

        ParagraphOverlayView(
            paragraphText: "It was the best of times, it was the worst of times, it was the age of wisdom, it was the age of foolishness, it was the epoch of belief, it was the epoch of incredulity.",
            highlightWordIndex: 8,
            onDismiss: {}
        )
    }
}
