import FinFlowCore
import Foundation

public actor BotChatGateway {
    private let chatRepository: any ChatRepositoryProtocol

    public init(chatRepository: any ChatRepositoryProtocol) {
        self.chatRepository = chatRepository
    }

    public func loadThreads() async throws -> [ChatThreadResponse] {
        try await chatRepository.listThreads()
    }

    public func createThread(title: String?) async throws -> ChatThreadResponse {
        try await chatRepository.createThread(title: title)
    }

    public func deleteThread(threadId: String) async throws {
        try await chatRepository.deleteThread(threadId: threadId)
    }

    public func loadMessages(threadId: String) async throws -> [FinFlowBotChatMessage] {
        let messages = try await chatRepository.listMessages(threadId: threadId)
        return messages.map(mapMessage)
    }

    public func sendMessage(_ content: String, threadId: String) async throws -> FinFlowBotSendResult {
        let response = try await chatRepository.sendMessage(threadId: threadId, content: content)

        let assistant = response.assistantMessage
        let normalizedQuestion = response.clarificationQuestion?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedContent = assistant.content.trimmingCharacters(in: .whitespacesAndNewlines)

        let finalContent: String
        if response.needsClarification, let normalizedQuestion, !normalizedQuestion.isEmpty {
            finalContent = normalizedQuestion
        } else if !normalizedContent.isEmpty {
            finalContent = normalizedContent
        } else if let normalizedQuestion, !normalizedQuestion.isEmpty {
            finalContent = normalizedQuestion
        } else {
            finalContent = "Mình chưa có đủ dữ liệu để trả lời chính xác. Bạn giúp mình bổ sung thêm mã cổ phiếu hoặc giai đoạn nhé."
        }

        return FinFlowBotSendResult(
            content: finalContent,
            needsClarification: response.needsClarification,
            clarificationQuestion: response.clarificationQuestion,
            citations: assistant.sources.map(mapCitation)
        )
    }

    private func mapMessage(_ message: ChatMessageResponse) -> FinFlowBotChatMessage {
        let role = message.role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sender: FinFlowBotMessageSender = role == "user" ? .user : .bot
        return FinFlowBotChatMessage(
            id: message.id,
            sender: sender,
            text: message.content,
            sentAt: parseDate(message.createdAt),
            citations: message.sources.map(mapCitation)
        )
    }

    private func mapCitation(_ source: ChatMessageSourceResponse) -> FinFlowBotCitation {
        let normalizedTitle = (source.sourceTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let title = normalizedTitle.isEmpty ? "Tài liệu nội bộ FinFlow" : normalizedTitle

        return FinFlowBotCitation(
            id: source.chunkId ?? UUID().uuidString,
            sourceTitle: title,
            pageNumber: source.pageNumber,
            score: source.score.flatMap { NSDecimalNumber(decimal: $0).doubleValue }
        )
    }

    private func parseDate(_ value: String?) -> Date {
        guard let value, !value.isEmpty else { return Date() }

        if let parsed = Self.iso8601WithZone.date(from: value) { return parsed }
        if let parsed = Self.localFormatterWithMillis.date(from: value) { return parsed }
        if let parsed = Self.localFormatter.date(from: value) { return parsed }
        return Date()
    }

    private nonisolated(unsafe) static let iso8601WithZone: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let localFormatterWithMillis: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return formatter
    }()

    private static let localFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
}
