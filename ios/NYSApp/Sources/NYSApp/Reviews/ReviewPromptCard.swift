import SwiftUI

/// The Google review ask, shown once a project reaches 'final'.
///
/// Deliberately ungated: every customer gets the same prompt and the same
/// destination, with no "how did we do?" step that routes happy customers
/// to Google and unhappy ones to a private form. That pattern — review
/// gating — violates Google's review policies and the FTC's rule on
/// suppressing negative reviews, and puts the real NYS listing at risk.
/// The Messages tab is where an unhappy customer is directed instead, and
/// it is offered to everyone rather than shown selectively by sentiment.
struct ReviewPromptCard: View {
    let service: ReviewService

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How did we do?")
                .font(NYSFont.subheadline(17))
                .foregroundStyle(NYSColor.black)

            Text("Your project is complete. If you have a moment, a Google review helps other homeowners in your neighborhood find us.")
                .font(NYSFont.body(15))
                .foregroundStyle(NYSColor.slateGray)

            Button("Leave a Google review") {
                openURL(NYSLinks.googleReview)
                Task { await service.markOpened() }
            }
            .buttonStyle(.nysPrimary)

            Button("Not now") {
                Task { await service.markDismissed() }
            }
            .buttonStyle(.nysSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NYSColor.lightGray)
        .overlay(Rectangle().stroke(NYSColor.slateGray.opacity(0.2), lineWidth: 1))
    }
}
