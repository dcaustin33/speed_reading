import SwiftUI

enum Theme {
    enum Colors {
        /// Main background color
        static let background: Color = {
            #if os(visionOS)
            return .clear
            #else
            return Color(hex: 0x1A1A1A)
            #endif
        }()

        /// Card/elevated surface background
        static let cardBackground: Color = {
            #if os(visionOS)
            return .clear
            #else
            return Color(hex: 0x2A2A2A)
            #endif
        }()

        /// Primary text color
        static let primaryText: Color = {
            #if os(visionOS)
            return .primary
            #else
            return Color(hex: 0xE0E0E0)
            #endif
        }()

        /// Secondary text color
        static let secondaryText: Color = {
            #if os(visionOS)
            return .secondary
            #else
            return Color(hex: 0x888888)
            #endif
        }()

        /// Accent color for interactive elements - Blue (#4A90D9)
        static let accent = Color(hex: 0x4A90D9)

        /// ORP highlight color - Red (#FF3333)
        static let orpHighlight = Color(hex: 0xFF3333)

        /// Slider/progress track color - Dark gray (#404040)
        static let trackGray = Color(hex: 0x404040)

        /// Bold/highlighted text in search results - White (#FFFFFF)
        static let highlightText = Color.white
    }

    enum Fonts {
        /// Monospace font for ORP display
        static func orpDisplay(size: CGFloat) -> Font {
            .system(size: size, design: .monospaced)
        }
    }

    enum Layout {
        /// Progress bar height
        static let progressBarHeight: CGFloat = 8

        /// Default font size for ORP display
        static let defaultFontSize: CGFloat = {
            #if os(visionOS)
            return 64
            #else
            return 48
            #endif
        }()

        /// Minimum font size for ORP display
        static let minFontSize: CGFloat = 24

        /// Maximum font size for ORP display
        static let maxFontSize: CGFloat = 96
    }

    enum Animation {
        /// Navigation overlay auto-hide duration
        static let navigationOverlayDuration: TimeInterval = 2.0

        /// Navigation overlay fade animation duration
        static let navigationOverlayFadeDuration: Double = 0.3

        /// visionOS ornament auto-hide delay (longer than iOS for spatial discovery)
        static let ornamentHideDelay: TimeInterval = 3.0
    }

    enum Navigation {
        /// Navigation button size
        static let buttonSize: CGFloat = 56

        /// Navigation button edge inset
        static let edgeInset: CGFloat = 20

        /// Minimum swipe distance to trigger sentence navigation
        static let minimumSwipeDistance: CGFloat = 50
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
