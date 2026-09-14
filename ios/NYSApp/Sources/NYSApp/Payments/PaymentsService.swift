import Foundation
import Supabase

@Observable
final class PaymentsService {
    private(set) var payments: [Payment] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let client: SupabaseClient
    private let projectId: UUID

    init(projectId: UUID, client: SupabaseClient = SupabaseClientProvider.client) {
        self.projectId = projectId
        self.client = client
    }

    var totalCents: Int64 { payments.reduce(0) { $0 + $1.amountCents } }
    var paidCents: Int64 { payments.filter(\.isPaid).reduce(0) { $0 + $1.amountCents } }

    var remainingFormatted: String {
        let amount = Decimal(totalCents - paidCents) / 100
        return amount.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }

    func loadPayments() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            payments = try await client
                .from("payments")
                .select("id, project_id, label, amount_cents, due_on, paid_at, sequence")
                .eq("project_id", value: projectId)
                .order("sequence", ascending: true)
                .execute()
                .value
        } catch {
            errorMessage = "Couldn't load your payment schedule. Pull to refresh."
        }
    }
}
