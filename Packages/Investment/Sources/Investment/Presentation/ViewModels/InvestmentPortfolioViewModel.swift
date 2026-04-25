import Foundation
import FinFlowCore
import Observation

@MainActor
@Observable
public final class InvestmentPortfolioViewModel {
    public var portfolios: [PortfolioResponse] = []
    public var assets: [PortfolioAssetResponse] = []
    public var selectedPortfolio: PortfolioResponse?
    public var industryBySymbol: [String: String] = [:]
    public var portfolioHealth: PortfolioHealthResponse?
    public var portfolioBenchmark: PortfolioMarketBenchmarkResponse?

    /// True while the initial (or empty-list) portfolio fetch is in flight — avoids showing empty state before the first response.
    public var isLoadingPortfolios = true
    public var isLoadingSelectedPortfolioDetails = false

    public var errorAlert: AppErrorAlert?

    private let getCompanyIndustriesUseCase: GetCompanyIndustriesUseCase
    private let getPortfoliosUseCase: GetPortfoliosUseCase
    private let getPortfolioAssetsUseCase: GetPortfolioAssetsUseCase
    private let createPortfolioUseCase: CreatePortfolioUseCase
    private let createTradeTransactionUseCase: CreateTradeTransactionUseCase
    private let importPortfolioSnapshotUseCase: ImportPortfolioSnapshotUseCase
    private let getPortfolioHealthUseCase: GetPortfolioHealthUseCase
    private let getPortfolioVsMarketUseCase: GetPortfolioVsMarketUseCase

    private let sessionManager: any SessionManagerProtocol
    private var latestPortfolioLoadRequestID = UUID()
    private var loadedPortfolioDetailsID: String?

    public init(
        getCompanyIndustriesUseCase: GetCompanyIndustriesUseCase,
        getPortfoliosUseCase: GetPortfoliosUseCase,
        getPortfolioAssetsUseCase: GetPortfolioAssetsUseCase,
        createPortfolioUseCase: CreatePortfolioUseCase,
        createTradeTransactionUseCase: CreateTradeTransactionUseCase,
        importPortfolioSnapshotUseCase: ImportPortfolioSnapshotUseCase,
        getPortfolioHealthUseCase: GetPortfolioHealthUseCase,
        getPortfolioVsMarketUseCase: GetPortfolioVsMarketUseCase,
        sessionManager: any SessionManagerProtocol
    ) {
        self.getCompanyIndustriesUseCase = getCompanyIndustriesUseCase
        self.getPortfoliosUseCase = getPortfoliosUseCase
        self.getPortfolioAssetsUseCase = getPortfolioAssetsUseCase
        self.createPortfolioUseCase = createPortfolioUseCase
        self.createTradeTransactionUseCase = createTradeTransactionUseCase
        self.importPortfolioSnapshotUseCase = importPortfolioSnapshotUseCase
        self.getPortfolioHealthUseCase = getPortfolioHealthUseCase
        self.getPortfolioVsMarketUseCase = getPortfolioVsMarketUseCase

        self.sessionManager = sessionManager
    }

    public func loadAll(force: Bool = false) async {
        Logger.info("loadAll start | force=\(force)", category: "Investment")
        let showPortfolioLoadingOverlay = portfolios.isEmpty
        let previousSelectedPortfolioID = selectedPortfolio?.id
        if showPortfolioLoadingOverlay {
            isLoadingPortfolios = true
        }
        defer {
            if showPortfolioLoadingOverlay {
                isLoadingPortfolios = false
            }
        }

        do {
            portfolios = try await getPortfoliosUseCase.execute()
            Logger.info("loadAll portfolios fetched | count=\(portfolios.count)", category: "Investment")
            if let current = selectedPortfolio, portfolios.contains(where: { $0.id == current.id }) {
                // keep selection
            } else {
                selectedPortfolio = portfolios.first
            }
            Logger.info(
                "loadAll selectedPortfolio after sync | id=\(selectedPortfolio?.id ?? "nil") name=\(selectedPortfolio?.name ?? "nil")",
                category: "Investment"
            )
            if selectedPortfolio?.id == previousSelectedPortfolioID {
                await loadAssetsForSelectedPortfolio()
            } else {
                Logger.debug(
                    "loadAll skip direct asset load | selection changed and will be handled by onChange",
                    category: "Investment"
                )
            }
        } catch {
            if error is CancellationError {
                Logger.debug("loadAll cancelled", category: "Investment")
                return
            }
            Logger.error("loadAll failed | error=\(error.localizedDescription)", category: "Investment")
            errorAlert = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi tải danh mục/tài sản")
        }
    }

    public func createPortfolio(name: String) async {
        do {
            _ = try await createPortfolioUseCase.execute(request: CreatePortfolioRequest(name: name))
            await loadAll(force: true)
        } catch {
            errorAlert = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi tạo danh mục")
        }
    }

