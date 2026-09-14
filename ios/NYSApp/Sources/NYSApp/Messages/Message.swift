import Foundation

/// A row from `messages` (supabase/migrations/0001_init.sql).
struct Message: Decodable, Identifiable {
    let id: UUID
    let projectId: UUID
    let sender: String
    let body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case sender
        case body
        case createdAt = "created_at"
    }

    /// Mirrors the `sender` check constraint. RLS only ever lets a client
    /// insert 'customer', so anything else came from the office.
    var isFromCustomer: Bool { sender == "customer" }
}

/// The insert payload. `tenant_id` is required by the RLS check, so it's
/// carried explicitly rather than defaulted server-side.
struct NewMessage: Encodable {
    let projectId: UUID
    let tenantId: UUID
    let sender: String
    let body: String

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case tenantId = "tenant_id"
        case sender
        case body
    }

    init(projectId: UUID, tenantId: UUID, body: String) {
        self.projectId = projectId
        self.tenantId = tenantId
        self.sender = "customer"
        self.body = body
    }
}
