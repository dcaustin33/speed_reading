import SwiftUI

enum LayoutHelper {
    private static let minimumColumnWidth: CGFloat = 100
    private static let columnSpacing: CGFloat = 16
    private static let horizontalPadding: CGFloat = 32 // 16 on each side

    static func libraryColumnCount(for availableWidth: CGFloat) -> Int {
        let usableWidth = availableWidth - horizontalPadding
        let count = Int((usableWidth + columnSpacing) / (minimumColumnWidth + columnSpacing))
        return min(max(count, 2), 6)
    }

    static func libraryGridColumns(for availableWidth: CGFloat) -> [GridItem] {
        let count = libraryColumnCount(for: availableWidth)
        return Array(repeating: GridItem(.flexible(), spacing: columnSpacing), count: count)
    }

    static func completionOverlayTopPadding(isCompactHeight: Bool) -> CGFloat {
        isCompactHeight ? 24 : 100
    }
}
