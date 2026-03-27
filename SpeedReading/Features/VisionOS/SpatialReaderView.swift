#if os(visionOS)
import SwiftUI
import RealityKit

/// Placeholder immersive space view — full implementation in Task 7.
struct SpatialReaderView: View {
    @Environment(SpatialNavigationState.self) private var navState
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        RealityView { content in
            // Head-anchored container — full entity setup in Task 7
            let headAnchor = Entity()
            headAnchor.components.set(
                AnchoringComponent(.head, trackingMode: .continuous)
            )
            content.add(headAnchor)
        }
        .overlay {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text("Preparing immersive reader…")
                    .font(.title3)
            }
            .padding(32)
            .glassBackgroundEffect()
        }
        .onDisappear {
            // System-initiated dismissals (Digital Crown, safety boundary, other app)
            navState.isImmersiveSpaceOpen = false
        }
    }
}
#endif
