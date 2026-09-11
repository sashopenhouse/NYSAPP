import SwiftUI

/// New York Sash brand palette — see docs/brand-guidelines.md.
/// Values are fixed brand colors, not semantic light/dark tokens: the guide
/// specifies exact hexes for both contexts (e.g. the logo inverts to solid
/// white on dark, but Brand/Action Red stay the same hex in both).
enum NYSColor {
    static let brandRed = Color(hex: 0xB20022)
    static let actionRed = Color(hex: 0xDC3545)
    static let black = Color(hex: 0x000000)
    static let white = Color(hex: 0xFFFFFF)
    static let slateGray = Color(hex: 0x64788C)
    static let lightGray = Color(hex: 0xF8F8F8)
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
