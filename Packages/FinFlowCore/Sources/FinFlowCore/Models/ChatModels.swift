import Foundation

public struct CreateChatThreadRequest: Codable, Sendable {
    public let title: String?

    public init(title: String?) {
        self.title = title
    }
}

public struct SendChatMessageRequest: Codable, Sendable {
    public let content: String

    public init(content: String) {
        self.content = content
    }
}

public struct ChatThreadResponse: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String?
    public let lastTicker: String?
    public let lastYear: Int?
    public let contextSummary: String?
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String,
        title: String?,
        lastTicker: String?,
        lastYear: Int?,
        contextSummary: String?,
        createdAt: String?,
        updatedAt: String?
    ) {
        self.id = id
        self.title = title
        self.lastTicker = lastTicker
        self.lastYear = lastYear
        self.contextSummary = contextSummary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ChatMessageSourceResponse: Codable, Sendable {
    public let chunkId: String?
    public let sourceTitle: String?
    public let pageNumber: Int?
    public let score: Decimal?

    public init(
        chunkId: String?,
        sourceTitle: String?,
        pageNumber: Int?,
        score: Decimal?
    ) {
        self.chunkId = chunkId
        self.sourceTitle = sourceTitle
        self.pageNumber = pageNumber
        self.score = score
    }
}

public struct ChatMessageResponse: Codable, Identifiable, Sendable {
    public let id: String
    public let threadId: String
    public let role: String
    public let content: String
    public let provider: String?
    public let model: String?
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let totalTokens: Int?
    public let costUsd: Decimal?
    public let latencyMs: Int?
    public let toolCallsJson: String?
    public let createdAt: String?
    public let sources: [ChatMessageSourceResponse]

    public init(
        id: String,
        threadId: String,
        role: String,
        content: String,
        provider: String?,
        model: String?,
        inputTokens: Int?,
        outputTokens: Int?,
        totalTokens: Int?,
        costUsd: Decimal?,
        latencyMs: Int?,
        toolCallsJson: String?,
        createdAt: String?,
        sources: [ChatMessageSourceResponse]
    ) {
        self.id = id
        self.threadId = threadId
        self.role = role
        self.content = content
        self.provider = provider
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.costUsd = costUsd
        self.latencyMs = latencyMs
        self.toolCallsJson = toolCallsJson
        self.createdAt = createdAt
        self.sources = sources
    }
}

public struct SendChatMessageResponse: Codable, Sendable {
    public let threadId: String
    public let needsClarification: Bool
    public let clarificationQuestion: String?
    public let userMessage: ChatMessageResponse
    public let assistantMessage: ChatMessageResponse

    public init(
        threadId: String,
        needsClarification: Bool,
        clarificationQuestion: String?,
        userMessage: ChatMessageResponse,
        assistantMessage: ChatMessageResponse
    ) {
        self.threadId = threadId
        self.needsClarification = needsClarification
        self.clarificationQuestion = clarificationQuestion
        self.userMessage = userMessage
        self.assistantMessage = assistantMessage
    }
}

public enum FinFlowBotMessageSender: Sendable {
    case bot
    case user
}

public struct FinFlowBotCitation: Identifiable, Equatable, Sendable {
    public let id: String
    public let sourceTitle: String
    public let pageNumber: Int?
    public let score: Double?

    public init(
        id: String = UUID().uuidString,
        sourceTitle: String,
        pageNumber: Int?,
        score: Double?
    ) {
        self.id = id
        self.sourceTitle = sourceTitle
        self.pageNumber = pageNumber
        self.score = score
    }
}

public struct FinFlowBotChatMessage: Identifiable, Equatable, Sendable {
    public let id: String
    public let sender: FinFlowBotMessageSender
    public let text: String
    public let sentAt: Date
    public let citations: [FinFlowBotCitation]

    public init(
        id: String = UUID().uuidString,
        sender: FinFlowBotMessageSender,
        text: String,
        sentAt: Date,
        citations: [FinFlowBotCitation] = []
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.sentAt = sentAt
        self.citations = citations
    }
}

public struct FinFlowBotSendResult: Sendable {
    public let content: String
    public let needsClarification: Bool
    public let clarificationQuestion: String?
    public let citations: [FinFlowBotCitation]

    public init(
        content: String,
        needsClarification: Bool,
        clarificationQuestion: String?,
        citations: [FinFlowBotCitation]
    ) {
        self.content = content
        self.needsClarification = needsClarification
        self.clarificationQuestion = clarificationQuestion
        self.citations = citations
    }
}
