import SwiftUI

struct InstallDayCard: View {
    let crewNames: [String]
    let windowStart: Date?
    let windowEnd: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Install Day", systemImage: "hammer.fill")
                .font(NYSFont.subheadline(17))
                .foregroundStyle(NYSColor.black)

            if let windowStart, let windowEnd {
                Text("\(windowStart.formatted(date: .abbreviated, time: .shortened)) – \(windowEnd.formatted(date: .omitted, time: .shortened))")
                    .font(NYSFont.body())
                    .foregroundStyle(NYSColor.black)
            } else {
                Text("Arrival window not yet scheduled.")
                    .font(NYSFont.body())
                    .foregroundStyle(NYSColor.slateGray)
            }

            if !crewNames.isEmpty {
                Text("Crew: \(crewNames.joined(separator: ", "))")
                    .font(NYSFont.body())
                    .foregroundStyle(NYSColor.slateGray)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NYSColor.lightGray)
        .overlay(Rectangle().stroke(NYSColor.slateGray.opacity(0.2), lineWidth: 1))
    }
}
