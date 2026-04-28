import FinFlowCore
import SwiftUI

/// Mobile-first snapshot cards inspired by compact financial dashboards.
public struct MobileInsightSnapshot: View {
    let overview: StockOverview

    public init(overview: StockOverview) {
        self.overview = overview
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Các chỉ số quan trọng")
                .font(AppTypography.headline)

            LazyVGrid(columns: SnapshotGridLayout.twoColumns, spacing: SnapshotGridLayout.spacing) {
                CompactMetricCard(
                    title: "ROE",
                    value: String(format: "%.2f%%", overview.roe),
                    caption: trendText(overview.roe, threshold: 15),
                    accent: AppColors.chartGrowthStrong
                )
                CompactMetricCard(
                    title: "ROA",
                    value: String(format: "%.2f%%", overview.roa),
                    caption: trendText(overview.roa, threshold: 2.5),
                    accent: AppColors.chartCapitalDeposits
                )
                CompactMetricCard(
                    title: "EPS",
                    value: formatNumber(overview.eps),
                    caption: "VND / cổ phiếu",
                    accent: AppColors.chartRevenue
                )
                CompactMetricCard(
                    title: "BVPS",
                    value: formatNumber(overview.bvps),
                    caption: "VND / cổ phiếu",
                    accent: AppColors.chartProfit
                )
                CompactMetricCard(
                    title: "CPLH",
                    value: String(format: "%.1f tỷ", overview.cplh),
                    caption: "Cổ phiếu lưu hành",
                    accent: AppColors.chartIncomeFee
                )
            }
        }
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

    private func formatNumber(_ value: Double) -> String {
        if abs(value) >= 1_000 {
            return String(format: "%.0f", value)
                .replacingOccurrences(of: "(?<=\\d)(?=(\\d{3})+$)", with: ",", options: .regularExpression)
        }
        return String(format: "%.2f", value)
    }
}
