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
                    color: AppColors.chartOther
                )
            )
        }
        return slices
    }

    private func colorForIndex(_ index: Int) -> Color {
        let palette = AppColors.chartPalette
        return palette[index % palette.count]
    }

}
