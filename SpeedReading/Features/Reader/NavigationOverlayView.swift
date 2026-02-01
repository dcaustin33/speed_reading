import SwiftUI

/// Overlay with navigation buttons for sentence and paragraph navigation.
/// Displays previous/next buttons in the bottom corners that auto-fade.
struct NavigationOverlayView: View {
    let isVisible: Bool
    let onPreviousSentence: () -> Void
    let onNextSentence: () -> Void
    let onPreviousParagraph: () -> Void
    let onNextParagraph: () -> Void

    var body: some View {
        ZStack {
            // Left corner buttons - bottom left
            VStack {
                Spacer()
                HStack {
                    VStack(spacing: 8) {
                        navigationButton(
                            icon: "chevron.backward.2.circle.fill",
                            accessibilityLabel: "Previous paragraph",
                            accessibilityHint: "Go back one paragraph",
                            action: onPreviousParagraph
                        )
                        navigationButton(
                            icon: "chevron.backward.circle.fill",
                            accessibilityLabel: "Previous sentence",
                            accessibilityHint: "Go back one sentence",
                            action: onPreviousSentence
                        )
                    }
                    Spacer()
                }
            }
            .padding(.leading, Theme.Navigation.edgeInset)
            .padding(.bottom, Theme.Navigation.edgeInset)

            // Right corner buttons - bottom right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        navigationButton(
                            icon: "chevron.forward.2.circle.fill",
                            accessibilityLabel: "Next paragraph",
                            accessibilityHint: "Skip to next paragraph",
                            action: onNextParagraph
                        )
                        navigationButton(
                            icon: "chevron.forward.circle.fill",
                            accessibilityLabel: "Next sentence",
                            accessibilityHint: "Skip to next sentence",
                            action: onNextSentence
                        )
                    }
                }
            }
            .padding(.trailing, Theme.Navigation.edgeInset)
            .padding(.bottom, Theme.Navigation.edgeInset)
        }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: Theme.Animation.navigationOverlayFadeDuration), value: isVisible)
        .allowsHitTesting(isVisible)
    }

    private func navigationButton(
        icon: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: Theme.Navigation.buttonSize * 0.7))
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: Theme.Navigation.buttonSize, height: Theme.Navigation.buttonSize)
                .background(
                    Circle()
                        .fill(Theme.Colors.cardBackground.opacity(0.9))
                )
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
}

#Preview("Visible") {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        NavigationOverlayView(
            isVisible: true,
            onPreviousSentence: { print("Previous sentence") },
            onNextSentence: { print("Next sentence") },
            onPreviousParagraph: { print("Previous paragraph") },
            onNextParagraph: { print("Next paragraph") }
        )
    }
}

#Preview("Hidden") {
    ZStack {
        Theme.Colors.background
            .ignoresSafeArea()

        NavigationOverlayView(
            isVisible: false,
            onPreviousSentence: { print("Previous sentence") },
            onNextSentence: { print("Next sentence") },
            onPreviousParagraph: { print("Previous paragraph") },
            onNextParagraph: { print("Next paragraph") }
        )
    }
}
