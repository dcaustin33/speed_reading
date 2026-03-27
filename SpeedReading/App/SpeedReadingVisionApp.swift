#if os(visionOS)
import SwiftUI

@main
struct SpeedReadingVisionApp: App {
    @State private var navState = SpatialNavigationState()
    @State private var immersionStyle: ImmersionStyle = .mixed

    var body: some Scene {
        WindowGroup {
            LibraryCoordinatorView()
                .environment(navState)
                .frame(width: 900, height: 600)
                .glassBackgroundEffect()
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 600)

        WindowGroup(id: "reader") {
            Group {
                if let bookId = navState.selectedBookId {
                    ReaderWindowView(bookId: bookId)
                        .frame(width: 500, height: 125)
                        .glassBackgroundEffect()
                } else {
                    Text("No book selected")
                        .padding()
                        .glassBackgroundEffect()
                }
            }
            .environment(navState)
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .defaultSize(width: 500, height: 125)

        ImmersiveSpace(id: "immersiveReader") {
            SpatialReaderView()
                .environment(navState)
        }
        .immersionStyle(selection: $immersionStyle, in: .mixed)
    }
}

/// Wraps the library content and coordinates immersive space open/dismiss
/// based on SpatialNavigationState changes.
struct LibraryCoordinatorView: View {
    @Environment(SpatialNavigationState.self) private var navState
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        SpatialLibraryView()
            .onChange(of: navState.isReaderOpen) { _, isOpen in
                if isOpen {
                    guard !navState.isImmersiveSpaceOpen else { return }
                    Task {
                        let result = await openImmersiveSpace(id: "immersiveReader")
                        switch result {
                        case .opened:
                            navState.immersiveSpaceOpened()
                        case .userCancelled:
                            navState.closeReader()
                        case .error:
                            navState.immersiveSpaceFailed("Failed to open immersive space")
                            openWindow(id: "reader")
                        @unknown default:
                            break
                        }
                    }
                } else {
                    dismissWindow(id: "reader")
                    Task {
                        await dismissImmersiveSpace()
                    }
                }
            }
    }
}
#endif
