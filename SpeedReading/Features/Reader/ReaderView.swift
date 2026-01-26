import SwiftUI

struct ReaderView: View {
    @EnvironmentObject var router: NavigationRouter
    let bookId: UUID

    @State private var isPlaying = false
    @State private var showMenu = false
    @State private var progress: Double = 0.35

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Main content area - tap to toggle play/pause
                Button {
                    isPlaying.toggle()
                } label: {
                    VStack {
                        Spacer()

                        // ORP Display placeholder
                        HStack(spacing: 0) {
                            Text("extra")
                                .foregroundStyle(Theme.Colors.primaryText)
                            Text("o")
                                .foregroundStyle(Theme.Colors.orpHighlight)
                            Text("rdinary")
                                .foregroundStyle(Theme.Colors.primaryText)
                        }
                        .font(Theme.Fonts.orpDisplay(size: Theme.Layout.defaultFontSize))

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Bottom controls area
                VStack(spacing: 8) {
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Track
                            Rectangle()
                                .fill(Theme.Colors.trackGray)
                                .frame(height: Theme.Layout.progressBarHeight)

                            // Fill
                            Rectangle()
                                .fill(Theme.Colors.accent)
                                .frame(width: geometry.size.width * progress, height: Theme.Layout.progressBarHeight)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .frame(height: Theme.Layout.progressBarHeight)
                    .accessibilityValue("\(Int(progress * 100)) percent complete")

                    // Stats bar
                    HStack {
                        Text("300 WPM")
                            .foregroundStyle(Theme.Colors.secondaryText)

                        Text("•")
                            .foregroundStyle(Theme.Colors.secondaryText)

                        Text("12:34 remaining")
                            .foregroundStyle(Theme.Colors.secondaryText)

                        Spacer()

                        Text("\(Int(progress * 100))%")
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                    .font(.caption)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            // Menu button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showMenu = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title2)
                            .foregroundStyle(Theme.Colors.primaryText)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Menu")
                    .padding(.trailing, 8)
                    .padding(.bottom, 80)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    router.pop()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Theme.Colors.primaryText)
                }
                .accessibilityLabel("Back to library")
            }
        }
        .sheet(isPresented: $showMenu) {
            MenuView(bookId: bookId, showMenu: $showMenu)
        }
    }
}

#Preview {
    NavigationStack {
        ReaderView(bookId: UUID())
            .environmentObject(NavigationRouter())
    }
}
