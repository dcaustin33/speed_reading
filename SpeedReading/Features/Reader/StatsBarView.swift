import SwiftUI

/// Displays reading statistics: WPM and time remaining.
/// Per spec (Section 4.2): "300 WPM • 12:34 remaining"
struct StatsBarView: View {
    /// Current words per minute setting
    let wpm: Int

    /// Formatted time remaining (M:SS or H:MM:SS)
    let timeRemaining: String

    /// Progress percentage (0-100)
    let progressPercentage: Int

    /// Formatted chapter time remaining, nil for non-EPUB books
    var chapterTimeRemaining: String? = nil

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                // WPM display
                Text("\(wpm) WPM")
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .accessibilityLabel("\(wpm) words per minute")

                // Separator
                Text("•")
                    .foregroundStyle(Theme.Colors.secondaryText)

                // Time remaining
                Text("\(timeRemaining) remaining")
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .accessibilityLabel("\(timeRemaining) remaining")

                Spacer()

                // Progress percentage
                Text("\(progressPercentage)%")
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .accessibilityLabel("\(progressPercentage) percent complete")
            }

            if let chapterTime = chapterTimeRemaining {
                HStack {
                    Text("Chapter: \(chapterTime) remaining")
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .accessibilityLabel("Chapter \(chapterTime) remaining")
                    Spacer()
                }
            }
        }
        .font(.caption)
    }
}

// MARK: - Preview

#Preview("Stats Bar - Middle") {
    VStack {
        Spacer()
        StatsBarView(
            wpm: 300,
            timeRemaining: "12:34",
            progressPercentage: 35
        )
        .padding()
        Spacer()
    }
    .background(Theme.Colors.background)
}

#Preview("Stats Bar - Start") {
    VStack {
        Spacer()
        StatsBarView(
            wpm: 250,
            timeRemaining: "45:00",
            progressPercentage: 0
        )
        .padding()
        Spacer()
    }
    .background(Theme.Colors.background)
}

#Preview("Stats Bar - Near End") {
    VStack {
        Spacer()
        StatsBarView(
            wpm: 400,
            timeRemaining: "1:23",
            progressPercentage: 95
        )
        .padding()
        Spacer()
    }
    .background(Theme.Colors.background)
}

#Preview("Stats Bar - Over 1 Hour") {
    VStack {
        Spacer()
        StatsBarView(
            wpm: 300,
            timeRemaining: "1:23:45",
            progressPercentage: 10
        )
        .padding()
        Spacer()
    }
    .background(Theme.Colors.background)
}
