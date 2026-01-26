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
                    case .toc(let bookId):
                        TOCView(bookId: bookId)
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
