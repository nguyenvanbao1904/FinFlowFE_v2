import FinFlowCore
import SwiftUI

/// Groups the use-cases and session dependency for `InvestmentView`.
/// Using a struct keeps the view initializer lean and avoids long argument lists.
public struct InvestmentViewDependencies {
    let getStockAnalysisUseCase: GetStockAnalysisUseCase
    let getCompanyIndustriesUseCase: GetCompanyIndustriesUseCase
    let suggestCompaniesUseCase: SuggestCompaniesUseCase
    let getPortfoliosUseCase: GetPortfoliosUseCase
    let getPortfolioAssetsUseCase: GetPortfolioAssetsUseCase
    let createPortfolioUseCase: CreatePortfolioUseCase
    let updatePortfolioUseCase: UpdatePortfolioUseCase
    let deletePortfolioUseCase: DeletePortfolioUseCase
    let createTradeTransactionUseCase: CreateTradeTransactionUseCase
    let importPortfolioSnapshotUseCase: ImportPortfolioSnapshotUseCase
    let getPortfolioHealthUseCase: GetPortfolioHealthUseCase
    let getPortfolioVsMarketUseCase: GetPortfolioVsMarketUseCase
    let getTradeTransactionsUseCase: GetTradeTransactionsUseCase
    let sessionManager: any SessionManagerProtocol
    /// Closure trả về tổng tài sản ròng từ Wealth module (live value mỗi lần đọc).
    let netWorthProvider: @MainActor () -> Double
    /// Tổng tài sản thanh khoản (tài khoản nhóm LIQUID) — dùng cho FSI survival runway.
    let liquidAssetsProvider: @MainActor () -> Double
    /// Chi tiêu trung bình hàng tháng — dùng cho FSI survival runway.
    let monthlyExpensesProvider: @MainActor () -> Double
    /// Mua ròng cổ phiếu tháng này — dùng cho FSI invest ratio.
    let monthlyNetBuyProvider: @MainActor () -> Double
    /// Thu nhập thặng dư tháng này (thu nhập - chi tiêu) — dùng cho FSI invest ratio.
    let monthlySurplusProvider: @MainActor () -> Double

    public init(
        getStockAnalysisUseCase: GetStockAnalysisUseCase,
        getCompanyIndustriesUseCase: GetCompanyIndustriesUseCase,
        suggestCompaniesUseCase: SuggestCompaniesUseCase,
        getPortfoliosUseCase: GetPortfoliosUseCase,
        getPortfolioAssetsUseCase: GetPortfolioAssetsUseCase,
        createPortfolioUseCase: CreatePortfolioUseCase,
        updatePortfolioUseCase: UpdatePortfolioUseCase,
        deletePortfolioUseCase: DeletePortfolioUseCase,
        createTradeTransactionUseCase: CreateTradeTransactionUseCase,
        importPortfolioSnapshotUseCase: ImportPortfolioSnapshotUseCase,
        getPortfolioHealthUseCase: GetPortfolioHealthUseCase,
        getPortfolioVsMarketUseCase: GetPortfolioVsMarketUseCase,
        getTradeTransactionsUseCase: GetTradeTransactionsUseCase,
        sessionManager: any SessionManagerProtocol,
        netWorthProvider: @escaping @MainActor () -> Double = { 0 },
        liquidAssetsProvider: @escaping @MainActor () -> Double = { 0 },
        monthlyExpensesProvider: @escaping @MainActor () -> Double = { 0 },
        monthlyNetBuyProvider: @escaping @MainActor () -> Double = { 0 },
        monthlySurplusProvider: @escaping @MainActor () -> Double = { 0 }
    ) {
        self.getStockAnalysisUseCase = getStockAnalysisUseCase
        self.getCompanyIndustriesUseCase = getCompanyIndustriesUseCase
        self.suggestCompaniesUseCase = suggestCompaniesUseCase
        self.getPortfoliosUseCase = getPortfoliosUseCase
        self.getPortfolioAssetsUseCase = getPortfolioAssetsUseCase
        self.createPortfolioUseCase = createPortfolioUseCase
        self.updatePortfolioUseCase = updatePortfolioUseCase
        self.deletePortfolioUseCase = deletePortfolioUseCase
        self.createTradeTransactionUseCase = createTradeTransactionUseCase
        self.importPortfolioSnapshotUseCase = importPortfolioSnapshotUseCase
        self.getPortfolioHealthUseCase = getPortfolioHealthUseCase
        self.getPortfolioVsMarketUseCase = getPortfolioVsMarketUseCase
        self.getTradeTransactionsUseCase = getTradeTransactionsUseCase
        self.sessionManager = sessionManager
        self.netWorthProvider = netWorthProvider
        self.liquidAssetsProvider = liquidAssetsProvider
        self.monthlyExpensesProvider = monthlyExpensesProvider
        self.monthlyNetBuyProvider = monthlyNetBuyProvider
        self.monthlySurplusProvider = monthlySurplusProvider
    }
}

