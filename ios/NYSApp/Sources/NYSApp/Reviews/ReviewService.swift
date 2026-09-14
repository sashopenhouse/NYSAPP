import Foundation
import Supabase

@Observable
final class ReviewService {
    private(set) var request: ReviewRequest?

    private let client: SupabaseClient
    private let projectId: UUID

    init(projectId: UUID, client: SupabaseClient = SupabaseClientProvider.client) {
        self.projectId = projectId
        self.client = client
    }

    var shouldPrompt: Bool { request?.isPending == true }

    /// Secondary surface, like offers: a failure here shows no prompt rather
    /// than an error over the customer's project.
    func load() async {
        let rows: [ReviewRequest]? = try? await client
            .from("review_requests")
            .select("id, project_id, opened_at, dismissed_at")
            .eq("project_id", value: projectId)
            .limit(1)
            .execute()
            .value

        request = rows?.first
    }

    func markOpened() async {
        await stamp(column: "opened_at")
    }

    func markDismissed() async {
        await stamp(column: "dismissed_at")
    }

    private func stamp(column: String) async {
        guard let request else { return }

        // Optimistic: the prompt disappears on tap, and stays gone even if
        // the write loses the race with the view being torn down.
        self.request = request.stamping(column: column)

        try? await client
            .from("review_requests")
            .update([column: Date.now])
            .eq("id", value: request.id)
            .execute()

        await load()
    }
}
