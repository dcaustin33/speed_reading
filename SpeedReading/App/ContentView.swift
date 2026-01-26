import SwiftUI

struct ContentView: View {
    @EnvironmentObject var router: NavigationRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            LibraryView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .reader(let bookId):
                        ReaderView(bookId: bookId)
                    case .settings:
                        SettingsView()
                    case .search(let bookId):
                        SearchView(bookId: bookId)
                    case .toc(let bookId, let currentWordIndex):
                        TOCView(bookId: bookId, currentWordIndex: currentWordIndex)
                    }
                }
        }
        .tint(Theme.Colors.accent)
    }
}

#Preview {
    ContentView()
        .environmentObject(NavigationRouter())
}
