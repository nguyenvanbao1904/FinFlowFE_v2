import Charts
import FinFlowCore
import SwiftUI

struct InvestmentPortfolioTabContent: View {
    let viewModel: InvestmentPortfolioViewModel
    @Binding var showCreatePortfolio: Bool
    @Binding var showAddInvestmentActionSheet: Bool
    @Binding var selectedAssetForDetail: PortfolioAssetResponse?

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.md) {
                Menu {
                    ForEach(viewModel.portfolios) { portfolio in
                        Button {
                            viewModel.selectedPortfolio = portfolio
                        } label: {
                            HStack {
                                Text(portfolio.name)
                                if viewModel.selectedPortfolio?.id == portfolio.id {
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
                        Text(viewModel.selectedPortfolio?.name ?? "Danh mục")
                            .font(AppTypography.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(AppColors.settingsCardBackground)
                    .clipShape(.rect(cornerRadius: CornerRadius.medium))
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.plain)
                .padding(.top, Spacing.sm)

                if viewModel.selectedPortfolio != nil {
                    FinancialHeroCard(
                        title: "Tổng giá trị danh mục",
                        mainAmount: CurrencyFormatter.format(viewModel.selectedPortfolioMarketValue),
                        subtitle: "Theo danh mục đang mở"
                    ) {
                        portfolioSummaryStats(viewModel: viewModel)
                    }
                }

                if viewModel.isLoadingSelectedPortfolioDetails {
                    VStack(spacing: Spacing.sm) {
                        ProgressView()
                        Text("Đang tải dữ liệu danh mục...")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.lg)
                } else if viewModel.assets.isEmpty {
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
                                allocations: viewModel.compactIndustryAllocations
                            )

                            allocationDonutCard(
                                title: "Tỷ trọng theo cổ phiếu",
                                allocations: viewModel.compactAssetAllocations
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Danh sách mã nắm giữ")
                            .font(AppTypography.displayCaption)
                            .foregroundStyle(.primary)

                        VStack(spacing: Spacing.sm) {
                            ForEach(viewModel.sortedAssets, id: \.symbol) { asset in
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
                                            "KL \(viewModel.formatQuantity(asset.totalQuantity)) • Giá vốn \(CurrencyFormatter.format(asset.averagePrice)) • Giá hiện tại \(CurrencyFormatter.format(asset.closePrice ?? 0))"
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

                                if asset.symbol != viewModel.sortedAssets.last?.symbol {
                                    Divider()
                                }
                            }
                        }
                        .padding(Spacing.md)
                        .background(AppColors.cardBackground)
                        .clipShape(.rect(cornerRadius: CornerRadius.medium))
                    }
                }

                if let portfolioHealth = viewModel.portfolioHealth {
                    if let portfolioBenchmark = viewModel.portfolioBenchmark {
                        PortfolioBenchmarkCards(benchmark: portfolioBenchmark)
                            .padding(.top, Spacing.sm)
                    } else {
                        PortfolioHealthCard(health: portfolioHealth)
                            .padding(.top, Spacing.sm)
                    }
                }

                if viewModel.selectedPortfolio != nil {
                    navVsIndexPerformanceCard(viewModel: viewModel)
                        .padding(.top, Spacing.md)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .background(AppColors.appBackground)
    }

    private func navVsIndexPerformanceCard(viewModel: InvestmentPortfolioViewModel) -> some View {
        @Bindable var viewModel = viewModel

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Hiệu suất vs \(viewModel.portfolioPerformance?.benchmarkCode ?? "VNINDEX")")
                    .font(AppTypography.displayCaption)
                    .foregroundStyle(.primary)
                Spacer()
                Picker(
                    "Kỳ",
                    selection: Binding(
                        get: { viewModel.performanceRange },
                        set: { viewModel.performanceRange = $0 }
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

            if let perf = viewModel.portfolioPerformance {
                let hasPortfolio = perf.portfolioPoints.contains { $0.returnPct != nil }
                let hasBench = perf.benchmarkPoints.contains { $0.returnPct != nil }
                if hasPortfolio || hasBench {
                    Chart {
                        ForEach(perf.portfolioPoints, id: \.date) { pt in
                            if let rp = pt.returnPct {
                                LineMark(
                                    x: .value("Ngày", viewModel.performanceChartDay(pt.date)),
                                    y: .value("%", rp)
                                )
                                .foregroundStyle(AppColors.primary)
                                .interpolationMethod(.catmullRom)
                            }
                        }
                        ForEach(perf.benchmarkPoints, id: \.date) { pt in
                            if let rp = pt.returnPct {
                                LineMark(
                                    x: .value("Ngày", viewModel.performanceChartDay(pt.date)),
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
        .clipShape(.rect(cornerRadius: CornerRadius.medium))
    }

    @ViewBuilder
    private func portfolioSummaryStats(viewModel: InvestmentPortfolioViewModel) -> some View {
        let pnlValue = viewModel.unrealizedPnLValue
        let pnlColor: Color = pnlValue >= 0 ? AppColors.chartGrowthStrong : AppColors.error
        let pnlPrefix = pnlValue >= 0 ? "+" : ""
        let pnlPctText: String = {
            guard let pct = viewModel.unrealizedPnLPct else { return "—" }
            return String(format: "%@%.2f%%", pct >= 0 ? "+" : "", pct)
        }()

        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Giá trị thị trường: \(CurrencyFormatter.format(viewModel.selectedPortfolioMarketValue))")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.textInverted.opacity(OpacityLevel.high))

            Text("Giá vốn danh mục: \(CurrencyFormatter.format(viewModel.portfolioCostBasis))")
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
