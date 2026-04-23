import Foundation

public struct InvestmentAnalysisBundle: Sendable {
    public let overview: StockOverview
    public let shareholders: [ShareholderDataPoint]
    public let valuations: [ValuationDataPoint]
    public let financials: FinancialDataSeries?
    public let dividends: [DividendDataPoint]

    public init(
        overview: StockOverview,
        shareholders: [ShareholderDataPoint],
        valuations: [ValuationDataPoint],
        financials: FinancialDataSeries?,
        dividends: [DividendDataPoint]
    ) {
        self.overview = overview
        self.shareholders = shareholders
        self.valuations = valuations
        self.financials = financials
        self.dividends = dividends
    }
}
