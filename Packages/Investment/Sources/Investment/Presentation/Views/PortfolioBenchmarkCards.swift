import FinFlowCore
import SwiftUI

/// So sánh P/E, P/B, P/S danh mục với chỉ số thị trường (VNINDEX) — chỉ hiện tại, không chart.
struct PortfolioBenchmarkCards: View {
    let benchmark: PortfolioMarketBenchmarkResponse

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Định giá danh mục")
                    .font(AppTypography.headline)
                    .foregroundStyle(.primary)
                Text("So với \(benchmark.benchmarkCode)")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: AppSpacing.sm) {
                comparisonRow(title: "Định giá P/E", comparison: benchmark.pe)
                comparisonRow(title: "Định giá P/B", comparison: benchmark.pb)
                comparisonRow(title: "Định giá P/S", comparison: benchmark.ps)
            }
        }
    }

    private func comparisonRow(title: String, comparison: PortfolioMetricComparison) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.headline)
                .foregroundStyle(.primary)

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Danh mục")
                        .font(AppTypography.caption2)
                        .foregroundStyle(.secondary)
                    Text(formatMetric(comparison.portfolio))
                        .font(AppTypography.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(benchmark.benchmarkCode)
                        .font(AppTypography.caption2)
                        .foregroundStyle(.secondary)
                    Text(formatMetric(comparison.benchmark))
                        .font(AppTypography.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(comparisonSummary(comparison))
                .font(AppTypography.caption)
                .fontWeight(.medium)
                .foregroundStyle(summaryColor(comparison))
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(summaryColor(comparison).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }

    private func formatMetric(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        return String(format: "%.2f", value)
    }

    private func comparisonSummary(_ comparison: PortfolioMetricComparison) -> String {
        guard let delta = comparison.deltaPct, let bench = comparison.benchmark, bench != 0 else {
            return "Không đủ dữ liệu để so sánh với \(benchmark.benchmarkCode)."
        }
        if abs(delta) < 0.1 {
            return "Gần bằng \(benchmark.benchmarkCode) (chênh lệch < 0,1%)."
        }
        let dir = delta >= 0 ? "Cao hơn" : "Thấp hơn"
        return "\(dir) \(benchmark.benchmarkCode) khoảng \(String(format: "%.1f", abs(delta)))%."
    }

    private func summaryColor(_ comparison: PortfolioMetricComparison) -> Color {
        guard let delta = comparison.deltaPct else { return .secondary }
        if abs(delta) < 0.1 { return .secondary }
        return delta >= 0 ? AppColors.chartGrowthStable : AppColors.chartGrowthStrong
    }
}
