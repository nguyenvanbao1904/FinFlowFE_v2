import Foundation

// MARK: - Investment Portfolio DTOs

/// Portfolio DTO from Backend (GET/POST /api/investments/portfolios)
public struct PortfolioResponse: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let cashBalance: Double
    public let totalCostBasis: Double?
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String,
        name: String,
        cashBalance: Double,
        totalCostBasis: Double? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.cashBalance = cashBalance
        self.totalCostBasis = totalCostBasis
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

public struct UpdatePortfolioRequest: Codable, Sendable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

// MARK: - Investment Portfolio Asset DTOs

/// Asset snapshot DTO from Backend (GET/POST /api/investments/portfolios/{portfolioId}/assets)
public struct PortfolioAssetResponse: Codable, Sendable, Identifiable, Hashable {
    // Backend doesn’t expose asset id in response for now; we derive a stable id for UI.
    public var id: String { symbol }

    public let symbol: String
    public let totalQuantity: Double
    public let averagePrice: Double
    /// Giá đóng cửa gần nhất (VND) — null nếu backend không lấy được.
    public let closePrice: Double?
    /// Giá trị thị trường close = qty × closePrice (VND).
    public let marketValueClose: Double?
    /// Lãi/lỗ tạm tính (VND) theo close.
    public let unrealizedPnL: Double?
    /// Lãi/lỗ tạm tính (%) theo close.
    public let unrealizedPnLPct: Double?
    public let updatedAt: String?

    public init(
        symbol: String,
        totalQuantity: Double,
        averagePrice: Double,
        closePrice: Double? = nil,
        marketValueClose: Double? = nil,
        unrealizedPnL: Double? = nil,
        unrealizedPnLPct: Double? = nil,
        updatedAt: String? = nil
    ) {
        self.symbol = symbol
        self.totalQuantity = totalQuantity
        self.averagePrice = averagePrice
        self.closePrice = closePrice
        self.marketValueClose = marketValueClose
        self.unrealizedPnL = unrealizedPnL
        self.unrealizedPnLPct = unrealizedPnLPct
        self.updatedAt = updatedAt
    }
}

public struct CreatePortfolioAssetRequest: Codable, Sendable {
    public let symbol: String
    public let quantity: Double
    public let averagePrice: Double

    public init(symbol: String, quantity: Double, averagePrice: Double) {
        self.symbol = symbol
        self.quantity = quantity
        self.averagePrice = averagePrice
    }
}

// MARK: - Trade / Cash Transactions (TradeTransaction-based)

public enum TradeType: String, Codable, Sendable, Hashable {
    case BUY
    case SELL
    case DIVIDEND
    case DEPOSIT
    case WITHDRAW
}

public struct CreateTradeTransactionRequest: Codable, Sendable {
    public let tradeType: TradeType

    // BUY/SELL/DIVIDEND
    public let symbol: String?
    public let quantity: Double?
    public let price: Double?

    // DEPOSIT/WITHDRAW
    public let amount: Double?

    // percent fields: e.g. 0.1 means 0.1%
    public let feePercent: Double?
    public let taxPercent: Double?

    // ISO8601
    public let transactionDate: String?

    public init(
        tradeType: TradeType,
        symbol: String? = nil,
        quantity: Double? = nil,
        price: Double? = nil,
        amount: Double? = nil,
        feePercent: Double? = nil,
        taxPercent: Double? = nil,
        transactionDate: String? = nil
    ) {
        self.tradeType = tradeType
        self.symbol = symbol
        self.quantity = quantity
        self.price = price
        self.amount = amount
        self.feePercent = feePercent
        self.taxPercent = taxPercent
        self.transactionDate = transactionDate
    }
}

// MARK: - Import Portfolio Snapshot

public struct ImportPortfolioSnapshotRequest: Codable, Sendable {
    public let cashBalance: Double
    public let holdings: [HoldingSnapshotRequest]?

    public init(cashBalance: Double, holdings: [HoldingSnapshotRequest]? = nil) {
        self.cashBalance = cashBalance
        self.holdings = holdings
    }

    public struct HoldingSnapshotRequest: Codable, Sendable {
        public let symbol: String
        public let totalQuantity: Double
        public let averagePrice: Double

        public init(symbol: String, totalQuantity: Double, averagePrice: Double) {
            self.symbol = symbol
            self.totalQuantity = totalQuantity
            self.averagePrice = averagePrice
        }
    }
}

// MARK: - Portfolio Health DTOs

