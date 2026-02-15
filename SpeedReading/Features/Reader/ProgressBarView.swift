import SwiftUI

/// A draggable progress bar for the reading screen.
/// Supports scrubbing with live preview and pauses playback on drag.
struct ProgressBarView: View {
    /// Current progress (0.0 - 1.0)
    let progress: Double

    /// Whether the user is currently scrubbing
    let isScrubbing: Bool

    /// Called when user starts dragging
    var onScrubStart: () -> Void = {}

    /// Called during drag with new position (0.0 - 1.0)
    var onScrubChange: (Double) -> Void = { _ in }

    /// Called when user releases the progress bar
    var onScrubEnd: () -> Void = {}

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track (background)
                Rectangle()
                    .fill(Theme.Colors.trackGray)
                    .frame(height: Theme.Layout.progressBarHeight)

                // Fill (progress)
                Rectangle()
                    .fill(Theme.Colors.accent)
                    .frame(
                        width: geometry.size.width * CGFloat(progress),
                        height: Theme.Layout.progressBarHeight
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.progressBarHeight / 2))
            .contentShape(Rectangle())  // Make entire area tappable
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onScrubStart()
                        }

                        let position = value.location.x / geometry.size.width
                        onScrubChange(position)
                    }
                    .onEnded { _ in
                        isDragging = false
                        onScrubEnd()
                    }
            )
        }
        .frame(height: Theme.Layout.progressBarHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reading progress")
        .accessibilityValue("\(Int(progress * 100)) percent complete")
        .accessibilityAdjustableAction { direction in
            onScrubStart()
            switch direction {
            case .increment:
                onScrubChange(min(1, progress + 0.05))
            case .decrement:
                onScrubChange(max(0, progress - 0.05))
            @unknown default:
                break
            }
            onScrubEnd()
        }
    }
}

// MARK: - Preview

#Preview("Progress Bar - 35%") {
    VStack {
        Spacer()
        ProgressBarView(
            progress: 0.35,
            isScrubbing: false
        )
        .padding()
        Spacer()
    }
    .background(Theme.Colors.background)
}

#Preview("Progress Bar - 0%") {
    VStack {
        Spacer()
        ProgressBarView(
            progress: 0,
            isScrubbing: false
        )
        .padding()
        Spacer()
    }
    .background(Theme.Colors.background)
}

#Preview("Progress Bar - 100%") {
    VStack {
        Spacer()
        ProgressBarView(
            progress: 1.0,
            isScrubbing: false
        )
        .padding()
        Spacer()
    }
    .background(Theme.Colors.background)
}

#Preview("Progress Bar - Interactive") {
    struct InteractivePreview: View {
        @State private var progress: Double = 0.5
        @State private var isScrubbing = false

        var body: some View {
            VStack(spacing: 20) {
                Spacer()

                Text("Progress: \(Int(progress * 100))%")
                    .foregroundStyle(Theme.Colors.primaryText)

                ProgressBarView(
                    progress: progress,
                    isScrubbing: isScrubbing,
                    onScrubStart: {
                        isScrubbing = true
                    },
                    onScrubChange: { newProgress in
                        progress = max(0, min(1, newProgress))
                    },
                    onScrubEnd: {
                        isScrubbing = false
                    }
                )
                .padding(.horizontal)

                Text(isScrubbing ? "Scrubbing..." : "Drag to scrub")
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .font(.caption)

                Spacer()
            }
            .background(Theme.Colors.background)
        }
    }
    return InteractivePreview()
}
