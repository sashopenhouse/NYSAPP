import Foundation
import Supabase

@Observable
final class DocumentsService {
    private(set) var documents: [ProjectDocument] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let client: SupabaseClient
    private let projectId: UUID

    init(projectId: UUID, client: SupabaseClient = SupabaseClientProvider.client) {
        self.projectId = projectId
        self.client = client
    }

    func loadDocuments() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            documents = try await client
                .from("documents")
                .select("id, project_id, kind, url, title, created_at")
                .eq("project_id", value: projectId)
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            errorMessage = "Couldn't load your documents. Pull to refresh."
        }
    }
}
