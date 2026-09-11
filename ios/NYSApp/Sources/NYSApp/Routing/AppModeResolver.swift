import Foundation
import Supabase

/// Resolves which of the three app states applies to the signed-in user.
/// contact_id arrives pre-baked into the JWT by the custom access token
/// hook (supabase/migrations/0002_auth_hook.sql), which looks it up by
/// phone at token-issuance time — the client never queries contacts/projects
/// before establishing identity. See BUILD_PLAN.md "Architecture".
enum AppModeResolver {
    struct NoContactIdInSession: Error {}

    private struct ProjectRow: Decodable {
        let id: UUID
        let stage: String
    }

    static func resolve(client: SupabaseClient) async throws -> AppMode {
        let session = try await client.auth.session
        guard let contactId = decodeContactIdFromJWTClaims(session.accessToken) else {
            // No contacts row matched this phone at token-issuance time.
            return .prospect
        }

        let projects: [ProjectRow] = try await client
            .from("projects")
            .select("id, stage")
            .eq("contact_id", value: contactId)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        guard let project = projects.first else {
            return .prospect
        }

        return project.stage == "final"
            ? .homeFile(projectId: project.id)
            : .project(projectId: project.id)
    }

    /// The custom claims (contact_id, tenant_id) land in the JWT payload
    /// itself, not user_metadata — decode the token's middle segment to
    /// read them until supabase-swift exposes custom claims directly.
    private static func decodeContactIdFromJWTClaims(_ accessToken: String) -> UUID? {
        let segments = accessToken.split(separator: ".")
        guard segments.count == 3 else { return nil }

        var base64 = String(segments[1])
        base64 = base64.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contactIdString = json["contact_id"] as? String
        else { return nil }

        return UUID(uuidString: contactIdString)
    }
}
