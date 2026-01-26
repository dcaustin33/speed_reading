import SwiftUI

/// Overlay displayed during chapter transitions.
/// Per spec (Section 3.7):
/// - Fades in when crossing chapter boundary
/// - Displays chapter title for 2 seconds
/// - Fades out automatically
/// - Playback continues behind overlay (no pause)
/// - Cannot be dismissed early
struct ChapterOverlayView: View {
    let chapterTitle: String
    let isVisible: Bool

    var body: some View {
        ZStack {
            // Semi-transparent background
            Theme.Colors.background
                .opacity(0.85)

            // Chapter title centered
            VStack(spacing: 8) {
                Text(chapterTitle)
                    .font(.title)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.Colors.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .allowsHitTesting(false) // Overlay cannot be interacted with
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chapter: \(chapterTitle)")
        .accessibilityAddTraits(.isStaticText)
    }
}

#Preview("Chapter Overlay - Visible") {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        Text("Reading content behind overlay")
            .foregroundStyle(Theme.Colors.primaryText)

        ChapterOverlayView(
            chapterTitle: "Chapter 3: The Journey",
            isVisible: true
        )
    }
}

#Preview("Chapter Overlay - Long Title") {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        ChapterOverlayView(
            chapterTitle: "Chapter 15: The Incredibly Long Chapter Title That Spans Multiple Lines",
            isVisible: true
        )
    }
}

#Preview("Chapter Overlay - Hidden") {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        Text("This text is visible when overlay is hidden")
            .foregroundStyle(Theme.Colors.primaryText)

        ChapterOverlayView(
            chapterTitle: "Chapter 1",
            isVisible: false
        )
    }
}