    public func loadAssetsForSelectedPortfolio() async {
        guard let selectedPortfolio else {
            Logger.info("loadAssetsForSelectedPortfolio skipped | no selected portfolio", category: "Investment")
            assets = []
            portfolioHealth = nil
            portfolioBenchmark = nil
            await recomputeAllPortfoliosTotalValue()
            return
        }
        Logger.info(
            "loadAssetsForSelectedPortfolio start | id=\(selectedPortfolio.id) name=\(selectedPortfolio.name)",
            category: "Investment"
        )
        let requestID = UUID()
        latestPortfolioLoadRequestID = requestID
        let selectedPortfolioID = selectedPortfolio.id
        isLoadingSelectedPortfolioDetails = true
        loadedPortfolioDetailsID = nil
        do {
            let fetchedAssets = try await getPortfolioAssetsUseCase.execute(portfolioId: selectedPortfolioID)
            guard requestID == latestPortfolioLoadRequestID else {
                Logger.debug(
                    "loadAssetsForSelectedPortfolio ignored stale request after assets fetch | id=\(selectedPortfolioID)",
                    category: "Investment"
                )
                return
            }
            Logger.info("assets fetched | count=\(fetchedAssets.count)", category: "Investment")

            let fetchedHealth = try? await getPortfolioHealthUseCase.execute(
                portfolioId: selectedPortfolioID,
                quarters: 12
            )
            guard requestID == latestPortfolioLoadRequestID else {
                Logger.debug(
                    "loadAssetsForSelectedPortfolio ignored stale request after health fetch | id=\(selectedPortfolioID)",
                    category: "Investment"
                )
                return
            }
            Logger.info(
                "health fetched | totalClose=\(fetchedHealth?.current.totalValueClose ?? -1) stockClose=\(fetchedHealth?.current.stockValueClose ?? -1)",
                category: "Investment"
            )

            let fetchedBenchmark = try? await getPortfolioVsMarketUseCase.execute(
                portfolioId: selectedPortfolioID,
                code: "VNINDEX"
            )
            guard requestID == latestPortfolioLoadRequestID else {
                Logger.debug(
                    "loadAssetsForSelectedPortfolio ignored stale request after benchmark fetch | id=\(selectedPortfolioID)",
                    category: "Investment"
                )
                return
            }
            Logger.info(
                "benchmark fetched | available=\(fetchedBenchmark != nil)",
                category: "Investment"
            )

            assets = fetchedAssets
            portfolioHealth = fetchedHealth
            portfolioBenchmark = fetchedBenchmark
            loadedPortfolioDetailsID = selectedPortfolioID

            await prefetchIndustries(for: fetchedAssets)
            guard requestID == latestPortfolioLoadRequestID else {
                Logger.debug(
                    "loadAssetsForSelectedPortfolio ignored stale request before recompute | id=\(selectedPortfolioID)",
                    category: "Investment"
                )
                return
            }
            await recomputeAllPortfoliosTotalValue()
            Logger.info(
                "portfolio computed | market=\(selectedPortfolioMarketValue) cost=\(portfolioCostBasis) pnl=\(unrealizedPnLValue) pnlPct=\(unrealizedPnLPct ?? -1)",
                category: "Investment"
            )
            isLoadingSelectedPortfolioDetails = false
        } catch {
            if requestID == latestPortfolioLoadRequestID {
                isLoadingSelectedPortfolioDetails = false
            }
            if error is CancellationError {
                Logger.debug("loadAssetsForSelectedPortfolio cancelled", category: "Investment")
                return
            }
            Logger.error(
                "loadAssetsForSelectedPortfolio failed | selectedId=\(selectedPortfolio.id) error=\(error.localizedDescription)",
                category: "Investment"
            )
            errorAlert = error.toHandledAlert(sessionManager: sessionManager, defaultTitle: "Lỗi tải tài sản")
        }
    }

    /// Cộng giá trị từng danh mục (tiền mặt + cổ phiếu); gọi song song theo từng portfolio.
    private func recomputeAllPortfoliosTotalValue() async {
        allPortfoliosTotalValue = portfolios.reduce(0) { partial, portfolio in
            partial + (portfolio.totalCostBasis ?? portfolio.cashBalance)
        }
    }

    public func createCashTransaction(tradeType: TradeType, amount: Double, transactionDate: Date) async throws {
        guard let selectedPortfolio else { return }
        try await createTradeTransactionUseCase.executeCash(
            portfolioId: selectedPortfolio.id,
            tradeType: tradeType,
            amount: amount,
            transactionDate: transactionDate
        )
        await loadAll(force: true)
    }

    public func createStockTradeTransaction(
        tradeType: TradeType,
        symbol: String,
        quantity: Double,
        price: Double,
        feePercent: Double,
        transactionDate: Date
    ) async throws {
        guard let selectedPortfolio else { return }
        try await createTradeTransactionUseCase.executeStock(
            portfolioId: selectedPortfolio.id,
            tradeType: tradeType,
            symbol: symbol,
            quantity: quantity,
            price: price,
            feePercent: feePercent,
            taxPercent: tradeType == .SELL ? 0.1 : nil,
            transactionDate: transactionDate
        )
        await loadAll(force: true)
    }

