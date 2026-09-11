import SwiftUI

// Placeholders — real screens are later build-plan phases/steps
// (Phase 2 visualizer, step 5 timeline, Phase 3 home file). Kept here so
// RootRouterView compiles and is runnable on a simulator today.

struct ProspectModeView: View {
    var body: some View {
        Text("Prospect mode")
    }
}

struct ProjectModeView: View {
    let projectId: UUID

    var body: some View {
        Text("Project mode")
    }
}

struct HomeFileModeView: View {
    let projectId: UUID

    var body: some View {
        Text("Home file mode")
    }
}
