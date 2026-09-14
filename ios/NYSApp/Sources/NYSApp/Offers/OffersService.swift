import Foundation
import Supabase

@Observable
final class OffersService {
    private(set) var offers: [Offer] = []
    private(set) var isLoading = false

    private let client: SupabaseClient
    private let audience: Offer.Audience

    init(audience: Offer.Audience, client: SupabaseClient = SupabaseClientProvider.client) {
        self.audience = audience
        self.client = client
    }

    /// Offers are a secondary surface — a failure here should never surface
    /// an error banner over someone's project. It just shows nothing.
    func loadOffers() async {
        isLoading = true
        defer { isLoading = false }

        let fetched: [Offer]? = try? await client
            .from("offers")
            .select("id, title, body, audiences, cta_label, cta_url, image_url, ends_at, sequence")
            .contains("audiences", value: [audience.rawValue])
            .order("sequence", ascending: true)
            .execute()
            .value

        offers = fetched ?? []
    }
}
