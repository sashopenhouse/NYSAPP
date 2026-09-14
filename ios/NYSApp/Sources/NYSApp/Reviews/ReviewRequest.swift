import Foundation

/// A row from `review_requests` (supabase/migrations/0012_offers_and_reviews.sql),
/// created by a database trigger when a project reaches 'final' — the build
/// plan's "fired by the final walkthrough event, not a calendar date".
struct ReviewRequest: Decodable, Identifiable {
    let id: UUID
    let projectId: UUID
    let openedAt: Date?
    let dismissedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case openedAt = "opened_at"
        case dismissedAt = "dismissed_at"
    }

    /// Ask once. Someone who tapped through or said "not now" is done —
    /// re-prompting a customer who already went to Google is how an app
    /// earns a deletion.
    var isPending: Bool { openedAt == nil && dismissedAt == nil }

    /// Local copy with one timestamp column filled in, for the optimistic
    /// update in ReviewService — avoids relying on a memberwise initializer
    /// that a future stored property would silently change the shape of.
    func stamping(column: String) -> ReviewRequest {
        ReviewRequest(
            id: id,
            projectId: projectId,
            openedAt: column == "opened_at" ? .now : openedAt,
            dismissedAt: column == "dismissed_at" ? .now : dismissedAt
        )
    }
}
