import FinFlowCore
import Charts
import SwiftUI

public struct InvestmentView: View {
    @State private var selectedSegment = 0
    @State private var stockAnalysisVM: StockAnalysisViewModel
    @State private var portfolioVM: InvestmentPortfolioViewModel

    @State private var showCreatePortfolio = false
    @State private var showAddInvestmentActionSheet = false
    @State private var showAddCashTransactionSheet = false
    @State private var showAddStockTradeSheet = false
    @State private var showImportPortfolioSheet = false
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
                        PortfolioView(onAddPortfolio: { showCreatePortfolio = true })
                    } else {
                        portfolioAssetsContent(portfolioVM: portfolioVM)
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
                            showCreatePortfolio = true
                        } else {
                            showAddInvestmentActionSheet = true
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
        .sheet(isPresented: $showCreatePortfolio) {
            CreatePortfolioSheet { name in
                await portfolioVM.createPortfolio(name: name)
                showCreatePortfolio = false
            }
        }
        .sheet(isPresented: $showAddInvestmentActionSheet) {
            AddInvestmentActionSheet(
                onCashTransaction: {
                    showAddCashTransactionSheet = true
                },
                onStockTrade: {
                    showAddStockTradeSheet = true
                },
                onImportPortfolio: {
                    showImportPortfolioSheet = true
                }
            )
        }
        .sheet(isPresented: $showAddCashTransactionSheet) {
            if portfolioVM.selectedPortfolio != nil {
                AddCashTransactionSheet { tradeType, amount, date in
                    try await portfolioVM.createCashTransaction(tradeType: tradeType, amount: amount, transactionDate: date)
                }
            }
        }
        .sheet(isPresented: $showAddStockTradeSheet) {
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
        }
        .sheet(isPresented: $showImportPortfolioSheet) {
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

    @ViewBuilder
    private func portfolioAssetsContent(portfolioVM: InvestmentPortfolioViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.md) {
                Menu {
                    ForEach(portfolioVM.portfolios) { portfolio in
                        Button {
                            portfolioVM.selectedPortfolio = portfolio
                        } label: {
                            HStack {
                                Text(portfolio.name)
                                if portfolioVM.selectedPortfolio?.id == portfolio.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    Divider()

                    Button {
                        showCreatePortfolio = true
                    } label: {
                        Label("Tạo danh mục mới", systemImage: "plus")
                    }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Text(portfolioVM.selectedPortfolio?.name ?? "Danh mục")
                            .font(AppTypography.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(AppColors.settingsCardBackground)
                    .cornerRadius(CornerRadius.medium)
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.plain)
                .padding(.top, Spacing.sm)

                if portfolioVM.selectedPortfolio != nil {
                    FinancialHeroCard(
                        title: "Tổng giá trị danh mục",
                        mainAmount: CurrencyFormatter.format(portfolioVM.selectedPortfolioMarketValue),
                        subtitle: "Theo danh mục đang mở"
                    ) {
                        portfolioSummaryStats(portfolioVM: portfolioVM)
                    }
                }

                if portfolioVM.isLoadingSelectedPortfolioDetails {
                    VStack(spacing: Spacing.sm) {
                        ProgressView()
                        Text("Đang tải dữ liệu danh mục...")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.lg)
                } else if portfolioVM.assets.isEmpty {
                    EmptyStateView(
                        icon: "tray",
                        title: "Chưa có tài sản nào",
                        subtitle: "Thêm tài sản để bắt đầu theo dõi và giao dịch trong danh mục.",
                        buttonTitle: "Thêm tài sản",
                        action: { showAddInvestmentActionSheet = true }
                    )
                    .padding(.top, Spacing.lg)
                } else {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Cơ cấu danh mục")
                            .font(AppTypography.displayCaption)
                            .foregroundStyle(.primary)

                        VStack(spacing: Spacing.md) {
                            allocationDonutCard(
                                title: "Tỷ trọng theo ngành",
                                allocations: portfolioVM.compactIndustryAllocations
                            )

                            allocationDonutCard(
                                title: "Tỷ trọng theo cổ phiếu",
                                allocations: portfolioVM.compactAssetAllocations
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Danh sách mã nắm giữ")
                            .font(AppTypography.displayCaption)
                            .foregroundStyle(.primary)

                        VStack(spacing: Spacing.sm) {
                            ForEach(portfolioVM.sortedAssets, id: \.symbol) { asset in
                                Button {
                                    selectedAssetForDetail = asset
                                } label: {
                                    let marketValue = asset.marketValueClose ?? (asset.totalQuantity * asset.averagePrice)
                                    let pnlValue = asset.unrealizedPnL ?? 0
                                    let pnlPct = asset.unrealizedPnLPct
                                    let pnlColor: Color = pnlValue >= 0 ? AppColors.chartGrowthStrong : AppColors.error

                                    IconTitleTrailingRow(
                                        icon: "chart.line.uptrend.xyaxis",
                                        color: colorForSymbol(asset.symbol),
                                        title: asset.symbol,
                                        subtitle:
                                            "KL \(portfolioVM.formatQuantity(asset.totalQuantity)) • Giá vốn \(CurrencyFormatter.format(asset.averagePrice)) • Giá hiện tại \(CurrencyFormatter.format(asset.closePrice ?? 0))"
                                    ) {
                                        VStack(alignment: .trailing, spacing: Spacing.xs) {
                                            Text(CurrencyFormatter.format(marketValue))
                                                .font(AppTypography.headline)
                                                .foregroundStyle(.primary)
                                            if let pct = pnlPct {
                                                Text(String(format: "%@%@ (%@%.2f%%)",
                                                            pnlValue >= 0 ? "+" : "",
                                                            CurrencyFormatter.format(pnlValue),
                                                            pct >= 0 ? "+" : "",
                                                            pct))
                                                    .font(AppTypography.caption)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(pnlColor)
                                            } else {
                                                Text("Lãi/Lỗ: —")
                                                    .font(AppTypography.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)

                                if asset.symbol != portfolioVM.sortedAssets.last?.symbol {
                                    Divider()
                                }
                            }
                        }
                        .padding(Spacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(CornerRadius.medium)
                    }
                }

                if let portfolioHealth = portfolioVM.portfolioHealth {
                    if let portfolioBenchmark = portfolioVM.portfolioBenchmark {
                        PortfolioBenchmarkCards(benchmark: portfolioBenchmark)
                            .padding(.top, Spacing.sm)
                    } else {
                        PortfolioHealthCard(health: portfolioHealth)
                            .padding(.top, Spacing.sm)
                    }
                }

                if portfolioVM.selectedPortfolio != nil {
                    navVsIndexPerformanceCard(portfolioVM: portfolioVM)
                        .padding(.top, Spacing.md)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .background(AppColors.appBackground)
    }

    private func navVsIndexPerformanceCard(portfolioVM: InvestmentPortfolioViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Hiệu suất vs \(portfolioVM.portfolioPerformance?.benchmarkCode ?? "VNINDEX")")
                    .font(AppTypography.displayCaption)
                    .foregroundStyle(.primary)
                Spacer()
                Picker(
                    "Kỳ",
                    selection: Binding(
                        get: { portfolioVM.performanceRange },
                        set: { portfolioVM.performanceRange = $0 }
                    )
                ) {
                    Text("1T").tag("1M")
                    Text("3T").tag("3M")
                    Text("6T").tag("6M")
                    Text("1N").tag("1Y")
                    Text("YTD").tag("YTD")
                    Text("Tối đa").tag("MAX")
                }
                .pickerStyle(.menu)
                .tint(AppColors.primary)
            }

            if let perf = portfolioVM.portfolioPerformance {
                let hasPortfolio = perf.portfolioPoints.contains { $0.returnPct != nil }
                let hasBench = perf.benchmarkPoints.contains { $0.returnPct != nil }
                if hasPortfolio || hasBench {
                    Chart {
                        ForEach(perf.portfolioPoints, id: \.date) { pt in
                            if let rp = pt.returnPct {
                                LineMark(
                                    x: .value("Ngày", portfolioVM.performanceChartDay(pt.date)),
                                    y: .value("%", rp)
                                )
                                .foregroundStyle(AppColors.primary)
                                .interpolationMethod(.catmullRom)
                            }
                        }
                        ForEach(perf.benchmarkPoints, id: \.date) { pt in
                            if let rp = pt.returnPct {
                                LineMark(
                                    x: .value("Ngày", portfolioVM.performanceChartDay(pt.date)),
                                    y: .value("%", rp)
                                )
                                .foregroundStyle(Color.orange)
                                .interpolationMethod(.catmullRom)
                            }
                        }
                    }
                    .chartYAxisLabel("% so với điểm đầu kỳ")
                    .frame(height: 200)
                    .padding(.top, Spacing.xs)

                    HStack(spacing: Spacing.md) {
                        HStack(spacing: AppSpacing.xs) {
                            Circle()
                                .fill(AppColors.primary)
                                .frame(width: AppSpacing.xs, height: AppSpacing.xs)
                            Text("Danh mục")
                                .font(AppTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: AppSpacing.xs) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: AppSpacing.xs, height: AppSpacing.xs)
                            Text(perf.benchmarkCode)
                                .font(AppTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("Biểu đồ sẽ có dữ liệu sau các phiên chốt NAV cuối ngày (so với chỉ số).")
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, Spacing.xs)
                }
            } else {
                Text("Biểu đồ sẽ có dữ liệu sau các phiên chốt NAV cuối ngày (so với chỉ số).")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, Spacing.xs)
            }
        }
        .padding(Spacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.medium)
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

    @ViewBuilder
    private func portfolioSummaryStats(portfolioVM: InvestmentPortfolioViewModel) -> some View {
        let pnlValue = portfolioVM.unrealizedPnLValue
        let pnlColor: Color = pnlValue >= 0 ? AppColors.chartGrowthStrong : AppColors.error
        let pnlPrefix = pnlValue >= 0 ? "+" : ""
        let pnlPctText: String = {
            guard let pct = portfolioVM.unrealizedPnLPct else { return "—" }
            return String(format: "%@%.2f%%", pct >= 0 ? "+" : "", pct)
        }()

        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Giá trị thị trường: \(CurrencyFormatter.format(portfolioVM.selectedPortfolioMarketValue))")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.textInverted.opacity(OpacityLevel.high))

            Text("Giá vốn danh mục: \(CurrencyFormatter.format(portfolioVM.portfolioCostBasis))")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.textInverted.opacity(OpacityLevel.high))

            Text("Lãi/Lỗ tạm tính: \(pnlPrefix)\(CurrencyFormatter.format(pnlValue)) (\(pnlPctText))")
                .font(AppTypography.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(pnlColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func allocationDonutCard(
        title: String,
        allocations: [(name: String, weight: Double)]
    ) -> some View {
        let slices = allocations.enumerated().map { idx, alloc -> ProportionDonutSlice in
            ProportionDonutSlice(
                id: alloc.name,
                name: alloc.name,
                percentage: alloc.weight,
                color: {
                    if alloc.name == "Khác" { return Color.gray.opacity(0.7) }
                    let palette: [Color] = [.teal, .purple, .orange, .pink, .indigo, .mint, .brown, .cyan, .red, .gray]
                    return palette[idx % palette.count]
                }()
            )
        }

        ProportionDonutChart(
            title: title,
            slices: slices
        )
        .padding(Spacing.lg)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }

    private func colorForSymbol(_ symbol: String) -> Color {
        let palette: [Color] = [
            AppColors.chartIncomeFee,
            AppColors.chartIncomeOther,
            AppColors.chartRevenue,
            AppColors.chartProfit,
            AppColors.chartAssetInterbank,
            AppColors.chartAssetReceivables,
            AppColors.chartAssetCash,
            AppColors.chartAssetShortTermInvestments,
        ]
        let hash = abs(symbol.hashValue)
        return palette[hash % palette.count]
    }
}
