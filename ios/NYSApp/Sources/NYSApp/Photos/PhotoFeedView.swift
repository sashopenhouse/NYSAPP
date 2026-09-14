import SwiftUI

struct PhotoFeedView: View {
    let projectId: UUID

    @State private var service: PhotoFeedService
    @State private var selectedPhoto: ProjectPhoto?

    init(projectId: UUID) {
        self.projectId = projectId
        _service = State(initialValue: PhotoFeedService(projectId: projectId))
    }

    var body: some View {
        ScrollView {
            if service.photos.isEmpty && !service.isLoading {
                NYSEmptyState(
                    title: "No photos yet",
                    message: "Your crew's photos appear here once our office has reviewed them."
                )
            } else {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(service.photos) { photo in
                        Button {
                            selectedPhoto = photo
                        } label: {
                            PhotoCard(photo: photo)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .background(NYSColor.white)
        .refreshable { await service.loadPhotos() }
        .task { await service.start() }
        .onDisappear {
            Task { await service.stop() }
        }
        .overlay {
            if service.isLoading && service.photos.isEmpty {
                ProgressView()
                    .tint(NYSColor.brandRed)
            }
        }
        .safeAreaInset(edge: .top) {
            if let errorMessage = service.errorMessage {
                NYSErrorBanner(message: errorMessage)
            }
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo)
        }
        .navigationTitle("Photos")
    }

}

private struct PhotoCard: View {
    let photo: ProjectPhoto

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: photo.url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholder(systemImage: "photo")
                default:
                    placeholder(systemImage: nil)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .clipped()

            if let caption = photo.caption, !caption.isEmpty {
                Text(caption)
                    .font(NYSFont.body())
                    .foregroundStyle(NYSColor.black)
            }

            Text(photo.displayDate.formatted(date: .abbreviated, time: .omitted))
                .font(NYSFont.body(13))
                .foregroundStyle(NYSColor.slateGray)
        }
    }

    @ViewBuilder
    private func placeholder(systemImage: String?) -> some View {
        ZStack {
            NYSColor.lightGray
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(NYSColor.slateGray)
            } else {
                ProgressView().tint(NYSColor.brandRed)
            }
        }
    }
}

private struct PhotoDetailView: View {
    let photo: ProjectPhoto

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            NYSColor.black.ignoresSafeArea()

            AsyncImage(url: photo.url) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                ProgressView().tint(NYSColor.white)
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(NYSColor.white)
                            .padding(12)
                    }
                }
                Spacer()

                if let caption = photo.caption, !caption.isEmpty {
                    Text(caption)
                        .font(NYSFont.body())
                        .foregroundStyle(NYSColor.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(NYSColor.black.opacity(0.6))
                }
            }
        }
    }
}
