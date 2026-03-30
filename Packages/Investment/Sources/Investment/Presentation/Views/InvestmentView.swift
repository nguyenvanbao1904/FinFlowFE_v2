import FinFlowCore
import Charts
import SwiftUI

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
        getPortfolioPerformanceUseCase: GetPortfolioPerformanceUseCase,
        sessionManager: any SessionManagerProtocol
    ) {
        self.suggestCompaniesUseCase = suggestCompaniesUseCase

        _stockAnalysisVM = State(
            initialValue: StockAnalysisViewModel(
                getStockAnalysisUseCase: getStockAnalysisUseCase,
                sessionManager: sessionManager
            )
        )
        _portfolioVM = State(
            initialValue: InvestmentPortfolioViewModel(
                getCompanyIndustriesUseCase: getCompanyIndustriesUseCase,
                getPortfoliosUseCase: getPortfoliosUseCase,
                getPortfolioAssetsUseCase: getPortfolioAssetsUseCase,
                createPortfolioUseCase: createPortfolioUseCase,
                createTradeTransactionUseCase: createTradeTransactionUseCase,
                importPortfolioSnapshotUseCase: importPortfolioSnapshotUseCase,
                getPortfolioHealthUseCase: getPortfolioHealthUseCase,
                getPortfolioVsMarketUseCase: getPortfolioVsMarketUseCase,
                getPortfolioPerformanceUseCase: getPortfolioPerformanceUseCase,
                sessionManager: sessionManager
            )
        )
    }

    public var body: some View {
        @Bindable var portfolioVM = portfolioVM

        VStack(spacing: .zero) {
            segmentPicker

            TabView(selection: $selectedSegment) {
                Group {
                    if portfolioVM.isLoadingPortfolios {
                        portfolioListLoadingView
                    } else if portfolioVM.portfolios.isEmpty {
                        PortfolioView(onAddPortfolio: { activeSheet = .createPortfolio })
                    } else {
                        InvestmentPortfolioTabContent(
                            viewModel: portfolioVM,
                            showCreatePortfolio: Binding(
                                get: { activeSheet == .createPortfolio },
                                set: { isPresented in
                                    activeSheet = isPresented ? .createPortfolio : nil
                                }
                            ),
                            showAddInvestmentActionSheet: Binding(
                                get: { activeSheet == .addInvestmentAction },
                                set: { isPresented in
                                    activeSheet = isPresented ? .addInvestmentAction : nil
                                }
                            ),
                            selectedAssetForDetail: $selectedAssetForDetail
                        )
                    }
                }
                .tag(0)

                StockAnalysisView(viewModel: stockAnalysisVM)
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: selectedSegment)
        }
        .background(AppColors.appBackground)
        .navigationTitle("Đầu tư")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if selectedSegment == 0, !portfolioVM.isLoadingPortfolios {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if portfolioVM.portfolios.isEmpty {
                            activeSheet = .createPortfolio
                        } else {
                            activeSheet = .addInvestmentAction
                        }
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.primary)
                    }
                    .accessibilityLabel(portfolioVM.portfolios.isEmpty ? "Tạo danh mục đầu tư" : "Thêm tài sản")
                }
            }
        }
        .alertHandler($portfolioVM.errorAlert)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .createPortfolio:
                CreatePortfolioSheet { name in
                    await portfolioVM.createPortfolio(name: name)
                    activeSheet = nil
                }
            case .addInvestmentAction:
                AddInvestmentActionSheet(
                    onCashTransaction: {
                        activeSheet = .addCashTransaction
                    },
                    onStockTrade: {
                        activeSheet = .addStockTrade
                    },
                    onImportPortfolio: {
                        activeSheet = .importPortfolio
                    }
                )
            case .addCashTransaction:
                if portfolioVM.selectedPortfolio != nil {
                    AddCashTransactionSheet { tradeType, amount, date in
                        try await portfolioVM.createCashTransaction(tradeType: tradeType, amount: amount, transactionDate: date)
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
                                tradeType: tradeType,
                                symbol: symbol,
                                quantity: quantity,
                                price: price,
                                feePercent: feePercent,
                                transactionDate: date
                            )
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
                        try await portfolioVM.importPortfolioSnapshot(cashBalance: cashBalance, holdings: holdings, transactionDate: date)
                    }
                )
                }
            }
        }
        .sheet(item: $selectedAssetForDetail) { asset in
            PortfolioAssetDetailSheet(
                asset: asset,
                portfolioStockValue: portfolioVM.portfolioStockValue
            )
        }
        .task { await portfolioVM.loadAll() }
        .refreshable { await portfolioVM.loadAll(force: true) }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: Spacing.xl) }
        .onChange(of: portfolioVM.selectedPortfolio?.id) { _, _ in
            Task { @MainActor in
                await portfolioVM.loadAssetsForSelectedPortfolio()
            }
        }
        .onChange(of: portfolioVM.performanceRange) { _, _ in
            Task { @MainActor in
                await portfolioVM.loadPortfolioPerformance()
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
