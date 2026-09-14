import Foundation

/// A row from `documents` (supabase/migrations/0001_init.sql).
struct ProjectDocument: Decodable, Identifiable {
    let id: UUID
    let projectId: UUID
    let kind: String
    let url: URL
    let title: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case kind
        case url
        case title
        case createdAt = "created_at"
    }

    var resolvedKind: Kind { Kind(rawValue: kind) ?? .other }

    /// `title` is nullable in the schema, so fall back to the kind rather
    /// than rendering a blank row.
    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        return resolvedKind.title
    }

    /// Mirrors the `kind` check constraint on `documents`.
    enum Kind: String {
        case contract
        case permit
        case specSheet = "spec_sheet"
        case other

        var title: String {
            switch self {
            case .contract: "Contract"
            case .permit: "Permit"
            case .specSheet: "Spec Sheet"
            case .other: "Document"
            }
        }

        var systemImage: String {
            switch self {
            case .contract: "doc.text"
            case .permit: "checkmark.seal"
            case .specSheet: "ruler"
            case .other: "doc"
            }
        }
    }
}