public struct InvestmentView: View {
    public var onAskAI: ((String) -> Void)?

    private enum ActiveSheet: String, Identifiable {
        case createPortfolio
        case renamePortfolio
        case addInvestmentAction
        case addCashTransaction
        case addStockTrade
        case importPortfolio
        case tradeHistory

        var id: String { rawValue }
    }

    @State private var selectedSegment = 0
    @State private var stockAnalysisVM: StockAnalysisViewModel
    @State private var portfolioVM: InvestmentPortfolioViewModel

    @State private var activeSheet: ActiveSheet?
    @State private var selectedAssetForDetail: PortfolioAssetResponse?
    @State private var showDeletePortfolioConfirm = false

    private let suggestCompaniesUseCase: SuggestCompaniesUseCase

    public init(dependencies: InvestmentViewDependencies) {
        self.suggestCompaniesUseCase = dependencies.suggestCompaniesUseCase

        let portfolioVM = InvestmentPortfolioViewModel(
            getCompanyIndustriesUseCase: dependencies.getCompanyIndustriesUseCase,
            getPortfoliosUseCase: dependencies.getPortfoliosUseCase,
            getPortfolioAssetsUseCase: dependencies.getPortfolioAssetsUseCase,
            createPortfolioUseCase: dependencies.createPortfolioUseCase,
            updatePortfolioUseCase: dependencies.updatePortfolioUseCase,
            deletePortfolioUseCase: dependencies.deletePortfolioUseCase,
            createTradeTransactionUseCase: dependencies.createTradeTransactionUseCase,
            importPortfolioSnapshotUseCase: dependencies.importPortfolioSnapshotUseCase,
            getPortfolioHealthUseCase: dependencies.getPortfolioHealthUseCase,
            getPortfolioVsMarketUseCase: dependencies.getPortfolioVsMarketUseCase,
            getTradeTransactionsUseCase: dependencies.getTradeTransactionsUseCase,
            sessionManager: dependencies.sessionManager
        )
        portfolioVM.liquidAssetsProvider = dependencies.liquidAssetsProvider
        portfolioVM.monthlyExpensesProvider = dependencies.monthlyExpensesProvider
        portfolioVM.monthlyNetBuyProvider = dependencies.monthlyNetBuyProvider
        portfolioVM.monthlySurplusProvider = dependencies.monthlySurplusProvider
        _portfolioVM = State(initialValue: portfolioVM)

        let netWorthProvider = dependencies.netWorthProvider
        _stockAnalysisVM = State(
            initialValue: StockAnalysisViewModel(
                getStockAnalysisUseCase: dependencies.getStockAnalysisUseCase,
                sessionManager: dependencies.sessionManager,
                netWorthProvider: netWorthProvider,
                portfolioValueProvider: { portfolioVM.portfolioTotalValue }
            )
        )
    }

    public var body: some View {
        @Bindable var bindablePortfolioVM = portfolioVM

        mainContent
            .navigationTitle("Đầu tư")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { portfolioToolbar }
            .alertHandler($bindablePortfolioVM.errorAlert)
            .sheet(item: $activeSheet) { sheet in
                sheetContent(for: sheet)
            }
            .sheet(item: $selectedAssetForDetail) { asset in
                PortfolioAssetDetailSheet(
                    asset: asset,
                    portfolioStockValue: portfolioVM.portfolioStockValue
                )
            }
            .alert("Xóa danh mục?", isPresented: $showDeletePortfolioConfirm) {
                Button("Xóa", role: .destructive) {
                    Task { await portfolioVM.deletePortfolio() }
                }
                Button("Hủy", role: .cancel) {}
            } message: {
                Text("Toàn bộ tài sản và giao dịch trong danh mục sẽ bị xóa vĩnh viễn.")
            }
            .task { await portfolioVM.loadAll() }
            .refreshable { await portfolioVM.loadAll(force: true) }
            .onChange(of: portfolioVM.selectedPortfolio?.id) { _, _ in
                Task { @MainActor in await portfolioVM.loadAssetsForSelectedPortfolio() }
            }
    }

