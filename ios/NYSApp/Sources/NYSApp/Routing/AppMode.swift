import Foundation

/// The three states from BUILD_PLAN.md. Never set directly by the user —
/// always derived from the Supabase mirror via AppModeResolver.
enum AppMode: Equatable {
    case prospect
    case project(projectId: UUID)
    case homeFile(projectId: UUID)
}
