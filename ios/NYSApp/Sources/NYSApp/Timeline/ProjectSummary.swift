import Foundation

struct ProjectSummary: Decodable {
    let id: UUID
    let stage: String
    let crewIds: [String]
    let installWindowStart: Date?
    let installWindowEnd: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case stage
        case crewIds = "crew_ids"
        case installWindowStart = "install_window_start"
        case installWindowEnd = "install_window_end"
    }
}
