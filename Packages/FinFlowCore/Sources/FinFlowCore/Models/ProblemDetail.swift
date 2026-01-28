import Foundation

/// RFC 7807 Problem Detail model used by backend error responses.
public struct ProblemDetail: Codable, Sendable {
    public let type: String?
    public let title: String?
    public let status: Int?
    public let detail: String?
    public let instance: String?
    public let code: Int?

    public init(
        type: String? = nil,
        title: String? = nil,
        status: Int? = nil,
        detail: String? = nil,
        instance: String? = nil,
        code: Int? = nil
    ) {
        self.type = type
        self.title = title
        self.status = status
        self.detail = detail
        self.instance = instance
        self.code = code
    }
}

