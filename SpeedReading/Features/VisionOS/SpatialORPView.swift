#if os(visionOS)
import SwiftUI

/// Floating ORP word display for the immersive space.
/// Designed to be used as a RealityView Attachment.
struct SpatialORPView: View {
    @State var viewModel: ReaderViewModel

    var body: some View {
        let parts = ORPDisplayLogic.splitWord(
            viewModel.currentWord,
            orpIndex: viewModel.currentOrpIndex
        )

        HStack(spacing: 0) {
            Text(parts.before)
                .foregroundStyle(.white)

            Text(parts.orp)
                .foregroundStyle(Theme.Colors.orpHighlight)

            Text(parts.after)
                .foregroundStyle(.white)
        }
        .font(.system(size: Theme.Spatial.fontSize, weight: .medium, design: .monospaced))
        .padding(.horizontal, 40)
        .padding(.vertical, 24)
        .glassBackgroundEffect()
        .animation(.easeInOut(duration: 0.05), value: viewModel.currentWord)
        .id(viewModel.currentWordIndex)
        .onTapGesture {
            viewModel.toggle()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(viewModel.currentWord)
        .accessibilityAddTraits(viewModel.isPlaying ? .updatesFrequently : [])
        .accessibilityHint(viewModel.isPlaying ? "Tap to pause" : "Tap to play")
    }
}
#endif