    private var mainContent: some View {
        VStack(spacing: .zero) {
            segmentPicker

            TabView(selection: $selectedSegment) {
                portfolioTab.tag(0)
                StockAnalysisView(viewModel: stockAnalysisVM).tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: selectedSegment)
            .background(AppColors.appBackground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.appBackground)
    }

    @ViewBuilder
    private var portfolioTab: some View {
        if portfolioVM.isLoadingPortfolios {
            portfolioListLoadingView
        } else if portfolioVM.portfolios.isEmpty {
            PortfolioView(onAddPortfolio: { activeSheet = .createPortfolio })
        } else {
            InvestmentPortfolioTabContent(
                viewModel: portfolioVM,
                showCreatePortfolio: Binding(
                    get: { activeSheet == .createPortfolio },
                    set: { activeSheet = $0 ? .createPortfolio : nil }
                ),
                showAddInvestmentActionSheet: Binding(
                    get: { activeSheet == .addInvestmentAction },
                    set: { activeSheet = $0 ? .addInvestmentAction : nil }
                ),
                selectedAssetForDetail: $selectedAssetForDetail,
                onRenamePortfolio: { activeSheet = .renamePortfolio },
                onDeletePortfolio: { showDeletePortfolioConfirm = true },
                onShowHistory: {
                    Task { @MainActor in await portfolioVM.loadTradeTransactions(reset: true) }
                    activeSheet = .tradeHistory
                },
                onAskAI: onAskAI
            )
        }
    }

    @ToolbarContentBuilder
    private var portfolioToolbar: some ToolbarContent {
        if selectedSegment == 0, !portfolioVM.isLoadingPortfolios {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    activeSheet = portfolioVM.portfolios.isEmpty
                        ? .createPortfolio : .addInvestmentAction
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.primary)
                }
                .accessibilityLabel(
                    portfolioVM.portfolios.isEmpty ? "Tạo danh mục đầu tư" : "Thêm tài sản")
            }
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .createPortfolio:
            CreatePortfolioSheet { name in
                await portfolioVM.createPortfolio(name: name)
                await MainActor.run { activeSheet = nil }
            }
        case .renamePortfolio:
            RenamePortfolioSheet(currentName: portfolioVM.selectedPortfolio?.name ?? "") { newName in
                await portfolioVM.updatePortfolio(name: newName)
                await MainActor.run { activeSheet = nil }
            }
        case .addInvestmentAction:
            AddInvestmentActionSheet(
                onCashTransaction: { activeSheet = .addCashTransaction },
                onStockTrade: { activeSheet = .addStockTrade },
                onImportPortfolio: { activeSheet = .importPortfolio }
            )
        case .addCashTransaction:
            if portfolioVM.selectedPortfolio != nil {
                AddCashTransactionSheet { tradeType, amount, date in
                    try await portfolioVM.createCashTransaction(
                        tradeType: tradeType, amount: amount, transactionDate: date)
                }
            }
        case .addStockTrade:
            if portfolioVM.selectedPortfolio != nil {
                AddStockTradeSheet(
                    assets: portfolioVM.sortedAssets,
                    onSuggest: { query in
                        try await suggestCompaniesUseCase.execute(query: query, limit: 10)
                    },
                    onSubmit: { tradeType, symbol, quantity, price, feePercent, date in
                        try await portfolioVM.createStockTradeTransaction(
                            tradeType: tradeType, symbol: symbol, quantity: quantity,
                            price: price, feePercent: feePercent, transactionDate: date)
                    }
                )
            }
        case .importPortfolio:
            if portfolioVM.selectedPortfolio != nil {
                ImportPortfolioSnapshotSheet(
                    onSuggest: { query in
                        try await suggestCompaniesUseCase.execute(query: query, limit: 10)
                    },
                    onSubmit: { cashBalance, holdings, date in
                        try await portfolioVM.importPortfolioSnapshot(
                            cashBalance: cashBalance, holdings: holdings, transactionDate: date)
                    }
                )
            }
        case .tradeHistory:
            if let portfolio = portfolioVM.selectedPortfolio {
                TradeTransactionHistorySheet(
                    portfolioName: portfolio.name,
                    viewModel: portfolioVM
                )
            }
        }
    }

    private var portfolioListLoadingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Đang tải danh mục...")
                .font(AppTypography.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, Spacing.xl * 2)
    }

    private var segmentPicker: some View {
        Picker("Phân loại", selection: $selectedSegment) {
            Text("Danh mục").tag(0)
            Text("Phân tích cổ phiếu").tag(1)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.bottom, Spacing.sm)
        .background(AppColors.settingsCardBackground)
    }

}
