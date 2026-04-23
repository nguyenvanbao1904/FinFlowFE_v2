import Foundation
import FinFlowCore

/// Creates a new trade transaction (BUY/SELL/DEPOSIT/WITHDRAW) inside an investment portfolio.
public struct CreateTradeTransactionUseCase: Sendable {
    private let repository: any PortfolioRepositoryProtocol

    public init(repository: any PortfolioRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Cash transaction (DEPOSIT / WITHDRAW)

    public func executeCash(
        portfolioId: String,
        tradeType: TradeType,
        amount: Double,
        feePercent: Double? = nil,
        taxPercent: Double? = nil,
        transactionDate: Date
    ) async throws {
        let request = CreateTradeTransactionRequest(
            tradeType: tradeType,
            symbol: nil,
            quantity: nil,
            price: nil,
            amount: amount,
            feePercent: feePercent,
            taxPercent: taxPercent,
            transactionDate: Self.formatDate(transactionDate)
        )
        _ = try await repository.createTradeTransaction(portfolioId: portfolioId, request: request)
    }

    // MARK: - Stock trade (BUY / SELL / DIVIDEND)

    public func executeStock(
        portfolioId: String,
        tradeType: TradeType,
        symbol: String,
        quantity: Double,
        price: Double,
        feePercent: Double,
        taxPercent: Double? = nil,
        transactionDate: Date
    ) async throws {
        let request = CreateTradeTransactionRequest(
            tradeType: tradeType,
            symbol: symbol,
            quantity: quantity,
            price: price,
            amount: nil,
            feePercent: feePercent,
            taxPercent: taxPercent,
            transactionDate: Self.formatDate(transactionDate)
        )
        _ = try await repository.createTradeTransaction(portfolioId: portfolioId, request: request)
    }

    // MARK: - Helper

    /// Format Date thanh ISO8601 string (yeu cau cua backend Investment service).
    static func formatDate(_ date: Date) -> String {
        date.formatted(.iso8601)
    }
}
