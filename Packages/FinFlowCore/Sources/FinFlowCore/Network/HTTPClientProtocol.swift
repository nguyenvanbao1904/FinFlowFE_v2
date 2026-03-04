import Foundation

/// Protocol cho HTTP Client - giúp dễ dàng test và thay thế implementation
public protocol HTTPClientProtocol: Sendable {
    // swiftlint:disable:next function_parameter_count
    func request<T: Codable & Sendable>(
        endpoint: String,
        method: String,
        body: (any Encodable & Sendable)?,
        headers: [String: String]?,
        version: String?,
        retryOn401: Bool
    ) async throws -> T
}

// Default convenience to keep call sites short
public extension HTTPClientProtocol {
    // Overload for backward compatibility (default retryOn401 = true)
    func request<T: Codable & Sendable>(
        endpoint: String,
        method: String,
        body: (any Encodable & Sendable)?,
        headers: [String: String]?,
        version: String?
    ) async throws -> T {
        return try await request(
            endpoint: endpoint,
            method: method,
            body: body,
            headers: headers,
            version: version,
            retryOn401: true
        )
    }

    func request<T: Codable & Sendable>(
        endpoint: String,
        method: String,
        body: (any Encodable & Sendable)?
    ) async throws -> T {
        try await request(endpoint: endpoint, method: method, body: body, headers: nil, version: nil, retryOn401: true)
    }

    func request<T: Codable & Sendable>(
        endpoint: String,
        method: String
    ) async throws -> T {
        try await request(endpoint: endpoint, method: method, body: nil, headers: nil, version: nil)
    }
}
