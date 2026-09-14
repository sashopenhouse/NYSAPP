import Foundation

/// A row from `media` (supabase/migrations/0001_init.sql). Only
/// office-approved rows ever reach the client — the `media_self` RLS policy
/// filters on `approved_for_customer` server-side, so this model has no
/// approval field: an unapproved photo is not merely hidden here, it is
/// never returned. See BUILD_PLAN.md "Media approval is in scope".
struct ProjectPhoto: Decodable, Identifiable {
    let id: UUID
    let projectId: UUID
    let url: URL
    let caption: String?
    let approvedAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case url
        case caption
        case approvedAt = "approved_at"
        case createdAt = "created_at"
    }

    /// Approval time is what the homeowner is shown: a photo taken weeks ago
    /// but released today reads as new to them. Falls back to capture time
    /// for rows approved before `approved_at` was being stamped.
    var displayDate: Date { approvedAt ?? createdAt }
}
