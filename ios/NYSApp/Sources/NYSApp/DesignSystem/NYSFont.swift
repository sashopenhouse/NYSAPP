import SwiftUI

/// Inter is the brand's specified fallback for anything outside the main
/// website — Aptos itself isn't freely licensable for embedding. Headlines
/// use weight 900 (Black) in sentence case; body copy uses weight 300 (Light).
/// See docs/brand-guidelines.md.
///
/// TODO: bundle the actual Inter font files. Google Fonts ships Inter under
/// the SIL Open Font License (https://fonts.google.com/specimen/Inter) —
/// download Inter-Black.ttf / Inter-Light.ttf (etc.), add them under
/// Resources/Fonts/, and register each filename in Info.plist's
/// UIAppFonts array. `.custom(name:)` with a name SwiftUI can't resolve
/// falls back to the system font silently (no crash), which is why the
/// app still renders correctly today — it's just not actually on-brand
/// until the font files are added.
enum NYSFont {
    static func headline(_ size: CGFloat = 28) -> Font {
        .custom("Inter-Black", size: size, relativeTo: .title)
    }

    static func subheadline(_ size: CGFloat = 20) -> Font {
        .custom("Inter-Black", size: size, relativeTo: .title3)
    }

    static func body(_ size: CGFloat = 17) -> Font {
        .custom("Inter-Light", size: size, relativeTo: .body)
    }
}