/// GET /api/investments/portfolios/{id}/health
public struct PortfolioHealthResponse: Codable, Sendable {
    public let latestYear: Int
    public let latestQuarter: Int
    public let current: PortfolioHealthCurrent
    public let history: [PortfolioHealthPoint]

    public init(latestYear: Int, latestQuarter: Int, current: PortfolioHealthCurrent, history: [PortfolioHealthPoint]) {
        self.latestYear = latestYear
        self.latestQuarter = latestQuarter
        self.current = current
        self.history = history
    }
}

/// Snapshot tức thì theo giá đóng cửa gần nhất (market weight).
public struct PortfolioHealthCurrent: Codable, Sendable {
    /// "CLOSE" | "INSUFFICIENT"
    public let priceType: String
    public let totalValueClose: Double
    public let stockValueClose: Double
    public let cashBalance: Double
    /// null khi coverage < 50%
    public let pe: Double?
    public let pb: Double?
    public let ps: Double?

    public init(
        priceType: String,
        totalValueClose: Double,
        stockValueClose: Double,
        cashBalance: Double,
        pe: Double?,
        pb: Double?,
        ps: Double?
    ) {
        self.priceType = priceType
        self.totalValueClose = totalValueClose
        self.stockValueClose = stockValueClose
        self.cashBalance = cashBalance
        self.pe = pe
        self.pb = pb
        self.ps = ps
    }
}

/// Một điểm lịch sử theo quý (cost weight).
/// metric = nil khi coverage < 50% → FE vẽ đứt nét.
public struct PortfolioHealthPoint: Codable, Sendable, Identifiable {
    public var id: String { "\(year)-\(quarter)" }
    public let year: Int
    public let quarter: Int
    public let pe: Double?
    public let pb: Double?
    public let ps: Double?
    public let roe: Double?
    public let roa: Double?
    /// 0.0 – 1.0
    public let coverage: Double

    public init(year: Int, quarter: Int, pe: Double?, pb: Double?, ps: Double?, roe: Double?, roa: Double?, coverage: Double) {
        self.year = year
        self.quarter = quarter
        self.pe = pe
        self.pb = pb
        self.ps = ps
        self.roe = roe
        self.roa = roa
        self.coverage = coverage
    }
}

// MARK: - Trade Transaction History

/// Một giao dịch lịch sử từ GET /api/investments/portfolios/{id}/transactions
public struct TradeTransactionResponse: Codable, Sendable, Identifiable {
    public let id: String
    public let tradeType: TradeType
    public let symbol: String?
    public let quantity: Double?
    public let price: Double?
    public let totalAmount: Double
    public let feeAmount: Double
    public let taxAmount: Double
    public let transactionDate: String

    public init(
        id: String,
        tradeType: TradeType,
        symbol: String? = nil,
        quantity: Double? = nil,
        price: Double? = nil,
        totalAmount: Double,
        feeAmount: Double = 0,
        taxAmount: Double = 0,
        transactionDate: String
    ) {
        self.id = id
        self.tradeType = tradeType
        self.symbol = symbol
        self.quantity = quantity
        self.price = price
        self.totalAmount = totalAmount
        self.feeAmount = feeAmount
        self.taxAmount = taxAmount
        self.transactionDate = transactionDate
    }
}

// MARK: - Portfolio Vs Market Benchmark

public struct PortfolioMarketBenchmarkResponse: Codable, Sendable {
    public let benchmarkCode: String
    public let pe: PortfolioMetricComparison
    public let pb: PortfolioMetricComparison
    public let ps: PortfolioMetricComparison
    public let roe: PortfolioMetricComparison
    public let roa: PortfolioMetricComparison

    public init(
        benchmarkCode: String,
        pe: PortfolioMetricComparison,
        pb: PortfolioMetricComparison,
        ps: PortfolioMetricComparison,
        roe: PortfolioMetricComparison,
        roa: PortfolioMetricComparison
    ) {
        self.benchmarkCode = benchmarkCode
        self.pe = pe
        self.pb = pb
        self.ps = ps
        self.roe = roe
        self.roa = roa
    }
}

public struct PortfolioMetricComparison: Codable, Sendable {
    public let portfolio: Double?
    public let benchmark: Double?
    public let deltaPct: Double?

    public init(portfolio: Double?, benchmark: Double?, deltaPct: Double?) {
        self.portfolio = portfolio
        self.benchmark = benchmark
        self.deltaPct = deltaPct
    }
}
