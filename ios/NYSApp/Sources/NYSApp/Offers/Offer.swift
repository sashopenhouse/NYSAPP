import Foundation

/// A row from `offers` (supabase/migrations/0012_offers_and_reviews.sql).
/// RLS already restricts reads to published, in-window rows, so anything
/// that arrives here is live — the client only filters by audience.
struct Offer: Decodable, Identifiable {
    let id: UUID
    let title: String
    let body: String?
    let audiences: [String]
    let ctaLabel: String?
    let ctaUrl: URL?
    let imageUrl: URL?
    let endsAt: Date?
    let sequence: Int

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case audiences
        case ctaLabel = "cta_label"
        case ctaUrl = "cta_url"
        case imageUrl = "image_url"
        case endsAt = "ends_at"
        case sequence
    }

    /// Mirrors the `audiences` check constraint.
    enum Audience: String {
        case prospect
        case project
        case homeFile = "home_file"
    }

    func targets(_ audience: Audience) -> Bool {
        audiences.contains(audience.rawValue)
    }

    /// Only shown when an end date is genuinely near — a countdown on an
    /// offer that runs for months reads as fake urgency.
    var expiryNote: String? {
        guard let endsAt else { return nil }
        let days = Calendar.current.dateComponents([.day], from: .now, to: endsAt).day ?? 0
        guard days >= 0, days <= 30 else { return nil }
        return days == 0 ? "Ends today" : "Ends in \(days) day\(days == 1 ? "" : "s")"
    }
}
