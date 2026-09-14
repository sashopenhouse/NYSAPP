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
        TabView {
            NavigationStack {
                TimelineView(projectId: projectId)
            }
            .tabItem { Label("Project", systemImage: "list.bullet") }

            NavigationStack {
                PhotoFeedView(projectId: projectId)
            }
            .tabItem { Label("Photos", systemImage: "photo.on.rectangle") }

            NavigationStack {
                DocumentsView(projectId: projectId)
            }
            .tabItem { Label("Documents", systemImage: "folder") }

            NavigationStack {
                MessagesView(projectId: projectId)
            }
            .tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right") }

            NavigationStack {
                PaymentsView(projectId: projectId)
            }
            .tabItem { Label("Payments", systemImage: "creditcard") }
        }
        .tint(NYSColor.brandRed)
    }
}

struct HomeFileModeView: View {
    let projectId: UUID

    var body: some View {
        Text("Home file mode")
    }
}
