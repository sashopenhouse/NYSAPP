import SwiftUI

/// Offers shown inline above a screen's own content. Deliberately not a tab:
/// promos earn attention by being adjacent to something the customer came
/// for, and a dedicated "Offers" tab in a project-tracking app reads as an
/// ad surface. Renders nothing at all when there's nothing live.
struct OffersStrip: View {
    let audience: Offer.Audience

    @State private var service: OffersService
    @Environment(\.openURL) private var openURL

    init(audience: Offer.Audience) {
        self.audience = audience
        _service = State(initialValue: OffersService(audience: audience))
    }

    var body: some View {
        Group {
            if !service.offers.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(service.offers) { offer in
                        OfferCard(offer: offer) {
                            if let url = offer.ctaUrl { openURL(url) }
                        }
                    }
                }
            }
        }
        .task { await service.loadOffers() }
    }
}

private struct OfferCard: View {
    let offer: Offer
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageUrl = offer.imageUrl {
                AsyncImage(url: imageUrl) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    NYSColor.lightGray
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .clipped()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(offer.title)
                    .font(NYSFont.subheadline(17))
                    .foregroundStyle(NYSColor.black)
                    .multilineTextAlignment(.leading)

                if let body = offer.body, !body.isEmpty {
                    Text(body)
                        .font(NYSFont.body(15))
                        .foregroundStyle(NYSColor.slateGray)
                        .multilineTextAlignment(.leading)
                }

                if let expiryNote = offer.expiryNote {
                    Text(expiryNote)
                        .font(NYSFont.body(13))
                        .foregroundStyle(NYSColor.actionRed)
                }

                if let ctaLabel = offer.ctaLabel, offer.ctaUrl != nil {
                    Button(ctaLabel, action: onTap)
                        .buttonStyle(.nysPrimary)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, offer.imageUrl == nil ? 0 : 12)
            .padding(.bottom, offer.imageUrl == nil ? 0 : 12)
        }
        .padding(offer.imageUrl == nil ? 12 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NYSColor.lightGray)
        .overlay(Rectangle().stroke(NYSColor.slateGray.opacity(0.2), lineWidth: 1))
    }
}
