import SwiftUI

struct PaymentsView: View {
    let projectId: UUID

    @State private var service: PaymentsService

    init(projectId: UUID) {
        self.projectId = projectId
        _service = State(initialValue: PaymentsService(projectId: projectId))
    }

    var body: some View {
        ScrollView {
            if service.payments.isEmpty && !service.isLoading {
                NYSEmptyState(
                    title: "No payment schedule yet",
                    message: "Your payment schedule appears here once your contract is finalized."
                )
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    remainingCard

                    VStack(spacing: 0) {
                        ForEach(service.payments) { payment in
                            PaymentRow(payment: payment)
                            Rectangle()
                                .fill(NYSColor.slateGray.opacity(0.2))
                                .frame(height: 1)
                        }
                    }

                    Text("This schedule is for reference. New York Sash collects payments directly — you can't pay in the app.")
                        .font(NYSFont.body(13))
                        .foregroundStyle(NYSColor.slateGray)
                }
                .padding()
            }
        }
        .background(NYSColor.white)
        .refreshable { await service.loadPayments() }
        .task { await service.loadPayments() }
        .overlay {
            if service.isLoading && service.payments.isEmpty {
                ProgressView().tint(NYSColor.brandRed)
            }
        }
        .safeAreaInset(edge: .top) {
            if let errorMessage = service.errorMessage {
                NYSErrorBanner(message: errorMessage)
            }
        }
        .navigationTitle("Payments")
    }

    private var remainingCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Remaining balance")
                .font(NYSFont.body(13))
                .foregroundStyle(NYSColor.slateGray)
            Text(service.remainingFormatted)
                .font(NYSFont.headline(28))
                .foregroundStyle(NYSColor.black)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NYSColor.lightGray)
        .overlay(Rectangle().stroke(NYSColor.slateGray.opacity(0.2), lineWidth: 1))
    }
}

private struct PaymentRow: View {
    let payment: Payment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.label)
                    .font(NYSFont.subheadline(17))
                    .foregroundStyle(NYSColor.black)

                if payment.isPaid, let paidAt = payment.paidAt {
                    Text("Paid \(paidAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(NYSFont.body(13))
                        .foregroundStyle(NYSColor.slateGray)
                } else if let dueOn = payment.dueOn {
                    Text("Due \(dueOn.formatted(date: .abbreviated, time: .omitted))")
                        .font(NYSFont.body(13))
                        .foregroundStyle(payment.isPastDue ? NYSColor.actionRed : NYSColor.slateGray)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(payment.formattedAmount)
                    .font(NYSFont.subheadline(17))
                    .foregroundStyle(NYSColor.black)

                if payment.isPaid {
                    Label("Paid", systemImage: "checkmark")
                        .font(NYSFont.body(13))
                        .foregroundStyle(NYSColor.brandRed)
                }
            }
        }
        .padding(.vertical, 14)
    }
}
