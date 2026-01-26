import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var router: NavigationRouter

    @State private var fontSize: Double = 48
    @State private var wordSkip: Double = 5

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

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

                        Slider(value: $fontSize, in: 24...96, step: 1)
                            .tint(Theme.Colors.accent)

                        Text("96pt")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }

                    Text("\(Int(fontSize))pt")
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

                        Slider(value: $wordSkip, in: 1...20, step: 1)
                            .tint(Theme.Colors.accent)

                        Text("20")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }

                    Text("\(Int(wordSkip)) words")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.primaryText)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 24)
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
