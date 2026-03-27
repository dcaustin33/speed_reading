import SwiftUI

@Observable
@MainActor
final class SpatialNavigationState {
    var selectedBookId: UUID?
    var isReaderOpen: Bool = false
    var isImmersiveSpaceOpen: Bool = false
    var immersiveSpaceError: String?

    func selectBook(_ bookId: UUID) {
        selectedBookId = bookId
        isReaderOpen = true
    }

    func closeReader() {
        isReaderOpen = false
        isImmersiveSpaceOpen = false
        selectedBookId = nil
    }

    func immersiveSpaceOpened() {
        isImmersiveSpaceOpen = true
        immersiveSpaceError = nil
    }

    func immersiveSpaceFailed(_ error: String) {
        immersiveSpaceError = error
        isImmersiveSpaceOpen = false
    }
}
