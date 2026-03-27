import SwiftUI
import CoreText

enum FontMetrics {
    /// Measures the width of a single character in the monospace system font.
    /// Uses CTFont on visionOS (where UIFont is unavailable) and UIFont on iOS.
    static func monospacedCharacterWidth(fontSize: CGFloat) -> CGFloat {
        #if os(visionOS)
        let font = CTFontCreateWithName("Menlo" as CFString, fontSize, nil)
        let characters: [UniChar] = [0x0057] // 'W'
        var glyphs: [CGGlyph] = [0]
        CTFontGetGlyphsForCharacters(font, characters, &glyphs, 1)
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .horizontal, &glyphs, &advance, 1)
        return advance.width
        #else
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        return ("W" as NSString).size(withAttributes: [.font: font]).width
        #endif
    }
}
