import SwiftUI

// Placeholder so the scaffold builds and runs on a simulator.
// Real three-state routing (Prospect / Project / Home file) is step 4
// of the build plan, after auth and the Supabase mirror exist — see
// BUILD_PLAN.md. Do not build out state-specific screens here yet.
struct RootRouterView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("New York Sash")
                .font(.title)
                .bold()
            Text("Scaffold running. Auth + router not yet implemented.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}
