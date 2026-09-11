import SwiftUI

/// Inter is the brand's specified fallback for anything outside the main
/// website — Aptos itself isn't freely licensable for embedding. Headlines
/// use weight 900 (Black) in sentence case; body copy uses weight 300 (Light).
/// See docs/brand-guidelines.md.
///
/// Bundled as Resources/Fonts/Inter-Variable.ttf (SIL Open Font License,
/// license text alongside it as Inter-OFL.txt), registered in Info.plist's
/// UIAppFonts. It's a *variable* font — its internal PostScript name is
/// "Inter-Regular" regardless of weight, so weight comes from `.weight()`
/// on top of `.custom(name:)`, not from separate per-weight font names.
enum NYSFont {
    private static let postScriptName = "Inter-Regular"

    static func headline(_ size: CGFloat = 28) -> Font {
        .custom(postScriptName, size: size, relativeTo: .title)
            .weight(.black)
    }

    static func subheadline(_ size: CGFloat = 20) -> Font {
        .custom(postScriptName, size: size, relativeTo: .title3)
            .weight(.black)
    }

    static func body(_ size: CGFloat = 17) -> Font {
        .custom(postScriptName, size: size, relativeTo: .body)
            .weight(.light)
    }
}
