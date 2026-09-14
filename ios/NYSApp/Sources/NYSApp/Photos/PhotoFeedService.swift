import Foundation
import Supabase

@Observable
final class PhotoFeedService {
    private(set) var photos: [ProjectPhoto] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let client: SupabaseClient
    private let projectId: UUID
    private var realtimeChannel: RealtimeChannelV2?

    init(projectId: UUID, client: SupabaseClient = SupabaseClientProvider.client) {
        self.projectId = projectId
        self.client = client
    }

    func start() async {
        await loadPhotos()
        await subscribeToLiveUpdates()
    }

    func stop() async {
        if let realtimeChannel {
            await client.removeChannel(realtimeChannel)
        }
        realtimeChannel = nil
    }

    func loadPhotos() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            photos = try await client
                .from("media")
                .select("id, project_id, url, caption, approved_at, created_at")
                .eq("project_id", value: projectId)
                // Newest-released first. `approved_at` is null on rows approved
                // before it was stamped, so keep those nulls last (PostgREST's
                // default, stated here so a reordering doesn't silently float
                // the oldest photos to the top) and break the tie on created_at,
                // matching the fallback in ProjectPhoto.displayDate.
                .order("approved_at", ascending: false, nullsFirst: false)
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            errorMessage = "Couldn't load your project photos. Pull to refresh."
        }
    }

    /// Approval happens in the internal web view, not in this app, so the
    /// interesting event is an UPDATE flipping `approved_for_customer` —
    /// the INSERT the timeline listens for would fire while the row is still
    /// crew-only and invisible to RLS. Listening to both covers a row that
    /// arrives already approved.
    private func subscribeToLiveUpdates() async {
        let channel = client.channel("project-media-\(projectId.uuidString)")
        realtimeChannel = channel

        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "media",
            filter: .eq("project_id", value: projectId.uuidString)
        )

        await channel.subscribe()

        for await _ in changes {
            await loadPhotos()
        }
    }
}
