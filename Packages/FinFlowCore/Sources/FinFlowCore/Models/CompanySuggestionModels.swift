import Foundation

/// Suggestion item for stock autocomplete (GET /api/investments/companies/suggest).
public struct CompanySuggestionResponse: Codable, Sendable, Identifiable, Hashable {
    public let id: String // ticker
    public let companyName: String?

    public init(id: String, companyName: String?) {
        self.id = id
        self.companyName = companyName
    }
}

/// Lightweight industry lookup item for investment portfolio screen.
public struct CompanyIndustryResponse: Codable, Sendable, Hashable {
    public let symbol: String
    public let industryLabel: String

    public init(symbol: String, industryLabel: String) {
        self.symbol = symbol
        self.industryLabel = industryLabel
    }
}
