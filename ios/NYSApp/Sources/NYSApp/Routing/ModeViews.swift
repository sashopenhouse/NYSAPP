import SwiftUI

// The three top-level surfaces RootRouterView switches between.
// Prospect mode is still a holding screen until the Phase 2 visualizer
// lands; home file mode carries the review ask and offers today, with
// Phase 3's warranties and care guides still to come.

struct ProspectModeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Welcome to New York Sash")
                        .font(NYSFont.headline(28))
                        .foregroundStyle(NYSColor.black)

                    Text("The visualizer is coming soon. In the meantime, here's what we have going on.")
                        .font(NYSFont.body())
                        .foregroundStyle(NYSColor.slateGray)

                    OffersStrip(audience: .prospect)
                }
                .padding()
            }
            .background(NYSColor.white)
            .navigationTitle("New York Sash")
        }
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

/// Completed-job surface. Phase 3 adds warranties, care guides and service
/// requests; today it carries the review ask (fired by the final walkthrough
/// event) plus the documents and photos from the finished project, so a
/// homeowner who paid for a job still has somewhere to land.
struct HomeFileModeView: View {
    let projectId: UUID

    @State private var reviewService: ReviewService

    init(projectId: UUID) {
        self.projectId = projectId
        _reviewService = State(initialValue: ReviewService(projectId: projectId))
    }

    var body: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if reviewService.shouldPrompt {
                            ReviewPromptCard(service: reviewService)
                        }

                        Text("Your project is complete")
                            .font(NYSFont.headline(28))
                            .foregroundStyle(NYSColor.black)

                        Text("Warranties, care guides and service requests are on the way. Your documents and photos are still here any time you need them.")
                            .font(NYSFont.body())
                            .foregroundStyle(NYSColor.slateGray)

                        OffersStrip(audience: .homeFile)
                    }
                    .padding()
                }
                .background(NYSColor.white)
                .refreshable { await reviewService.load() }
                .task { await reviewService.load() }
                .navigationTitle("Home File")
            }
            .tabItem { Label("Home", systemImage: "house") }

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
        }
        .tint(NYSColor.brandRed)
    }
}
