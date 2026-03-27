#if os(visionOS)
import SwiftUI

@main
struct SpeedReadingVisionApp: App {
    @State private var navState = SpatialNavigationState()

    var body: some Scene {
        WindowGroup {
            Group {
                if navState.isReaderOpen, let bookId = navState.selectedBookId {
                    ReaderWindowView(bookId: bookId)
                        .frame(width: 500, height: 125)
                        .glassBackgroundEffect()
                } else {
                    ContentView()
                        .environmentObject(NavigationRouter())
                        .frame(width: 900, height: 600)
                        .glassBackgroundEffect()
                }
            }
            .environment(navState)
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 600)

        ImmersiveSpace(id: "immersiveReader") {
            Text("Immersive reader — coming in Phase 1B")
                .environment(navState)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
#endif
