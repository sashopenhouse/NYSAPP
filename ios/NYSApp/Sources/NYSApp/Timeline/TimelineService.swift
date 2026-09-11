import Foundation
import Supabase

@Observable
final class TimelineService {
    private(set) var events: [ProjectEvent] = []
    private(set) var currentStage: ProjectStage?
    private(set) var summary: ProjectSummary?
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
        await loadSummary()
        await loadEvents()
        await subscribeToLiveUpdates()
    }

    func loadSummary() async {
        do {
            summary = try await client
                .from("projects")
                .select("id, stage, crew_ids, install_window_start, install_window_end")
                .eq("id", value: projectId)
                .single()
                .execute()
                .value
        } catch {
            // Non-fatal — the timeline itself still renders from events.
        }
    }

    func stop() async {
        if let realtimeChannel {
            await client.removeChannel(realtimeChannel)
        }
        realtimeChannel = nil
    }

    func loadEvents() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched: [ProjectEvent] = try await client
                .from("project_events")
                .select()
                .eq("project_id", value: projectId)
                .order("occurred_at", ascending: true)
                .execute()
                .value
            events = fetched
            currentStage = fetched.last?.resolvedStage
        } catch {
            errorMessage = "Couldn't load your project timeline. Pull to refresh."
        }
    }

    /// Stage changes arrive via the connecteam-webhook edge function
    /// (docs/sync-validation.md) writing new project_events rows in near
    /// real time. Subscribing here means a homeowner sees a stage update
    /// without reopening the app.
    private func subscribeToLiveUpdates() async {
        let channel = client.channel("project-events-\(projectId.uuidString)")
        realtimeChannel = channel

        let changes = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "project_events",
            filter: .eq("project_id", value: projectId.uuidString)
        )

        await channel.subscribe()

        for await _ in changes {
            await loadEvents()
            await loadSummary()
        }
    }
}
