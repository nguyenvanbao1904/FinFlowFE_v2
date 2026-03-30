import FinFlowCore
import SwiftUI

struct HomeDashboardContentView: View {
    let snapshot: HomeDashboardSnapshot
    let onOpenBot: () -> Void
    let onSelectTab: (AppTab) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                FinancialHeroCard(
                    title: "Tổng giá trị các danh mục",
                    mainAmount: CurrencyFormatter.format(snapshot.investmentTotalValue),
                    subtitle: "Tiền mặt và cổ phiếu · mọi danh mục"
                )

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Tóm tắt nhanh")
                        .font(AppTypography.headline)
                        .foregroundStyle(.primary)

                    LazyVGrid(columns: SnapshotGridLayout.twoColumns, spacing: SnapshotGridLayout.spacing) {
                        CompactMetricCard(
                            title: "Thu",
                            value: CurrencyFormatter.format(snapshot.totalIncome),
                            caption: "Tổng thu nhập",
                            accent: AppColors.chartGrowthStrong
                        )
                        CompactMetricCard(
                            title: "Chi",
                            value: CurrencyFormatter.format(snapshot.totalExpense),
                            caption: "Tổng chi tiêu",
                            accent: AppColors.expense
                        )
                        CompactMetricCard(
                            title: "Kế hoạch",
                            value: budgetPercentValue,
                            caption: budgetCaption,
                            accent: budgetAccent
                        )
                        CompactMetricCard(
                            title: "Đầu tư",
                            value: investmentPrimaryValue,
                            caption: investmentCaption,
                            accent: AppColors.chartRevenue
                        )
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Lối tắt")
                        .font(AppTypography.headline)
                        .foregroundStyle(.primary)

                    LazyVGrid(columns: SnapshotGridLayout.twoColumns, spacing: SnapshotGridLayout.spacing) {
                        quickNavButton(title: "Giao dịch", symbol: "list.clipboard.fill", tab: .transaction, accent: AppColors.chartCapitalDeposits)
                        quickNavButton(title: "Kế hoạch", symbol: "target", tab: .planning, accent: AppColors.chartGrowthStrong)
                        quickNavButton(title: "Tài sản", symbol: "chart.pie.fill", tab: .wealth, accent: AppColors.chartProfit)
                        quickNavButton(title: "Đầu tư", symbol: "chart.line.uptrend.xyaxis", tab: .investment, accent: AppColors.chartRevenue)
                    }
                }
                .accessibilityElement(children: .contain)
            }
            .padding(.horizontal)
            .padding(.bottom, Spacing.xl)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                Spacer()
                FinFlowBotGlassOrb(
                    mascotAssetName: "FinFlowBotMascot",
                    mascotBundle: .main,
                    showsNotificationDot: true
                ) {
                    onOpenBot()
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.bottom, Spacing.xs)
        }
    }

    private func quickNavButton(title: String, symbol: String, tab: AppTab, accent: Color) -> some View {
        Button {
            onSelectTab(tab)
        } label: {
            CompactMetricCard(systemImage: symbol, headline: title, accent: accent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Chuyển tới \(title)")
    }

    private var budgetCaption: String {
        let target = snapshot.budgetTargetTotal
        let spent = snapshot.budgetSpentTotal
        if target > 0 {
            return "Đã chi \(CurrencyFormatter.format(spent)) · Ngân sách \(CurrencyFormatter.format(target))"
        }
        return "Chưa đặt ngân sách"
    }

    private var budgetPercentValue: String {
        let target = snapshot.budgetTargetTotal
        let spent = snapshot.budgetSpentTotal
        guard target > 0 else { return "—" }

        let pct = min(spent / target, 1.0)
        return "\(Int((pct * 100).rounded()))%"
    }

    private var budgetAccent: Color {
        let target = snapshot.budgetTargetTotal
        let spent = snapshot.budgetSpentTotal
        if target > 0, spent > target {
            return AppColors.error
        }
        if target > 0, spent > target * 0.85 {
            return AppColors.chartGrowthStable
        }
        return AppColors.chartCapitalDeposits
    }

    private var investmentPrimaryValue: String {
        guard snapshot.portfolioCount > 0 else { return "—" }
        return "\(snapshot.portfolioCount)"
    }

    private var investmentCaption: String {
        if snapshot.portfolioCount == 0 {
            return "Chưa có danh mục"
        }

        let cash = CurrencyFormatter.format(snapshot.portfolioCashTotal)
        let primaryName = snapshot.primaryPortfolioName ?? "Danh mục"
        return "Tiền mặt \(cash) · Danh mục chính: \(primaryName)"
    }
}
