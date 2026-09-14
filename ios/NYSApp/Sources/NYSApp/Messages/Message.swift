import Foundation

/// A row from `messages` (supabase/migrations/0001_init.sql).
struct Message: Decodable, Identifiable {
    let id: UUID
    let projectId: UUID
    let sender: String
    let body: String
    let createdAt: Date
    let authoredByAgent: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case sender
        case body
        case createdAt = "created_at"
        case authoredByAgent = "authored_by_agent"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectId = try container.decode(UUID.self, forKey: .projectId)
        sender = try container.decode(String.self, forKey: .sender)
        body = try container.decode(String.self, forKey: .body)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        // Defaulted rather than required: messages written before the agent
        // existed have no such column in older cached payloads.
        authoredByAgent = try container.decodeIfPresent(Bool.self, forKey: .authoredByAgent) ?? false
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
