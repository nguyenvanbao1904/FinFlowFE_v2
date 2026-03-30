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
                    title: "Định giá P/E",
                    value: String(format: "%.2f", overview.displayPE),
                    caption: valuationTrend(current: overview.displayPE, median: overview.medianPE, mean: overview.meanPE),
                    accent: AppColors.chartRevenue
                )
                CompactMetricCard(
                    title: "Định giá P/B",
                    value: String(format: "%.2f", overview.displayPB),
                    caption: valuationTrend(current: overview.displayPB, median: overview.medianPB, mean: overview.meanPB),
                    accent: AppColors.chartProfit
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

    private func valuationTrend(current: Double, median: Double, mean: Double?) -> String {
        var lines: [String] = []
        if median > 0 {
            let pct = abs(current - median) / median * 100
            if pct < 5 {
                lines.append("Gần trung vị lịch sử")
            } else if current < median {
                lines.append(String(format: "Thấp hơn TV %.0f%%", pct))
            } else {
                lines.append(String(format: "Cao hơn TV %.0f%%", pct))
            }
        } else {
            lines.append("Chưa có TV lịch sử")
        }
        if let m = mean, m.isFinite, m > 0 {
            lines.append(String(format: "TB lịch sử: %.2f", m))
        }
        return lines.joined(separator: "\n")
    }
}

