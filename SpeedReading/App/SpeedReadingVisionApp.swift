#if os(visionOS)
import SwiftUI

@main
struct SpeedReadingVisionApp: App {
    @State private var navState = SpatialNavigationState()
    @StateObject private var router = NavigationRouter()

    var body: some Scene {
        WindowGroup(id: "library") {
            ContentView()
                .environmentObject(router)
                .environment(navState)
        }
        .defaultSize(width: 900, height: 600)

        WindowGroup(id: "reader") {
            Group {
                if let bookId = navState.selectedBookId {
                    ReaderView(bookId: bookId)
                        .environmentObject(NavigationRouter())
                } else {
                    ProgressView("Waiting for book selection...")
                }
            }
            .environment(navState)
        }
        .defaultSize(width: 600, height: 400)

        ImmersiveSpace(id: "immersiveReader") {
            Text("Immersive reader — coming in Phase 1B")
                .environment(navState)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
#endif
