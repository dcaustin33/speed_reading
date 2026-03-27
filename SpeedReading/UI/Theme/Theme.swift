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

        /// Slider/progress track color
        static let trackGray: Color = {
            #if os(visionOS)
            return Color.white.opacity(0.2)
            #else
            return Color(hex: 0x404040)
            #endif
        }()

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

        /// visionOS ornament width
        static let ornamentWidth: CGFloat = 360
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

#if os(visionOS)
/// A button that shows a floating tooltip label above on hover/gaze.
struct TooltipButton: View {
    let title: String
    let systemImage: String
    var iconFont: Font = .body
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(iconFont)
        }
        .buttonStyle(.borderless)
        .hoverEffect(.highlight)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .overlay(alignment: .top) {
            if isHovered {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: Capsule())
                    .offset(y: -32)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    .allowsHitTesting(false)
            }
        }
        .accessibilityLabel(title)
    }
}
#endif

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
