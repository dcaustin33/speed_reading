import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var router: NavigationRouter

    @State private var viewModel = SettingsViewModel()

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    // Font Size Slider
                    VStack(spacing: 12) {
                        Text("Font Size")
                            .font(.headline)
                            .foregroundStyle(Theme.Colors.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack {
                            Text("24pt")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.secondaryText)

                            Slider(value: $viewModel.fontSize, in: 24...96, step: 1)
                                .tint(Theme.Colors.accent)
                                .accessibilityLabel("Font size")
                                .accessibilityValue(viewModel.fontSizeFormatted)

                            Text("96pt")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }

                        Text(viewModel.fontSizeFormatted)
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.primaryText)
                    }
                    .padding(.horizontal)

                    Divider()
                        .background(Theme.Colors.trackGray)
                        .padding(.horizontal)

                    // Word Skip Slider
                    VStack(spacing: 12) {
                        Text("Word Skip Amount")
                            .font(.headline)
                            .foregroundStyle(Theme.Colors.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack {
                            Text("1")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.secondaryText)

                            Slider(value: $viewModel.wordSkip, in: 1...20, step: 1)
                                .tint(Theme.Colors.accent)
                                .accessibilityLabel("Word skip amount")
                                .accessibilityValue(viewModel.wordSkipFormatted)

                            Text("20")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }

                        Text(viewModel.wordSkipFormatted)
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.primaryText)
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    router.pop()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(Theme.Colors.accent)
                }
                .accessibilityLabel("Back")
                .accessibilityHint("Return to menu")
            }
        }
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(NavigationRouter())
    }
}
