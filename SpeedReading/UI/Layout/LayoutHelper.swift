import SwiftUI

enum LayoutHelper {
    private static let minimumColumnWidth: CGFloat = {
        #if os(visionOS)
        return 160
        #else
        return 100
        #endif
    }()
    private static let columnSpacing: CGFloat = {
        #if os(visionOS)
        return 24
        #else
        return 16
        #endif
    }()
    private static let horizontalPadding: CGFloat = {
        #if os(visionOS)
        return 64 // 32 on each side
        #else
        return 32 // 16 on each side
        #endif
    }()

    static func libraryColumnCount(for availableWidth: CGFloat) -> Int {
        let usableWidth = availableWidth - horizontalPadding
        let count = Int((usableWidth + columnSpacing) / (minimumColumnWidth + columnSpacing))
        #if os(visionOS)
        return min(max(count, 2), 4)
        #else
        return min(max(count, 2), 6)
        #endif
    }

    static func libraryGridColumns(for availableWidth: CGFloat) -> [GridItem] {
        let count = libraryColumnCount(for: availableWidth)
        return Array(repeating: GridItem(.flexible(), spacing: columnSpacing), count: count)
    }

    static func completionOverlayTopPadding(isCompactHeight: Bool) -> CGFloat {
        isCompactHeight ? 24 : 100
    }
}
