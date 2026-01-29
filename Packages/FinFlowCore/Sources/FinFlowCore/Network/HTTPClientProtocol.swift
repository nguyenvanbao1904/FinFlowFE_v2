import Foundation

/// Protocol cho HTTP Client - giúp dễ dàng test và thay thế implementation
public protocol HTTPClientProtocol: Sendable {
    func request<T: Codable & Sendable>(
        endpoint: String,
        method: String,
        body: (any Encodable & Sendable)?,
        headers: [String: String]?,
        version: String?
    ) async throws -> T
}

// Default convenience to keep call sites short
public extension HTTPClientProtocol {
    func request<T: Codable & Sendable>(
        endpoint: String,
        method: String,
        body: (any Encodable & Sendable)?
    ) async throws -> T {
        try await request(endpoint: endpoint, method: method, body: body, headers: nil, version: nil)
    }

    func request<T: Codable & Sendable>(
        endpoint: String,
        method: String
    ) async throws -> T {
        try await request(endpoint: endpoint, method: method, body: nil, headers: nil, version: nil)
    }
}
