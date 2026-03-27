#if os(visionOS)
import SwiftUI
import RealityKit

/// Immersive space reader that assembles the ORP word and control bar
/// as RealityView attachments positioned in 3D space in front of the user.
struct SpatialReaderView: View {
    @Environment(SpatialNavigationState.self) private var navState
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel: ReaderViewModel?
    @State private var showMenu = false

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading {
                    loadingOverlay
                } else if let error = viewModel.errorMessage {
                    errorOverlay(message: error)
                } else {
                    readerContent(viewModel: viewModel)
                }
            } else {
                loadingOverlay
            }
        }
        .task {
            guard let bookId = navState.selectedBookId else { return }
            let vm = ReaderViewModel(bookId: bookId)
            viewModel = vm
            vm.loadBook()
        }
        .onChange(of: showMenu) { _, isShowing in
            if !isShowing {
                viewModel?.reloadSettings()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                viewModel?.pause()
                viewModel?.onDisappear()
            }
        }
        .onDisappear {
            viewModel?.onDisappear()
            navState.isImmersiveSpaceOpen = false
        }
    }

    // MARK: - Reader Content

    @ViewBuilder
    private func readerContent(viewModel: ReaderViewModel) -> some View {
        RealityView { content, attachments in
            let headAnchor = Entity()
            headAnchor.components.set(
                AnchoringComponent(.head, trackingMode: .continuous)
            )

            if let orpView = attachments.entity(for: "orpDisplay") {
                orpView.position = [0, 0, -2.0]
                orpView.components.set(BillboardComponent())
                headAnchor.addChild(orpView)
            }

            if let controls = attachments.entity(for: "controlBar") {
                controls.position = [0, -0.3, -2.0]
                controls.components.set(BillboardComponent())
                headAnchor.addChild(controls)
            }

            content.add(headAnchor)
        } attachments: {
            Attachment(id: "orpDisplay") {
                SpatialORPView(viewModel: viewModel)
            }

            Attachment(id: "controlBar") {
                SpatialControlBar(viewModel: viewModel, onMenuTapped: {
                    viewModel.pause()
                    openWindow(id: "reader")
                })
            }
        }
        .overlay {
            if viewModel.isCompleted {
                CompletionOverlayView(
                    bookTitle: viewModel.bookTitle,
                    isVisible: viewModel.isCompleted,
                    onDismiss: {
                        viewModel.dismissCompletion()
                        viewModel.onDisappear()
                        navState.closeReader()
                    }
                )
            }
        }
    }

    // MARK: - Loading

    private var loadingOverlay: some View {
        RealityView { content in
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
                Text("Preparing immersive reader\u{2026}")
                    .font(.title3)
            }
            .padding(32)
            .glassBackgroundEffect()
        }
    }

    // MARK: - Error

    private func errorOverlay(message: String) -> some View {
        RealityView { content in
            let headAnchor = Entity()
            headAnchor.components.set(
                AnchoringComponent(.head, trackingMode: .continuous)
            )
            content.add(headAnchor)
        }
        .overlay {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)

                Text(message)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Return to Library") {
                    viewModel?.onDisappear()
                    navState.closeReader()
                }
                .buttonStyle(.bordered)
                .hoverEffect(.highlight)
            }
            .padding(32)
            .glassBackgroundEffect()
        }
    }
}
#endif
