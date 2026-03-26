import Foundation

// MARK: - Investment Portfolio DTOs

/// Portfolio DTO from Backend (GET/POST /api/investments/portfolios)
public struct PortfolioResponse: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let cashBalance: Double
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String,
        name: String,
        cashBalance: Double,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.cashBalance = cashBalance
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct CreatePortfolioRequest: Codable, Sendable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

