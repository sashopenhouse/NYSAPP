import Foundation

struct ProjectEvent: Decodable, Identifiable {
    let id: UUID
    let projectId: UUID
    let stage: String
    let occurredAt: Date
    let source: String

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case stage
        case occurredAt = "occurred_at"
        case source
    }

    var resolvedStage: ProjectStage? {
        ProjectStage(rawValue: stage)
    }
}
