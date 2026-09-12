import Foundation
import Supabase

/// Resolves which of the three app states applies to the signed-in user via
/// a single RPC call (supabase/migrations/0007_resolve_app_mode_rpc.sql).
/// That function reads auth.jwt() itself and looks up the matching contact
/// by email, so it needs no pre-baked custom JWT claim — no dashboard-only
/// Auth Hook toggle to get right, and no way for it to silently be off.
/// See BUILD_PLAN.md "Architecture".
enum AppModeResolver {
    private struct ResolveAppModeRow: Decodable {
        let contactId: UUID?
        let tenantId: UUID?
        let projectId: UUID?
        let stage: String?

        enum CodingKeys: String, CodingKey {
            case contactId = "contact_id"
            case tenantId = "tenant_id"
            case projectId = "project_id"
            case stage
        }
    }

    static func resolve(client: SupabaseClient) async throws -> AppMode {
        let rows: [ResolveAppModeRow] = try await client
            .rpc("resolve_app_mode")
            .execute()
            .value

        guard let row = rows.first, row.contactId != nil else {
            return .prospect
        }

        guard let projectId = row.projectId, let stage = row.stage else {
            return .prospect
        }

        return stage == "final"
            ? .homeFile(projectId: projectId)
            : .project(projectId: projectId)
    }
}
