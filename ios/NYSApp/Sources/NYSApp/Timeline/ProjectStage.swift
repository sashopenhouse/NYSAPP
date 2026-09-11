import Foundation

/// Mirrors the `stage` check constraint on `projects`/`project_events`
/// (supabase/migrations/0001_init.sql). Order here is the canonical
/// pipeline order for the timeline UI.
enum ProjectStage: String, CaseIterable, Identifiable {
    case measure
    case orderPlaced = "order_placed"
    case permit
    case installScheduled = "install_scheduled"
    case install
    case punchList = "punch_list"
    case final

    var id: String { rawValue }

    var title: String {
        switch self {
        case .measure: "Measure"
        case .orderPlaced: "Order Placed"
        case .permit: "Permit"
        case .installScheduled: "Install Scheduled"
        case .install: "Install"
        case .punchList: "Punch List"
        case .final: "Final"
        }
    }

    var order: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}
