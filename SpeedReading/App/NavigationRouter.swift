import SwiftUI

enum Route: Hashable {
    case reader(bookId: UUID)
    case settings
    case search(bookId: UUID)
    case toc(bookId: UUID)
}

@MainActor
final class NavigationRouter: ObservableObject {
    @Published var path = NavigationPath()

    func navigateTo(_ route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
