import Foundation
import FinFlowCore

public struct GetCompanyIndustriesUseCase: Sendable {
    private let repository: any InvestmentRepositoryProtocol

    public init(repository: any InvestmentRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(symbols: [String]) async throws -> [CompanyIndustryResponse] {
        try await repository.getCompanyIndustries(symbols: symbols)
    }
}
