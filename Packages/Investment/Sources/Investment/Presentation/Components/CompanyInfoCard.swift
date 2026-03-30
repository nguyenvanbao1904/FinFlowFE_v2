import Charts
import FinFlowCore
import SwiftUI

/// Unified company information card: header, description, key metrics, valuation, shareholders.
public struct CompanyInfoCard: View {
    let overview: StockOverview
    let shareholders: [ShareholderDataPoint]
    @State private var isDescriptionExpanded = false

    public init(overview: StockOverview, shareholders: [ShareholderDataPoint]) {
        self.overview = overview
        self.shareholders = shareholders
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            headerSection
            descriptionSection

            Divider()
            keyMetricsSection

            Divider()
            valuationSection

            Divider()
            shareholdersSection
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(overview.companyName)
                .font(AppTypography.title)
                .fontWeight(.bold)
                .foregroundStyle(AppColors.apple)
            Text("(\(overview.exchange): \(overview.symbol))  ·  \(overview.industryLabel)")
                .font(AppTypography.subheadline)
                .foregroundStyle(.secondary)
            if let icb = overview.industryIcbCode {
                Text("ICB: \(icb)")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(overview.description)
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
                .lineLimit(isDescriptionExpanded ? nil : 3)

            if overview.description.count > 150 {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        isDescriptionExpanded.toggle()
                    }
                } label: {
                    Text(isDescriptionExpanded ? "Thu gọn" : "Xem thêm")
                        .font(AppTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isDescriptionExpanded ? "Thu gọn giới thiệu" : "Xem thêm giới thiệu")
            }
        }
    }

    // MARK: - Key Metrics

    private var keyMetricsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Các chỉ số quan trọng")
                .font(AppTypography.headline)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 3),
                spacing: Spacing.xs
            ) {
                metricCell(label: "ROE", value: String(format: "%.2f%%", overview.roe))
                metricCell(label: "ROA", value: String(format: "%.2f%%", overview.roa))
                metricCell(label: "EPS", value: formatNumber(overview.eps))
                metricCell(label: "BVPS", value: formatNumber(overview.bvps))
                metricCell(label: "CPLH", value: String(format: "%.1f tỷ", overview.cplh))
            }
        }
    }

    // MARK: - Valuation

    private var valuationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Góc nhìn FinFlow")
                .font(AppTypography.headline)
            if overview.livePriceVnd != nil {
                Text(
                    "So với trung vị & trung bình lịch sử (theo các quý có P/E, P/B, P/S trong DB): giá hiển thị là VPS gần nhất; EPS TTM, BVPS, doanh thu/CP trên BCTC."
                )
                .font(AppTypography.caption2)
                .foregroundStyle(.secondary)
            }

            VStack(spacing: Spacing.xs) {
                valuationRow(label: "Định giá P/E", current: overview.displayPE, median: overview.medianPE, mean: overview.meanPE)
                valuationRow(label: "Định giá P/B", current: overview.displayPB, median: overview.medianPB, mean: overview.meanPB)
                valuationRow(label: "Định giá P/S", current: overview.displayPS, median: overview.medianPS, mean: overview.meanPS)
            }
        }
    }

    // MARK: - Shareholders

    private var shareholdersSection: some View {
        ProportionDonutChart(
            title: "Top cổ đông lớn",
            slices: shareholderSlices
        )
    }

    private var shareholderSlices: [ProportionDonutSlice] {
        let topHolders = shareholders
            .filter { $0.name != "Cổ đông khác" }
            .sorted { $0.percentage > $1.percentage }
        let pieItems = Array(topHolders.prefix(6))
        let others = max(0, 100 - pieItems.map(\.percentage).reduce(0, +))

        var slices = pieItems.enumerated().map { idx, holder in
            ProportionDonutSlice(
                id: holder.id.uuidString,
                name: holder.name,
                percentage: holder.percentage,
                color: colorForIndex(idx)
            )
        }
        if others > 0.01 {
            slices.append(
                ProportionDonutSlice(
                    id: "others",
                    name: "Cổ đông khác",
                    percentage: others,
                    color: Color.gray.opacity(0.7)
                )
            )
        }
        return slices
    }

    private func colorForIndex(_ index: Int) -> Color {
        let palette: [Color] = [.teal, .purple, .orange, .pink, .indigo, .mint, .brown, .cyan, .red, .gray]
        return palette[index % palette.count]
    }

    // MARK: - Helpers

    private func metricCell(label: String, value: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(AppTypography.body)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.apple)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xs)
        .background(AppColors.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
    }

    private func valuationRow(label: String, current: Double, median: Double, mean: Double?) -> some View {
        let diff = current - median
        let pct = median > 0 ? abs(diff) / median * 100 : 0
        let assessment: (text: String, color: Color) = {
            if median <= 0 { return ("Chưa có trung vị", .secondary) }
            if pct < 5 { return ("Gần trung vị", .secondary) }
            if diff < 0 { return (String(format: "Thấp hơn trung vị %.0f%%", pct), .green) }
            return (String(format: "Cao hơn trung vị %.0f%%", pct), .orange)
        }()
        let benchmarkLine: String? = {
            var parts: [String] = []
            if median > 0 {
                parts.append(String(format: "TV %.2f", median))
            }
            if let m = mean, m.isFinite, m > 0 {
                parts.append(String(format: "TB %.2f", m))
            }
            if parts.isEmpty { return nil }
            return parts.joined(separator: " · ")
        }()

        return HStack(alignment: .center) {
            Text(label)
                .font(AppTypography.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Circle().fill(assessment.color).frame(width: 8, height: 8)
                    Text(assessment.text)
                        .font(AppTypography.caption)
                        .foregroundStyle(assessment.color)
                }
                if let benchmarkLine {
                    Text(benchmarkLine)
                        .font(AppTypography.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private func formatNumber(_ value: Double) -> String {
        if abs(value) >= 1_000 {
            return String(format: "%.0f", value)
                .replacingOccurrences(of: "(?<=\\d)(?=(\\d{3})+$)", with: ",", options: .regularExpression)
        }
        return String(format: "%.2f", value)
    }
}

