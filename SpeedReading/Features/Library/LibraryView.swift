import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var router: NavigationRouter
    @State private var isEditing = false

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            VStack {
                Spacer()

                // Empty state placeholder
                VStack(spacing: 16) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Theme.Colors.secondaryText)

                    Text("Your library is empty")
                        .font(.title2)
                        .foregroundStyle(Theme.Colors.primaryText)

                    Text("Tap the + button to import books from Files")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()

            // Floating action button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        // TODO: Open file picker
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Theme.Colors.accent)
                            .clipShape(Circle())
                            .shadow(radius: 4, y: 2)
                    }
                    .accessibilityLabel("Import book")
                    .padding(.trailing, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Speed Reading")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                }
                .foregroundStyle(Theme.Colors.accent)
            }
        }
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        LibraryView()
            .environmentObject(NavigationRouter())
    }
}
