import SwiftUI

/// Menu overlay with navigation controls, settings sliders, and menu items.
/// When provided with a ReaderViewModel, controls are connected to actual playback.
struct MenuView: View {
    @EnvironmentObject var router: NavigationRouter
    let bookId: UUID
    @Binding var showMenu: Bool

    /// Optional view model for connecting controls to playback
    var viewModel: ReaderViewModel?

    // Local state for when no viewModel is provided (preview mode)
    @State private var localWpm: Double = 300
    @State private var localParagraphPause: Double = 1.0

    // Computed bindings that use viewModel when available
    private var wpm: Binding<Double> {
        if let vm = viewModel {
            return Binding(
                get: { Double(vm.wpm) },
                set: { vm.wpm = Int($0) }
            )
        }
        return $localWpm
    }

    private var paragraphPause: Binding<Double> {
        if let vm = viewModel {
            return Binding(
                get: { vm.paragraphPause },
                set: { vm.paragraphPause = $0 }
            )
        }
        return $localParagraphPause
    }

    private var hasTOC: Bool {
        viewModel?.hasTOC ?? false
    }

    private var wordSkip: Int {
        viewModel?.wordSkip ?? 5
    }

    private var currentWordIndex: Int {
        viewModel?.currentWordIndex ?? 0
    }

    var body: some View {
        #if os(visionOS)
        visionOSMenuBody
        #else
        iOSMenuBody
        #endif
    }

    // MARK: - visionOS Menu

    #if os(visionOS)
    private var visionOSMenuBody: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Done button
                HStack {
                    Spacer()
                    Button("Done") {
                        showMenu = false
                    }
                    .font(.body.weight(.medium))
                    .buttonStyle(.plain)
                }

                // Playback section
                VStack(alignment: .leading, spacing: 20) {
                    Text("Playback")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    visionOSSlider(
                        title: "WPM",
                        value: wpm,
                        range: 100...800,
                        step: 25,
                        valueLabel: "\(Int(wpm.wrappedValue))"
                    )

                    visionOSSlider(
                        title: "Paragraph Pause",
                        value: paragraphPause,
                        range: 0.25...3.0,
                        step: 0.25,
                        valueLabel: formatPause(paragraphPause.wrappedValue)
                    )
                }
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                // Navigation section
                VStack(alignment: .leading, spacing: 0) {
                    Text("Navigation")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 12)

                    visionOSMenuItem(icon: "magnifyingglass", title: "Search in Book") {
                        showMenu = false
                        router.navigateTo(.search(bookId: bookId))
                    }

                    if hasTOC {
                        Divider().padding(.leading, 60)
                        visionOSMenuItem(icon: "list.bullet", title: "Table of Contents") {
                            showMenu = false
                            router.navigateTo(.toc(bookId: bookId, currentWordIndex: currentWordIndex))
                        }
                    }

                    Divider().padding(.leading, 60)
                    visionOSMenuItem(icon: "text.justify.left", title: "Show Paragraph") {
                        showMenu = false
                        viewModel?.showParagraphPreview()
                    }

                    Divider().padding(.leading, 60)
                    visionOSMenuItem(
                        icon: "arrow.left.arrow.right",
                        title: viewModel?.isNavigationOverlayVisible == true
                            ? "Hide Navigation Overlay"
                            : "Show Navigation Overlay"
                    ) {
                        viewModel?.toggleNavigationOverlay()
                        showMenu = false
                    }

                    Divider().padding(.leading, 60)
                    visionOSMenuItem(icon: "gearshape", title: "Settings") {
                        showMenu = false
                        router.navigateTo(.settings)
                    }
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(24)
        }
        .presentationSizing(.fitted)
        .presentationBackground(.regularMaterial)
    }

    private func visionOSSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        valueLabel: String
    ) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text(valueLabel)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: range, step: step)
                .tint(Theme.Colors.accent)
                .accessibilityLabel(title)
                .accessibilityValue(valueLabel)
        }
    }

    private func visionOSMenuItem(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(width: 24)

                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    #endif

    // MARK: - iOS Menu

    #if !os(visionOS)
    private var iOSMenuBody: some View {
        ZStack {
            Theme.Colors.background.opacity(0.95)
                .ignoresSafeArea()

            ScrollView {
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
                        navigationButton(symbol: "backward.end.fill", label: "Previous paragraph") {
                            viewModel?.previousParagraph()
                        }
                        navigationButton(symbol: "backward.fill", label: "Previous sentence") {
                            viewModel?.previousSentence()
                        }
                        navigationButton(symbol: "chevron.left", label: "Rewind \(wordSkip) words") {
                            viewModel?.skipBackward()
                        }
                        navigationButton(symbol: "chevron.right", label: "Forward \(wordSkip) words") {
                            viewModel?.skipForward()
                        }
                        navigationButton(symbol: "forward.fill", label: "Next sentence") {
                            viewModel?.nextSentence()
                        }
                        navigationButton(symbol: "forward.end.fill", label: "Next paragraph") {
                            viewModel?.nextParagraph()
                        }
                    }
                    .padding()
                    .background(Theme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // WPM Slider
                    sliderSection(
                        title: "WPM",
                        value: wpm,
                        range: 100...800,
                        step: 25,
                        minLabel: "100",
                        maxLabel: "800",
                        valueLabel: "\(Int(wpm.wrappedValue))"
                    )

                    // Paragraph Pause Slider
                    sliderSection(
                        title: "Paragraph Pause",
                        value: paragraphPause,
                        range: 0.25...3.0,
                        step: 0.25,
                        minLabel: "0.25s",
                        maxLabel: "3.0s",
                        valueLabel: formatPause(paragraphPause.wrappedValue)
                    )

                    Divider()
                        .background(Theme.Colors.trackGray)
                        .padding(.horizontal)

                    // Menu items
                    VStack(spacing: 0) {
                        menuItem(icon: "magnifyingglass", title: "Search in Book", hint: "Find text within this book") {
                            showMenu = false
                            router.navigateTo(.search(bookId: bookId))
                        }

                        if hasTOC {
                            menuItem(icon: "list.bullet", title: "Table of Contents", hint: "Navigate to chapters") {
                                showMenu = false
                                router.navigateTo(.toc(bookId: bookId, currentWordIndex: currentWordIndex))
                            }
                        }

                        menuItem(icon: "gearshape", title: "Settings", hint: "Adjust font size and word skip") {
                            showMenu = false
                            router.navigateTo(.settings)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .presentationBackground(Theme.Colors.background.opacity(0.95))
    }
    #endif

    private func navigationButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.Colors.primaryText)
                .frame(width: 40, height: 40)
        }
        .accessibilityLabel(label)
    }

    /// Formats pause value with consistent decimal places (1.0s, 1.25s, etc.)
    private func formatPause(_ value: Double) -> String {
        if value == Double(Int(value)) {
            return String(format: "%.1fs", value)
        } else if value * 4 == Double(Int(value * 4)) {
            // Value is a multiple of 0.25
            if value * 10 == Double(Int(value * 10)) {
                return String(format: "%.1fs", value)
            }
            return String(format: "%.2fs", value)
        }
        return String(format: "%.2fs", value)
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
                    .accessibilityLabel(title)
                    .accessibilityValue(valueLabel)

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

    private func menuItem(icon: String, title: String, hint: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.body)
                    .foregroundStyle(Theme.Colors.primaryText)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding()
        }
        .accessibilityLabel(title)
        .accessibilityHint(hint ?? "")
    }
}

#Preview {
    MenuView(bookId: UUID(), showMenu: .constant(true))
        .environmentObject(NavigationRouter())
}
