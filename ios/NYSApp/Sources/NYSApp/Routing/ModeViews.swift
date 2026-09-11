import SwiftUI

// Remaining placeholders — real screens are later build-plan phases
// (Phase 2 visualizer, Phase 3 home file). Kept here so RootRouterView
// compiles and is runnable on a simulator today.

struct ProspectModeView: View {
    var body: some View {
        Text("Prospect mode")
    }
}

struct ProjectModeView: View {
    let projectId: UUID

    var body: some View {
        NavigationStack {
            TimelineView(projectId: projectId)
        }
    }
}

struct HomeFileModeView: View {
    let projectId: UUID

    var body: some View {
        Text("Home file mode")
    }
}
