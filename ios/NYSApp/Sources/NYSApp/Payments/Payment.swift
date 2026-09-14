import Foundation

/// A row from `payments` (supabase/migrations/0011_payments_and_message_writes.sql).
/// View only in Phase 1 — the app never takes a payment, it only shows the
/// schedule the office set.
struct Payment: Decodable, Identifiable {
    let id: UUID
    let projectId: UUID
    let label: String
    let amountCents: Int64
    /// Postgres `date`, which PostgREST serializes as a bare "2026-10-01"
    /// with no time or zone. Supabase's decoder expects full ISO8601
    /// timestamps, so decoding this straight into `Date` throws and takes
    /// the whole screen down with it — keep the raw string and parse it
    /// deliberately in `dueOn`.
    let dueOnRaw: String?
    let paidAt: Date?
    let sequence: Int

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case label
        case amountCents = "amount_cents"
        case dueOnRaw = "due_on"
        case paidAt = "paid_at"
        case sequence
    }

    var isPaid: Bool { paidAt != nil }

    /// Parsed in the calendar's own time zone: a due date is a wall-clock
    /// day to the homeowner, not an instant, so anchoring it to UTC would
    /// show the wrong day for anyone west of it.
    var dueOn: Date? {
        guard let dueOnRaw else { return nil }
        return Self.dueDateFormatter.date(from: dueOnRaw)
    }

    private static let dueDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Stored as cents to avoid binary floating point on money; convert only
    /// at the display boundary.
    var formattedAmount: String {
        let amount = Decimal(amountCents) / 100
        return amount.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }

    var isPastDue: Bool {
        guard !isPaid, let dueOn else { return false }
        return dueOn < Calendar.current.startOfDay(for: .now)
    }
}
