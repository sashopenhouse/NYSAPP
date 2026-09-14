import SwiftUI

/// The error banner and empty state every project-mode screen needs.
/// Extracted from TimelineView/PhotoFeedView so the four Phase 1 screens
/// don't each carry their own copy.
struct NYSErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(NYSFont.body(13))
            .foregroundStyle(NYSColor.white)
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(NYSColor.actionRed)
    }
}

struct NYSEmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(NYSFont.subheadline(17))
                .foregroundStyle(NYSColor.black)
            Text(message)
                .font(NYSFont.body())
                .foregroundStyle(NYSColor.slateGray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, 80)
    }
}
