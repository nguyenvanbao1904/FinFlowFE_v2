import Charts
import FinFlowCore
import SwiftUI

/// Unified company information card: header, description, key metrics, valuation, shareholders.
public struct CompanyInfoCard: View {
    let overview: StockOverview
    let shareholders: [ShareholderDataPoint]
    @State private var isDescriptionExpanded = false
    @State private var selectedShareholderAngle: Double?
    @State private var displayedShareholderKey: String?

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

            VStack(spacing: Spacing.xs) {
                valuationRow(label: "Định giá P/E", current: overview.currentPE, median: overview.medianPE)
                valuationRow(label: "Định giá P/B", current: overview.currentPB, median: overview.medianPB)
                valuationRow(label: "Định giá P/S", current: overview.currentPS, median: overview.medianPS)
            }
        }
    }

    // MARK: - Shareholders

    private var shareholdersSection: some View {
        let slices = shareholderSlices
        let chartSlices = chartRenderableSlices(from: slices)
        let activeSlice = displayedShareholderKey.flatMap { key in
            slices.first(where: { $0.id == key })
        } ?? slices.first

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Top cổ đông lớn")
                .font(AppTypography.headline)
            if let activeSlice {
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(activeSlice.color)
                        .frame(width: 8, height: 8)
                    Text("\(activeSlice.name): \(String(format: "%.2f%%", activeSlice.percentage))")
                        .font(AppTypography.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: Spacing.md) {
                Chart {
                    ForEach(chartSlices) { slice in
                        SectorMark(
                            angle: .value("Tỷ lệ", slice.percentage),
                            innerRadius: .ratio(0.58),
                            angularInset: 1.4
                        )
                        .foregroundStyle(slice.color)
                        .opacity(slice.isPaddingSlice ? 0.001 : opacity(for: slice.id))
                    }
                }
                .chartAngleSelection(value: $selectedShareholderAngle)
                .onChange(of: selectedShareholderAngle) { _, newValue in
                    let newKey = newValue.flatMap { selectedShareholderSlice(for: $0, slices: slices)?.id }
                    displayedShareholderKey = newKey
                }
                .chartLegend(.hidden)
                .frame(width: 130, height: 130)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(slices) { slice in
                        HStack(spacing: Spacing.xs) {
                            Circle()
                                .fill(slice.color)
                                .frame(width: 8, height: 8)
                            Text(slice.name)
                                .font(AppTypography.caption2)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(String(format: "%.2f%%", slice.percentage))
                                .font(AppTypography.caption2)
                                .foregroundStyle(displayedShareholderKey == slice.id ? .primary : .secondary)
                        }
                        .opacity(opacity(for: slice.id))
                    }
                }
            }
        }
    }

    private func opacity(for sliceID: String) -> Double {
        guard let selected = displayedShareholderKey else { return 1.0 }
        return selected == sliceID ? 1.0 : 0.35
    }

    /// Swift Charts pie/sector có thể assert khi chỉ có 1 lát.
    /// Thêm 1 lát đệm gần như vô hình để đảm bảo domain góc luôn có >= 2 giá trị.
    private func chartRenderableSlices(from slices: [ShareholderSlice]) -> [ShareholderSlice] {
        guard slices.count == 1, let only = slices.first, only.percentage > 0 else { return slices }
        return slices + [
            ShareholderSlice(
                id: "__padding_slice__",
                name: "",
                percentage: 0.0001,
                color: .clear
            )
        ]
    }

    private var shareholderSlices: [ShareholderSlice] {
        let topHolders = shareholders
            .filter { $0.name != "Cổ đông khác" }
            .sorted { $0.percentage > $1.percentage }
        let pieItems = Array(topHolders.prefix(6))
        let others = max(0, 100 - pieItems.map(\.percentage).reduce(0, +))

        var slices = pieItems.enumerated().map { idx, holder in
            ShareholderSlice(
                id: holder.id.uuidString,
                name: holder.name,
                percentage: holder.percentage,
                color: colorForIndex(idx)
            )
        }
        if others > 0.01 {
            slices.append(
                ShareholderSlice(
                    id: "others",
                    name: "Cổ đông khác",
                    percentage: others,
                    color: Color.gray.opacity(0.7)
                )
            )
        }
        return slices
    }

    private func selectedShareholderSlice(for angle: Double, slices: [ShareholderSlice]) -> ShareholderSlice? {
        guard !slices.isEmpty else { return nil }
        let total = slices.map(\.percentage).reduce(0, +)
        guard total > 0 else { return nil }

        let normalizedAngle = max(0, min(angle, total))
        var accumulated = 0.0
        for slice in slices {
            accumulated += slice.percentage
            if normalizedAngle <= accumulated {
                return slice
            }
        }
        return slices.last
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

    private func valuationRow(label: String, current: Double, median: Double) -> some View {
        let diff = current - median
        let pct = abs(diff) / median * 100
        let assessment: (text: String, color: Color) = {
            if pct < 5 { return ("Gần trung vị", .secondary) }
            else if diff < 0 { return (String(format: "Thấp hơn trung vị %.0f%%", pct), .green) }
            else { return (String(format: "Cao hơn trung vị %.0f%%", pct), .orange) }
        }()

        return HStack {
            Text(label)
                .font(AppTypography.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: Spacing.xs) {
                Circle().fill(assessment.color).frame(width: 8, height: 8)
                Text(assessment.text)
                    .font(AppTypography.caption)
                    .foregroundStyle(assessment.color)
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

private struct ShareholderSlice: Identifiable {
    let id: String
    let name: String
    let percentage: Double
    let color: Color

    var isPaddingSlice: Bool { id == "__padding_slice__" }
}
