import Foundation
import Supabase

@Observable
final class MessagesService {
    private(set) var messages: [Message] = []
    private(set) var isLoading = false
    private(set) var isSending = false
    private(set) var errorMessage: String?

    private let client: SupabaseClient
    private let projectId: UUID
    private var tenantId: UUID?
    private var realtimeChannel: RealtimeChannelV2?

    init(projectId: UUID, client: SupabaseClient = SupabaseClientProvider.client) {
        self.projectId = projectId
        self.client = client
    }

    func start() async {
        await loadTenantId()
        await loadMessages()
        await subscribeToLiveUpdates()
    }

    func stop() async {
        if let realtimeChannel {
            await client.removeChannel(realtimeChannel)
        }
        realtimeChannel = nil
    }

    /// The insert policy checks tenant_id against the caller's own project,
    /// so a send needs it. Read it from the project row rather than
    /// threading it through AppMode — RLS already restricts this select to
    /// the signed-in homeowner's own project.
    private func loadTenantId() async {
        struct TenantRow: Decodable {
            let tenantId: UUID
            enum CodingKeys: String, CodingKey { case tenantId = "tenant_id" }
        }

        let row: TenantRow? = try? await client
            .from("projects")
            .select("tenant_id")
            .eq("id", value: projectId)
            .single()
            .execute()
            .value
        tenantId = row?.tenantId
    }

    func loadMessages() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            messages = try await client
                .from("messages")
                .select("id, project_id, sender, body, created_at, authored_by_agent")
                .eq("project_id", value: projectId)
                .order("created_at", ascending: true)
                .execute()
                .value
        } catch {
            errorMessage = "Couldn't load your messages. Pull to refresh."
        }
    }

    func send(_ body: String) async {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        // Recover the tenant if the initial load failed, so a send isn't
        // permanently dead for the rest of the session.
        if tenantId == nil { await loadTenantId() }
        guard let tenantId else {
            errorMessage = "Couldn't send your message. Pull to refresh and try again."
            return
        }

        isSending = true
        defer { isSending = false }

        do {
            try await client
                .from("messages")
                .insert(NewMessage(projectId: projectId, tenantId: tenantId, body: trimmed))
                .execute()
            await loadMessages()
        } catch {
            errorMessage = "Couldn't send your message. Try again."
        }
    }

    /// Office replies are inserts from the service role, so INSERT is the
    /// only event this thread cares about.
    private func subscribeToLiveUpdates() async {
        let channel = client.channel("project-messages-\(projectId.uuidString)")
        realtimeChannel = channel

        let changes = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: .eq("project_id", value: projectId.uuidString)
        )

        await channel.subscribe()

        for await _ in changes {
            await loadMessages()
        }
    }
}
