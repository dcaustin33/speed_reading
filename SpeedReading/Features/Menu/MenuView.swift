import SwiftUI

struct MenuView: View {
    @EnvironmentObject var router: NavigationRouter
    let bookId: UUID
    @Binding var showMenu: Bool

    @State private var wpm: Double = 300
    @State private var paragraphPause: Double = 1.0

    var body: some View {
        ZStack {
            Theme.Colors.background.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        showMenu = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(Theme.Colors.primaryText)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close menu")
                }
                .padding(.trailing)

                // Navigation controls
                HStack(spacing: 16) {
                    navigationButton(symbol: "backward.end.fill", label: "Previous paragraph")
                    navigationButton(symbol: "backward.fill", label: "Previous sentence")
                    navigationButton(symbol: "chevron.left", label: "Rewind")
                    navigationButton(symbol: "chevron.right", label: "Forward")
                    navigationButton(symbol: "forward.fill", label: "Next sentence")
                    navigationButton(symbol: "forward.end.fill", label: "Next paragraph")
                }
                .padding()
                .background(Theme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // WPM Slider
                sliderSection(
                    title: "WPM",
                    value: $wpm,
                    range: 100...800,
                    step: 25,
                    minLabel: "100",
                    maxLabel: "800",
                    valueLabel: "\(Int(wpm))"
                )

                // Paragraph Pause Slider
                sliderSection(
                    title: "Paragraph Pause",
                    value: $paragraphPause,
                    range: 0.25...3.0,
                    step: 0.25,
                    minLabel: "0.25s",
                    maxLabel: "3.0s",
                    valueLabel: String(format: "%.2fs", paragraphPause)
                )

                Divider()
                    .background(Theme.Colors.trackGray)
                    .padding(.horizontal)

                // Menu items
                VStack(spacing: 0) {
                    menuItem(icon: "magnifyingglass", title: "Search in Book") {
                        showMenu = false
                        router.navigateTo(.search(bookId: bookId))
                    }

                    // TOC - only shown for EPUB (placeholder logic)
                    menuItem(icon: "list.bullet", title: "Table of Contents") {
                        showMenu = false
                        router.navigateTo(.toc(bookId: bookId))
                    }

                    menuItem(icon: "gearshape", title: "Settings") {
                        showMenu = false
                        router.navigateTo(.settings)
                    }
                }

                Spacer()
            }
        }
        .presentationBackground(Theme.Colors.background.opacity(0.95))
    }

    private func navigationButton(symbol: String, label: String) -> some View {
        Button {
            // TODO: Implement navigation
        } label: {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.Colors.primaryText)
                .frame(width: 40, height: 40)
        }
        .accessibilityLabel(label)
    }

    private func sliderSection(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        minLabel: String,
        maxLabel: String,
        valueLabel: String
    ) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.Colors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text(minLabel)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)

                Slider(value: value, in: range, step: step)
                    .tint(Theme.Colors.accent)

                Text(maxLabel)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            Text(valueLabel)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.primaryText)
        }
        .padding(.horizontal)
    }

    private func menuItem(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(width: 24)

                Text(title)
                    .font(.body)
                    .foregroundStyle(Theme.Colors.primaryText)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
            .padding()
        }
    }
}

#Preview {
    MenuView(bookId: UUID(), showMenu: .constant(true))
        .environmentObject(NavigationRouter())
}
