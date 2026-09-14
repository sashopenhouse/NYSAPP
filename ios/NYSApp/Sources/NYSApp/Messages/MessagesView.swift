import SwiftUI

struct MessagesView: View {
    let projectId: UUID

    @State private var service: MessagesService
    @State private var draft = ""
    @FocusState private var isComposerFocused: Bool

    init(projectId: UUID) {
        self.projectId = projectId
        _service = State(initialValue: MessagesService(projectId: projectId))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    if service.messages.isEmpty && !service.isLoading {
                        NYSEmptyState(
                            title: "No messages yet",
                            message: "Questions about your project? Send a note and our office will get back to you."
                        )
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(service.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                }
                .onChange(of: service.messages.count) {
                    guard let lastId = service.messages.last?.id else { return }
                    withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                }
            }

            composer
        }
        .background(NYSColor.white)
        .task { await service.start() }
        .onDisappear {
            Task { await service.stop() }
        }
        .safeAreaInset(edge: .top) {
            if let errorMessage = service.errorMessage {
                NYSErrorBanner(message: errorMessage)
            }
        }
        .navigationTitle("Messages")
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message the office", text: $draft, axis: .vertical)
                .font(NYSFont.body())
                .lineLimit(1...5)
                .padding(10)
                .background(NYSColor.lightGray)
                .overlay(Rectangle().stroke(NYSColor.slateGray.opacity(0.3), lineWidth: 1))
                .focused($isComposerFocused)

            Button {
                let body = draft
                draft = ""
                Task { await service.send(body) }
            } label: {
                if service.isSending {
                    ProgressView().tint(NYSColor.white)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundStyle(NYSColor.white)
            .frame(width: 44, height: 44)
            .background(canSend ? NYSColor.actionRed : NYSColor.slateGray.opacity(0.5))
            .disabled(!canSend)
        }
        .padding(8)
        .background(NYSColor.white)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(NYSColor.slateGray.opacity(0.2))
                .frame(height: 1)
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !service.isSending
    }
}

private struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isFromCustomer { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 4) {
                Text(message.body)
                    .font(NYSFont.body())
                    .foregroundStyle(message.isFromCustomer ? NYSColor.white : NYSColor.black)

                HStack(spacing: 4) {
                    // Disclosed, not hidden: a homeowner should be able to
                    // tell an automated status reply from their project
                    // manager typing.
                    if message.authoredByAgent {
                        Text("Automated reply")
                            .font(NYSFont.body(11))
                            .foregroundStyle(NYSColor.slateGray)
                        Text("·")
                            .font(NYSFont.body(11))
                            .foregroundStyle(NYSColor.slateGray)
                    }

                    Text(message.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(NYSFont.body(11))
                        .foregroundStyle(message.isFromCustomer ? NYSColor.white.opacity(0.8) : NYSColor.slateGray)
                }
            }
            .padding(12)
            .background(message.isFromCustomer ? NYSColor.brandRed : NYSColor.lightGray)

            if !message.isFromCustomer { Spacer(minLength: 40) }
        }
    }
}
