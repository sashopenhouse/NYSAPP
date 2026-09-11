import SwiftUI

/// Square corners throughout, per the brand guide — .roundedBorder isn't on-brand.
struct NYSTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(NYSFont.body(17))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .overlay(Rectangle().stroke(NYSColor.slateGray.opacity(0.4), lineWidth: 1))
    }
}

extension TextFieldStyle where Self == NYSTextFieldStyle {
    static var nys: NYSTextFieldStyle { NYSTextFieldStyle() }
}
