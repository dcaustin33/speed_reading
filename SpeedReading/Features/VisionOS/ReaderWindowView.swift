#if os(visionOS)
import SwiftUI

struct ReaderWindowView: View {
    let bookId: UUID
    @StateObject private var router = NavigationRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            ReaderView(bookId: bookId)
                .frame(width: 500, height: 125)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .settings:
                        SettingsView()
                            .frame(width: 500, height: 350)
                    case .search(let id):
                        SearchView(bookId: id)
                            .frame(width: 700, height: 500)
                    case .toc(let id, let wordIndex):
                        TOCView(bookId: id, currentWordIndex: wordIndex)
                            .frame(width: 700, height: 500)
                    case .reader(let id):
                        ReaderView(bookId: id)
                            .frame(width: 500, height: 125)
                    }
                }
        }
        .environmentObject(router)
    }
}
#endif
