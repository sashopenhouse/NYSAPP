import SwiftUI

/// Brand guide, twice: "Square corners throughout — no rounded buttons."
/// Use this instead of .buttonStyle(.borderedProminent) etc., which round.
struct NYSPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NYSFont.body(17))
            .foregroundStyle(NYSColor.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(NYSColor.actionRed)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct NYSSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NYSFont.body(17))
            .foregroundStyle(NYSColor.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .overlay(Rectangle().stroke(NYSColor.black, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == NYSPrimaryButtonStyle {
    static var nysPrimary: NYSPrimaryButtonStyle { NYSPrimaryButtonStyle() }
}

extension ButtonStyle where Self == NYSSecondaryButtonStyle {
    static var nysSecondary: NYSSecondaryButtonStyle { NYSSecondaryButtonStyle() }
}
