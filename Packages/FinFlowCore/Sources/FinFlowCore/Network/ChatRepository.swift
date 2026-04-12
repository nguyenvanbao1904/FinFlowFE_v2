import Foundation

public actor ChatRepository: ChatRepositoryProtocol {
    private let client: any HTTPClientProtocol

    public init(client: any HTTPClientProtocol) {
        self.client = client
    }

    public func createThread(title: String?) async throws -> ChatThreadResponse {
        let payload = CreateChatThreadRequest(
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        return try await client.request(
            endpoint: "/chat/threads",
            method: "POST",
            body: payload,
            headers: nil,
            version: nil
        )
    }

    public func listThreads() async throws -> [ChatThreadResponse] {
        try await client.request(
            endpoint: "/chat/threads",
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }

    public func listMessages(threadId: String) async throws -> [ChatMessageResponse] {
        let trimmed = threadId.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await client.request(
            endpoint: "/chat/threads/\(trimmed)/messages",
            method: "GET",
            body: nil as String?,
            headers: nil,
            version: nil
        )
    }

    public func sendMessage(threadId: String, content: String) async throws -> SendChatMessageResponse {
        let trimmedThreadId = threadId.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = SendChatMessageRequest(
            content: content.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        return try await client.request(
            endpoint: "/chat/threads/\(trimmedThreadId)/messages",
            method: "POST",
            body: payload,
            headers: nil,
            version: nil,
            retryOn401: true,
            extendedTimeout: true
        )
    }
}
