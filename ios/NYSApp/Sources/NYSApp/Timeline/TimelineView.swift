import SwiftUI

struct TimelineView: View {
    let projectId: UUID

    @State private var service: TimelineService

    init(projectId: UUID) {
        self.projectId = projectId
        _service = State(initialValue: TimelineService(projectId: projectId))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if service.currentStage == .install, let summary = service.summary {
                    InstallDayCard(
                        crewNames: summary.crewIds,
                        windowStart: summary.installWindowStart,
                        windowEnd: summary.installWindowEnd
                    )
                }

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(ProjectStage.allCases) { stage in
                        TimelineRow(
                            stage: stage,
                            status: status(for: stage),
                            occurredAt: occurredAt(for: stage),
                            isLast: stage == ProjectStage.allCases.last
                        )
                    }
                }
            }
            .padding()
        }
        .refreshable { await service.loadEvents() }
        .task {
            await service.start()
        }
        .onDisappear {
            Task { await service.stop() }
        }
        .overlay {
            if service.isLoading && service.events.isEmpty {
                ProgressView()
            }
        }
        .safeAreaInset(edge: .top) {
            if let errorMessage = service.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(.red.opacity(0.1))
            }
        }
        .navigationTitle("Your Project")
    }

    private func status(for stage: ProjectStage) -> TimelineRow.Status {
        guard let currentStage = service.currentStage else { return .upcoming }
        if stage.order < currentStage.order { return .complete }
        if stage.order == currentStage.order { return .current }
        return .upcoming
    }

    private func occurredAt(for stage: ProjectStage) -> Date? {
        service.events.last { $0.resolvedStage == stage }?.occurredAt
    }
}

private struct TimelineRow: View {
    enum Status {
        case complete, current, upcoming
    }

    let stage: ProjectStage
    let status: Status
    let occurredAt: Date?
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                marker
                if !isLast {
                    Rectangle()
                        .fill(status == .complete ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 2)
                }
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(stage.title)
                    .font(.headline)
                    .foregroundStyle(status == .upcoming ? .secondary : .primary)

                if let occurredAt {
                    Text(occurredAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, isLast ? 0 : 24)

            Spacer()
        }
    }

    @ViewBuilder
    private var marker: some View {
        switch status {
        case .complete:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.accentColor)
        case .current:
            Image(systemName: "circle.fill")
                .foregroundStyle(Color.accentColor)
        case .upcoming:
            Image(systemName: "circle")
                .foregroundStyle(.secondary.opacity(0.5))
        }
    }
}
