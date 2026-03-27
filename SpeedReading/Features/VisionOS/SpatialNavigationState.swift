import SwiftUI

@Observable
@MainActor
final class SpatialNavigationState {
    var selectedBookId: UUID?
    var isReaderOpen: Bool = false

    func selectBook(_ bookId: UUID) {
        selectedBookId = bookId
        isReaderOpen = true
    }

    func closeReader() {
        isReaderOpen = false
        selectedBookId = nil
    }
}
