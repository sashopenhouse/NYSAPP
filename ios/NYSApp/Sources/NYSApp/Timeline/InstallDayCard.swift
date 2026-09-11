import SwiftUI

struct InstallDayCard: View {
    let crewNames: [String]
    let windowStart: Date?
    let windowEnd: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Install Day", systemImage: "hammer.fill")
                .font(.headline)

            if let windowStart, let windowEnd {
                Text("\(windowStart.formatted(date: .abbreviated, time: .shortened)) – \(windowEnd.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
            } else {
                Text("Arrival window not yet scheduled.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !crewNames.isEmpty {
                Text("Crew: \(crewNames.joined(separator: ", "))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
