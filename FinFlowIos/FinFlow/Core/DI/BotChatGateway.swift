//
//  BotChatGateway.swift
//  FinFlowIos
//

import FinFlowCore
import Foundation

actor BotChatGateway {
    private let chatRepository: any ChatRepositoryProtocol
    private var activeThreadId: String?

    init(chatRepository: any ChatRepositoryProtocol) {
        self.chatRepository = chatRepository
    }

    func loadMessages() async throws -> [FinFlowBotChatMessage] {
        let threadId = try await resolveThreadIdForRead()
        guard let threadId else { return [] }
        let messages = try await chatRepository.listMessages(threadId: threadId)
        return messages.map(mapMessage)
    }

    func sendMessage(_ content: String) async throws -> FinFlowBotSendResult {
        let threadId = try await ensureThreadId()
        let response = try await chatRepository.sendMessage(threadId: threadId, content: content)
        activeThreadId = response.threadId

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

    func startNewThread() async throws -> [FinFlowBotChatMessage] {
        let thread = try await chatRepository.createThread(title: nil)
        activeThreadId = thread.id
        return []
    }

    private func ensureThreadId() async throws -> String {
        if let activeThreadId, !activeThreadId.isEmpty {
            return activeThreadId
        }
        let newThread = try await chatRepository.createThread(title: nil)
        activeThreadId = newThread.id
        return newThread.id
    }

    private func resolveThreadIdForRead() async throws -> String? {
        if let activeThreadId, !activeThreadId.isEmpty {
            return activeThreadId
        }

        let threads = try await chatRepository.listThreads()
        guard let latest = threads.max(by: {
            ($0.updatedAt ?? $0.createdAt ?? "") < ($1.updatedAt ?? $1.createdAt ?? "")
        }) else {
            return nil
        }
        activeThreadId = latest.id
        return latest.id
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

    private static let iso8601WithZone: ISO8601DateFormatter = {
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
