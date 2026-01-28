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
