import SwiftUI

@main
struct SpeedReadingApp: App {
    @StateObject private var router = NavigationRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(router)
                .preferredColorScheme(.dark)
        }
    }
}
