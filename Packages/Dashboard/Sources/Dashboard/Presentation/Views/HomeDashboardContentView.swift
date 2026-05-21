import FinFlowCore
import SwiftUI

struct HomeDashboardContentView: View {
    let snapshot: HomeDashboardSnapshot
    let insight: HomeInsight?
    let isLoadingInsight: Bool
    let onSelectTab: (AppTab) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                commandCenter
                insightCard
                quickAccessSection
                metricGrid
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xs)
            .padding(.bottom, UILayout.fixedBottomBarClearance + Spacing.xl)
        }
        .background(AppColors.appBackground)
    }

    private var commandCenter: some View {
        FinancialHeroCard(
            title: "Tổng tài sản",
            mainAmount: CurrencyFormatter.format(snapshot.netWorth),
            subtitle: "Tài sản - Nợ"
        )
    }

    private var insightCard: some View {
        AIInsightCard(
            items: [
                AIInsightCardItem(
                    id: "home-insight",
                    title: insight?.title ?? "Gợi ý hôm nay",
                    message: insightMessage,
                    systemImage: "text.bubble.fill",
                    tint: AppColors.primary
                )
            ],
            isLoading: isLoadingInsight,
            loadingMessage: "Đang đọc bức tranh tài chính..."
        )
    }

    private var insightMessage: String {
        insight?.message
            ?? "FinFlow đang đọc tài sản, thu chi, ngân sách và đầu tư để viết một gợi ý ngắn cho bạn."
    }

    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Truy cập nhanh")
                .font(AppTypography.headline)
                .foregroundStyle(.primary)

            quickAccessGrid
        }
    }

    @ViewBuilder
    private var quickAccessGrid: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: Spacing.sm) {
                quickAccessItems
            }
        } else {
            quickAccessItems
        }
    }

    private var quickAccessItems: some View {
        LazyVGrid(columns: quickAccessColumns, spacing: Spacing.sm) {
            quickAccessButton(
                "Giao dịch",
                systemImage: "list.clipboard.fill",
                tab: .transaction,
                accent: AppColors.chartCapitalDeposits
            )
            quickAccessButton(
                "Tài sản",
                systemImage: "chart.pie.fill",
                tab: .wealth,
                accent: AppColors.chartProfit
            )
            quickAccessButton(
                "Kế hoạch",
                systemImage: "target",
                tab: .planning,
                accent: AppColors.chartGrowthStrong
            )
            quickAccessButton(
                "Đầu tư",
                systemImage: "chart.line.uptrend.xyaxis",
                tab: .investment,
                accent: AppColors.chartRevenue
            )
        }
    }

    private var quickAccessColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: Spacing.sm),
            GridItem(.flexible(), spacing: Spacing.sm),
            GridItem(.flexible(), spacing: Spacing.sm),
            GridItem(.flexible(), spacing: Spacing.sm)
        ]
    }

    private func quickAccessButton(
        _ title: String,
        systemImage: String,
        tab: AppTab,
        accent: Color
    ) -> some View {
        Button {
            onSelectTab(tab)
        } label: {
            VStack(spacing: Spacing.xs) {
                quickAccessIcon(systemImage: systemImage, accent: accent)

                Text(title)
                    .font(AppTypography.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.85)
                    .frame(minHeight: Spacing.sm)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Spacing.xl + Spacing.lg)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Chuyển tới \(title)")
    }

    @ViewBuilder
    private func quickAccessIcon(systemImage: String, accent: Color) -> some View {
        let icon = Image(systemName: systemImage)
            .font(AppTypography.headline)
            .foregroundStyle(accent)
            .frame(
                width: Spacing.touchTarget,
                height: Spacing.touchTarget
            )

        if #available(iOS 26, *) {
            icon
                .glassEffect(
                    .regular.tint(accent.opacity(OpacityLevel.cardSubtleMedium)).interactive(),
                    in: .rect(cornerRadius: CornerRadius.small)
                )
        } else {
            icon
                .background(AppColors.cardBackground)
                .clipShape(.rect(cornerRadius: CornerRadius.small))
        }
    }

    private var metricGrid: some View {
        LazyVGrid(columns: SnapshotGridLayout.twoColumns, spacing: SnapshotGridLayout.spacing) {
            CompactMetricCard(
                title: "Dòng tiền",
                value: CurrencyFormatter.format(monthlyCashflow),
                caption: "Thu \(CurrencyFormatter.format(snapshot.totalIncome))",
                accent: monthlyCashflow >= 0 ? AppColors.success : AppColors.error
            )
            CompactMetricCard(
                title: "Thanh khoản",
                value: runwayValue,
                caption: CurrencyFormatter.format(snapshot.liquidAssets),
                accent: runwayAccent
            )
            CompactMetricCard(
                title: "Ngân sách",
                value: budgetUsageValue,
                caption: "\(CurrencyFormatter.format(snapshot.budgetSpentTotal)) đã chi",
                accent: budgetAccent
            )
            CompactMetricCard(
                title: "Đầu tư",
                value: investmentShareValue,
                caption: CurrencyFormatter.format(snapshot.investmentAssets),
                accent: AppColors.chartRevenue
            )
        }
    }

    private var monthlyCashflow: Double {
        snapshot.totalIncome - snapshot.totalExpense
    }

    private var budgetUsage: Double? {
        guard snapshot.budgetTargetTotal > 0 else { return nil }
        return snapshot.budgetSpentTotal / snapshot.budgetTargetTotal
    }

    private var runwayMonths: Double? {
        guard snapshot.totalExpense > 0 else { return nil }
        return snapshot.liquidAssets / snapshot.totalExpense
    }

    private var investmentShare: Double? {
        guard snapshot.netWorth > 0 else { return nil }
        return snapshot.investmentAssets / snapshot.netWorth
    }

    private var runwayValue: String {
        guard let runwayMonths else { return "Chưa rõ" }
        if runwayMonths >= 12 {
            return "\(Int(runwayMonths.rounded())) tháng"
        }
        return String(format: "%.1f tháng", runwayMonths)
    }

    private var runwayAccent: Color {
        guard let runwayMonths else { return AppColors.chartCapitalDeposits }
        if runwayMonths >= 6 { return AppColors.success }
        if runwayMonths >= 3 { return AppColors.chartGrowthStable }
        return AppColors.error
    }

    private var budgetUsageValue: String {
        guard let budgetUsage else { return "Chưa có" }
        return "\(Int((budgetUsage * 100).rounded()))%"
    }

    private var budgetAccent: Color {
        guard let budgetUsage else { return AppColors.chartGrowthStable }
        if budgetUsage > 1 { return AppColors.error }
        if budgetUsage > 0.85 { return AppColors.chartGrowthStable }
        return AppColors.success
    }

    private var investmentShareValue: String {
        guard let investmentShare else { return "Chưa có" }
        return "\(Int((investmentShare * 100).rounded()))%"
    }
}
