import FinFlowCore
import SwiftUI

/// Mobile-first snapshot cards inspired by compact financial dashboards.
public struct MobileInsightSnapshot: View {
    let overview: StockOverview
    let financials: FinancialDataSeries?

    public init(overview: StockOverview, financials: FinancialDataSeries?) {
        self.overview = overview
        self.financials = financials
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Snapshot tài chính")
                .font(AppTypography.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
                snapshotCard(
                    title: "ROE",
                    value: String(format: "%.2f%%", overview.roe),
                    accent: AppColors.chartGrowthStrong,
                    trend: trendText(overview.roe, threshold: 15)
                )
                snapshotCard(
                    title: "ROA",
                    value: String(format: "%.2f%%", overview.roa),
                    accent: AppColors.chartCapitalDeposits,
                    trend: trendText(overview.roa, threshold: 2.5)
                )
                snapshotCard(
                    title: "Định giá P/E",
                    value: String(format: "%.2f", overview.currentPE),
                    accent: AppColors.chartRevenue,
                    trend: valuationTrend(current: overview.currentPE, median: overview.medianPE)
                )
                snapshotCard(
                    title: "Định giá P/B",
                    value: String(format: "%.2f", overview.currentPB),
                    accent: AppColors.chartProfit,
                    trend: valuationTrend(current: overview.currentPB, median: overview.medianPB)
                )
            }
        }
    }

    private func snapshotCard(title: String, value: String, accent: Color, trend: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(AppTypography.headline)
                .fontWeight(.bold)
                .foregroundStyle(AppColors.apple)
                .lineLimit(1)

            Text(trend)
                .font(AppTypography.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Rectangle()
                .fill(accent.opacity(0.85))
                .frame(height: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }

    private func trendText(_ value: Double, threshold: Double) -> String {
        if value >= threshold {
            return "Tích cực so với nhóm ngành"
        }
        if value >= threshold * 0.7 {
            return "Trung tính, cần theo dõi"
        }
        return "Thấp, cần cải thiện hiệu quả"
    }

    private func valuationTrend(current: Double, median: Double) -> String {
        if median <= 0 { return "Không đủ dữ liệu so sánh" }
        let pct = abs(current - median) / median * 100
        if pct < 5 { return "Gần trung vị ngành" }
        return current < median
            ? String(format: "Thấp hơn trung vị %.0f%%", pct)
            : String(format: "Cao hơn trung vị %.0f%%", pct)
    }
}

