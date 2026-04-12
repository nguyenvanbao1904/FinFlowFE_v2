import FinFlowCore
import Charts
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
    let createTradeTransactionUseCase: CreateTradeTransactionUseCase
    let importPortfolioSnapshotUseCase: ImportPortfolioSnapshotUseCase
    let getPortfolioHealthUseCase: GetPortfolioHealthUseCase
    let getPortfolioVsMarketUseCase: GetPortfolioVsMarketUseCase
    let sessionManager: any SessionManagerProtocol

    public init(
        getStockAnalysisUseCase: GetStockAnalysisUseCase,
        getCompanyIndustriesUseCase: GetCompanyIndustriesUseCase,
        suggestCompaniesUseCase: SuggestCompaniesUseCase,
        getPortfoliosUseCase: GetPortfoliosUseCase,
        getPortfolioAssetsUseCase: GetPortfolioAssetsUseCase,
        createPortfolioUseCase: CreatePortfolioUseCase,
        createTradeTransactionUseCase: CreateTradeTransactionUseCase,
        importPortfolioSnapshotUseCase: ImportPortfolioSnapshotUseCase,
        getPortfolioHealthUseCase: GetPortfolioHealthUseCase,
        getPortfolioVsMarketUseCase: GetPortfolioVsMarketUseCase,
        sessionManager: any SessionManagerProtocol
    ) {
        self.getStockAnalysisUseCase = getStockAnalysisUseCase
        self.getCompanyIndustriesUseCase = getCompanyIndustriesUseCase
        self.suggestCompaniesUseCase = suggestCompaniesUseCase
        self.getPortfoliosUseCase = getPortfoliosUseCase
        self.getPortfolioAssetsUseCase = getPortfolioAssetsUseCase
        self.createPortfolioUseCase = createPortfolioUseCase
        self.createTradeTransactionUseCase = createTradeTransactionUseCase
        self.importPortfolioSnapshotUseCase = importPortfolioSnapshotUseCase
        self.getPortfolioHealthUseCase = getPortfolioHealthUseCase
        self.getPortfolioVsMarketUseCase = getPortfolioVsMarketUseCase
        self.sessionManager = sessionManager
    }
}

public struct InvestmentView: View {
    private enum ActiveSheet: String, Identifiable {
        case createPortfolio
        case addInvestmentAction
        case addCashTransaction
        case addStockTrade
        case importPortfolio

        var id: String { rawValue }
    }

    @State private var selectedSegment = 0
    @State private var stockAnalysisVM: StockAnalysisViewModel
    @State private var portfolioVM: InvestmentPortfolioViewModel

    @State private var activeSheet: ActiveSheet?
    @State private var selectedAssetForDetail: PortfolioAssetResponse? = nil

    private let suggestCompaniesUseCase: SuggestCompaniesUseCase

    public init(dependencies: InvestmentViewDependencies) {
        self.suggestCompaniesUseCase = dependencies.suggestCompaniesUseCase

        _stockAnalysisVM = State(
            initialValue: StockAnalysisViewModel(
                getStockAnalysisUseCase: dependencies.getStockAnalysisUseCase,
                sessionManager: dependencies.sessionManager
            )
        )
        _portfolioVM = State(
            initialValue: InvestmentPortfolioViewModel(
                getCompanyIndustriesUseCase: dependencies.getCompanyIndustriesUseCase,
                getPortfoliosUseCase: dependencies.getPortfoliosUseCase,
                getPortfolioAssetsUseCase: dependencies.getPortfolioAssetsUseCase,
                createPortfolioUseCase: dependencies.createPortfolioUseCase,
                createTradeTransactionUseCase: dependencies.createTradeTransactionUseCase,
                importPortfolioSnapshotUseCase: dependencies.importPortfolioSnapshotUseCase,
                getPortfolioHealthUseCase: dependencies.getPortfolioHealthUseCase,
                getPortfolioVsMarketUseCase: dependencies.getPortfolioVsMarketUseCase,
                sessionManager: dependencies.sessionManager
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
                selectedAssetForDetail: $selectedAssetForDetail
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
                activeSheet = nil
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
