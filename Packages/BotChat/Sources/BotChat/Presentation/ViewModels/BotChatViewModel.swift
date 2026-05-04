import FinFlowCore
import Observation
import SwiftUI

private enum BotChatDefaults {
    static let greeting =
        "Chào bạn, mình là FinFlow Bot. Hãy hỏi về chi tiêu, ngân sách hoặc danh mục đầu tư để mình phân tích nhanh cho bạn."
    static let fallbackError =
        "Mình đang gặp lỗi tạm thời khi truy cập dữ liệu. Bạn thử gửi lại giúp mình sau vài giây nhé."
}

@MainActor
@Observable
public final class BotChatViewModel {
    // MARK: - State

    public var draft = ""
    public var isBotTyping = false
    public var isLoadingHistory = false
    public var errorMessage: String?
    public var messages: [FinFlowBotChatMessage]

    public let threadId: String
    private var hasLoadedHistory = false

    // MARK: - Dependencies

    private let quickPrompts: [String]
    private let initialPrompt: String?
    private let loadMessagesHandler: (@Sendable () async throws -> [FinFlowBotChatMessage])?
    private let sendMessageHandler: (@Sendable (String) async throws -> FinFlowBotSendResult)?

    public init(
        threadId: String,
        quickPrompts: [String] = [
            "Tóm tắt chi tiêu tuần này",
            "Kiểm tra ngân sách tháng này",
            "Gợi ý tối ưu danh mục đầu tư"
        ],
        initialPrompt: String? = nil,
        loadMessagesHandler: (@Sendable () async throws -> [FinFlowBotChatMessage])? = nil,
        sendMessageHandler: (@Sendable (String) async throws -> FinFlowBotSendResult)? = nil
    ) {
        self.threadId = threadId
        self.quickPrompts = quickPrompts
        self.initialPrompt = initialPrompt
        self.loadMessagesHandler = loadMessagesHandler
        self.sendMessageHandler = sendMessageHandler
        self.messages = Self.defaultMessages()
    }

    // MARK: - Computed

    public var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isBotTyping
            && !isLoadingHistory
    }

    public var shouldShowQuickPrompts: Bool {
        !messages.contains { $0.sender == .user }
    }

    public var availableQuickPrompts: [String] { quickPrompts }

    // MARK: - Actions

    public func onAppear() async {
        if let prompt = initialPrompt, !hasLoadedHistory {
            hasLoadedHistory = true
            applyPrompt(prompt)
        } else {
            await loadConversationIfNeeded()
        }
    }

    public func applyPrompt(_ prompt: String) {
        draft = prompt
        sendMessage()
    }

    public func sendMessage() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isBotTyping else { return }

        draft = ""
        messages.append(FinFlowBotChatMessage(sender: .user, text: trimmed, sentAt: Date()))
        isBotTyping = true

        Task { @MainActor in
            defer { isBotTyping = false }

            do {
                if let sendMessageHandler {
                    let result = try await sendMessageHandler(trimmed)
                    let assistantText = resolvedAssistantText(from: result)
                    messages.append(
                        FinFlowBotChatMessage(sender: .bot, text: assistantText, sentAt: Date(), citations: result.citations)
                    )
                    for event in result.mutationEvents {
                        switch event {
                        case .transactionSaved:
                            NotificationCenter.default.post(name: .transactionDidSave, object: nil)
                        case .budgetSaved:
                            NotificationCenter.default.post(name: .budgetDidSave, object: nil)
                        case .wealthAccountSaved:
                            NotificationCenter.default.post(name: .wealthAccountDidSave, object: nil)
                        }
                    }
                } else {
                    try await Task.sleep(for: .milliseconds(650))
                    messages.append(
                        FinFlowBotChatMessage(sender: .bot, text: botReply(for: trimmed), sentAt: Date())
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
                messages.append(
                    FinFlowBotChatMessage(sender: .bot, text: BotChatDefaults.fallbackError, sentAt: Date())
                )
            }
        }
    }

    // MARK: - Private

    private func loadConversationIfNeeded() async {
        guard !hasLoadedHistory else { return }
        hasLoadedHistory = true
        guard let loadMessagesHandler else { return }

        isLoadingHistory = true
        defer { isLoadingHistory = false }

        do {
            let history = try await loadMessagesHandler()
            if !history.isEmpty { messages = history }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolvedAssistantText(from result: FinFlowBotSendResult) -> String {
        let clarified = result.clarificationQuestion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let content = result.content.trimmingCharacters(in: .whitespacesAndNewlines)

        if result.needsClarification, !clarified.isEmpty { return clarified }
        if !content.isEmpty { return content }
        if !clarified.isEmpty { return clarified }
        return BotChatDefaults.fallbackError
    }

    private func botReply(for prompt: String) -> String {
        let normalized = prompt.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if normalized.contains("ngan sach") {
            return "Bạn có thể đặt ngưỡng cảnh báo ở mức 85% ngân sách để tránh vượt chi trước tuần cuối tháng."
        }
        if normalized.contains("chi tieu") || normalized.contains("thu chi") {
            return "Chi tiêu lớn nhất hiện nên gom theo 3 nhóm chính để thấy rõ khoản nào có thể cắt giảm ngay trong tuần này."
        }
        if normalized.contains("dau tu") || normalized.contains("co phieu") || normalized.contains("danh muc") {
            return "Mình gợi ý theo dõi tỷ trọng tiền mặt và biến động theo tuần để cân bằng rủi ro danh mục trước khi thêm vị thế mới."
        }
        return "Mình đã nhận câu hỏi. Bạn có thể hỏi cụ thể theo mốc thời gian như \u{201C}7 ngày gần đây\u{201D} hoặc \u{201C}tháng này\u{201D} để mình trả lời sát hơn."
    }

    private static func defaultMessages() -> [FinFlowBotChatMessage] {
        [FinFlowBotChatMessage(sender: .bot, text: BotChatDefaults.greeting, sentAt: Date())]
    }
}
