import FinFlowCore
import SwiftUI

public struct BotChatCreatorView: View {
    let gateway: BotChatGateway
    let threadId: String?
    let initialPrompt: String?

    @State private var resolvedThreadId: String?
    @State private var isCreating = false
    @State private var errorMessage: String?

    public init(gateway: BotChatGateway, threadId: String?, initialPrompt: String?) {
        self.gateway = gateway
        self.threadId = threadId
        self.initialPrompt = initialPrompt
    }

    public var body: some View {
        Group {
            if let tid = resolvedThreadId ?? threadId {
                FinFlowBotChatView(
                    threadId: tid,
                    initialPrompt: initialPrompt,
                    loadMessagesHandler: { [gateway] in
                        try await gateway.loadMessages(threadId: tid)
                    },
                    sendMessageHandler: { [gateway] content in
                        try await gateway.sendMessage(content, threadId: tid)
                    }
                )
            } else if isCreating {
                ProgressView("Đang tạo hội thoại...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                VStack(spacing: Spacing.md) {
                    Text(errorMessage)
                        .font(AppTypography.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Thử lại") { Task { await createThread() } }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if threadId == nil, resolvedThreadId == nil {
                await createThread()
            }
        }
    }

    private func createThread() async {
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }

        do {
            let thread = try await gateway.createThread(title: nil)
            resolvedThreadId = thread.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
