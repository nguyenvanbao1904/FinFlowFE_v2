import Foundation

public struct ApiResponse<T: Codable & Sendable>: Codable, Sendable {
    public let code: Int
    public let message: String?
    public let result: T?
}

/// Empty response for endpoints that return no data (e.g., logout, delete)
public struct EmptyResponse: Codable, Sendable {
    public init() {}
}

public struct PageResponse<T: Codable & Sendable>: Codable, Sendable {
    public let content: [T]
    public let totalElements: Int
    public let totalPages: Int
    public let number: Int
    public let size: Int
    public let first: Bool
    public let last: Bool
}
