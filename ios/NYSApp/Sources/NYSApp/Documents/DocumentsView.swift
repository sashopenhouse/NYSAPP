import SwiftUI

struct DocumentsView: View {
    let projectId: UUID

    @State private var service: DocumentsService
    @Environment(\.openURL) private var openURL

    init(projectId: UUID) {
        self.projectId = projectId
        _service = State(initialValue: DocumentsService(projectId: projectId))
    }

    var body: some View {
        ScrollView {
            if service.documents.isEmpty && !service.isLoading {
                NYSEmptyState(
                    title: "No documents yet",
                    message: "Your contract, permit, and product spec sheets appear here as they're ready."
                )
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(service.documents) { document in
                        Button {
                            openURL(document.url)
                        } label: {
                            DocumentRow(document: document)
                        }
                        .buttonStyle(.plain)

                        Rectangle()
                            .fill(NYSColor.slateGray.opacity(0.2))
                            .frame(height: 1)
                    }
                }
                .padding(.top, 8)
            }
        }
        .background(NYSColor.white)
        .refreshable { await service.loadDocuments() }
        .task { await service.loadDocuments() }
        .overlay {
            if service.isLoading && service.documents.isEmpty {
                ProgressView().tint(NYSColor.brandRed)
            }
        }
        .safeAreaInset(edge: .top) {
            if let errorMessage = service.errorMessage {
                NYSErrorBanner(message: errorMessage)
            }
        }
        .navigationTitle("Documents")
    }
}

private struct DocumentRow: View {
    let document: ProjectDocument

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: document.resolvedKind.systemImage)
                .font(.system(size: 20))
                .foregroundStyle(NYSColor.brandRed)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(document.displayTitle)
                    .font(NYSFont.subheadline(17))
                    .foregroundStyle(NYSColor.black)
                    .multilineTextAlignment(.leading)

                Text(document.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(NYSFont.body(13))
                    .foregroundStyle(NYSColor.slateGray)
            }

            Spacer()

            Image(systemName: "arrow.up.right.square")
                .foregroundStyle(NYSColor.slateGray)
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
