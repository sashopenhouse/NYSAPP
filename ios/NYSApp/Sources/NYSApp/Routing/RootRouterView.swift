import SwiftUI

struct RootRouterView: View {
    @State private var auth = AuthService()
    @State private var mode: AppMode?
    @State private var isResolving = false

    var body: some View {
        Group {
            switch auth.status {
            case .signedOut, .codeSent:
                PhoneSignInView()
            case .signedIn:
                modeView
            }
        }
        .environment(auth)
        .task { await auth.restoreSession() }
    }

    @ViewBuilder
    private var modeView: some View {
        switch mode {
        case nil:
            ProgressView()
                .task { await resolveMode() }
        case .prospect:
            ProspectModeView()
        case .project(let projectId):
            ProjectModeView(projectId: projectId)
        case .homeFile(let projectId):
            HomeFileModeView(projectId: projectId)
        }
    }

    private func resolveMode() async {
        guard !isResolving else { return }
        isResolving = true
        defer { isResolving = false }
        mode = (try? await AppModeResolver.resolve(client: SupabaseClientProvider.client)) ?? .prospect
    }
}