    public func importPortfolioSnapshot(
        cashBalance: Double,
        holdings: [ImportPortfolioSnapshotRequest.HoldingSnapshotRequest],
        transactionDate: Date
    ) async throws {
        guard let selectedPortfolio else { return }
        _ = try await importPortfolioSnapshotUseCase.execute(
            portfolioId: selectedPortfolio.id,
            request: ImportPortfolioSnapshotRequest(cashBalance: cashBalance, holdings: holdings)
        )
        await loadAll(force: true)
    }

    public var sortedAssets: [PortfolioAssetResponse] {
        guard loadedPortfolioDetailsID == selectedPortfolio?.id else { return [] }
        return assets.sorted { ($0.totalQuantity * $0.averagePrice) > ($1.totalQuantity * $1.averagePrice) }
    }

    public var portfolioStockValue: Double {
        sortedAssets.reduce(0) { $0 + ($1.totalQuantity * $1.averagePrice) }
    }

    public var portfolioTotalValue: Double {
        (selectedPortfolio?.cashBalance ?? 0) + portfolioStockValue
    }

    /// Giá vốn danh mục = tiền mặt + giá vốn cổ phiếu.
    public var portfolioCostBasis: Double {
        portfolioTotalValue
    }

    /// Giá trị hiện tại theo market close của danh mục đang chọn.
    /// Fallback sang giá vốn nếu chưa có dữ liệu health.
    public var selectedPortfolioMarketValue: Double {
        guard loadedPortfolioDetailsID == selectedPortfolio?.id else {
            return portfolioTotalValue
        }
        if let closeValue = portfolioHealth?.current.totalValueClose, closeValue > 0 {
            return closeValue
        }
        return portfolioTotalValue
    }

    /// Lãi/lỗ tạm tính = Giá trị thị trường hiện tại - Giá vốn.
    public var unrealizedPnLValue: Double {
        selectedPortfolioMarketValue - portfolioCostBasis
    }

    public var unrealizedPnLPct: Double? {
        guard portfolioCostBasis > 0 else { return nil }
        return (unrealizedPnLValue / portfolioCostBasis) * 100
    }

    /// Tổng giá trị (tiền mặt + giá trị cổ phiếu theo giá vốn) của **mọi** danh mục — dùng cho hero tổng quan.
    public private(set) var allPortfoliosTotalValue: Double = 0

    public var assetAllocations: [(name: String, weight: Double)] {
        let total = portfolioStockValue
        guard total > 0 else { return [("Khác", 100)] }
        return sortedAssets.map { asset in
            let value = asset.totalQuantity * asset.averagePrice
            return (name: asset.symbol, weight: (value / total) * 100)
        }
    }

    public var industryAllocations: [(name: String, weight: Double)] {
        let total = portfolioStockValue
        guard total > 0 else { return [("Khác", 100)] }

        var grouped: [String: Double] = [:]
        for asset in sortedAssets {
            let industry = industryBySymbol[asset.symbol] ?? "Khác"
            let value = asset.totalQuantity * asset.averagePrice
            grouped[industry, default: 0] += value
        }

        return grouped
            .map { (name: $0.key, weight: ($0.value / total) * 100) }
            .sorted { $0.weight > $1.weight }
    }

    public var compactIndustryAllocations: [(name: String, weight: Double)] {
        compactAllocations(industryAllocations, maxItems: 6)
    }

    public var compactAssetAllocations: [(name: String, weight: Double)] {
        compactAllocations(assetAllocations, maxItems: 6)
    }

    private func prefetchIndustries(for assets: [PortfolioAssetResponse]) async {
        let symbols = Set(assets.map(\.symbol))
        let missingSymbols = symbols.filter { symbol in
            let label = industryBySymbol[symbol]?.trimmingCharacters(in: .whitespacesAndNewlines)
            return label == nil || label?.isEmpty == true
        }
        if missingSymbols.isEmpty { return }
        do {
            let responses = try await getCompanyIndustriesUseCase.execute(symbols: Array(missingSymbols))
            for response in responses {
                let label = response.industryLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                industryBySymbol[response.symbol] = label.isEmpty ? "Khác" : label
            }
            for symbol in missingSymbols where industryBySymbol[symbol] == nil {
                industryBySymbol[symbol] = "Khác"
            }
        } catch {
            for symbol in missingSymbols {
                industryBySymbol[symbol] = "Khác"
            }
        }
    }

    private func compactAllocations(
        _ allocations: [(name: String, weight: Double)],
        maxItems: Int
    ) -> [(name: String, weight: Double)] {
        guard allocations.count > maxItems else { return allocations }
        let head = Array(allocations.prefix(maxItems - 1))
        let tail = allocations.dropFirst(maxItems - 1)
        let othersWeight = tail.reduce(0) { $0 + $1.weight }
        return head + [("Khác", othersWeight)]
    }
}
