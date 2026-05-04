import Charts
import FinFlowCore
import SwiftUI

struct InvestmentPortfolioTabContent: View {
    let viewModel: InvestmentPortfolioViewModel
    @Binding var showCreatePortfolio: Bool
    @Binding var showAddInvestmentActionSheet: Bool
    @Binding var selectedAssetForDetail: PortfolioAssetResponse?
    var onRenamePortfolio: () -> Void = {}
    var onDeletePortfolio: () -> Void = {}
    var onShowHistory: () -> Void = {}
    var onAskAI: ((String) -> Void)?

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

                    if viewModel.selectedPortfolio != nil {
                        Button {
                            onRenamePortfolio()
                        } label: {
                            Label("Đổi tên danh mục", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            onDeletePortfolio()
                        } label: {
                            Label("Xóa danh mục", systemImage: "trash")
                        }
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
                        HStack {
                            Text("Danh sách mã nắm giữ")
                                .font(AppTypography.displayCaption)
                                .foregroundStyle(.primary)
                            Spacer()
                            Button {
                                onShowHistory()
                            } label: {
                                HStack(spacing: Spacing.xs / 2) {
                                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                                        .font(AppTypography.caption)
                                    Text("Lịch sử")
                                        .font(AppTypography.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(AppColors.primary)
                            }
                            .buttonStyle(.plain)
                        }

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
                                            "KL \(CurrencyFormatter.formatQuantity(asset.totalQuantity)) • Giá vốn \(CurrencyFormatter.format(asset.averagePrice)) • Giá hiện tại \(CurrencyFormatter.format(asset.closePrice ?? 0))"
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

                let assessment = PortfolioAssessment.compute(
                    assets: viewModel.sortedAssets,
                    industryAllocations: viewModel.compactIndustryAllocations
                )
                PortfolioAssessmentCard(
                    assessment: assessment,
                    portfolioName: viewModel.selectedPortfolio?.name ?? "Danh mục",
                    onAskAI: onAskAI,
                    survivalRunwayMonths: viewModel.survivalRunwayMonths,
                    monthlyInvestRatio: viewModel.monthlyInvestRatio,
                    onOpenCFO: onAskAI.map { askAI in { askAI(cfoPrompt(viewModel: viewModel)) } }
                )

                if let portfolioHealth = viewModel.portfolioHealth {
                    if let portfolioBenchmark = viewModel.portfolioBenchmark {
                        PortfolioBenchmarkCards(benchmark: portfolioBenchmark)
                            .padding(.top, Spacing.sm)
                    } else {
                        PortfolioHealthCard(health: portfolioHealth)
                            .padding(.top, Spacing.sm)
                    }
                }

            }
        }
        .padding(.horizontal, Spacing.md)
        .background(AppColors.appBackground)
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
            Text("Cổ phiếu: \(CurrencyFormatter.format(viewModel.selectedPortfolioMarketValue - (viewModel.selectedPortfolio?.cashBalance ?? 0)))")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.textInverted.opacity(OpacityLevel.high))

            Text("Tiền mặt: \(CurrencyFormatter.format(viewModel.selectedPortfolio?.cashBalance ?? 0))")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.textInverted.opacity(OpacityLevel.high))

            Text("Giá vốn: \(CurrencyFormatter.format(viewModel.portfolioCostBasis))")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.textInverted.opacity(OpacityLevel.medium))

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
                    if alloc.name == "Khác" { return AppColors.chartOther }
                    let palette = AppColors.chartPalette
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

    private func cfoPrompt(viewModel: InvestmentPortfolioViewModel) -> String {
        var parts = ["Phân tích tình hình tài chính của tôi với vai trò CFO ảo:"]
        if let runway = viewModel.survivalRunwayMonths {
            parts.append("Quỹ dự phòng hiện tại: \(String(format: "%.1f", runway)) tháng.")
        }
        if let ratio = viewModel.monthlyInvestRatio {
            parts.append("Tỉ lệ đầu tư/thu nhập thặng dư: \(Int(round(ratio * 100)))%.")
        }
        parts.append("Danh mục: \(viewModel.selectedPortfolio?.name ?? "Danh mục chính").")
        parts.append("Đánh giá rủi ro tài chính tổng thể và đề xuất hướng cân bằng dòng tiền.")
        return parts.joined(separator: " ")
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
            AppColors.chartAssetShortTermInvestments
        ]
        let hash = abs(symbol.hashValue)
        return palette[hash % palette.count]
    }
}
