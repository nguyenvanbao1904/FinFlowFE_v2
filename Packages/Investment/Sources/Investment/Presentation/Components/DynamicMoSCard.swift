import FinFlowCore
import SwiftUI

/// Thẻ Biên An Toàn Động — hiển thị trong phần Khu vực định giá của StockAnalysisView.
/// Logic: allocation_ratio → required_margin → reference_price = fair_value × (1 - margin).
public struct DynamicMoSCard: View {
    let overview: StockOverview
    @Binding var cautionLevel: MoSCautionLevel
    let allocationRatio: Double?
    let requiredMargin: Double

    @State private var showExplanation = false

    public init(
        overview: StockOverview,
        cautionLevel: Binding<MoSCautionLevel>,
        allocationRatio: Double?,
        requiredMargin: Double
    ) {
        self.overview = overview
        self._cautionLevel = cautionLevel
        self.allocationRatio = allocationRatio
        self.requiredMargin = requiredMargin
    }

    // MARK: - Computed

    private var fairValue: Double? {
        guard let price = overview.livePriceVnd, price > 0 else { return nil }
        let pb = overview.livePB ?? overview.currentPB
        let bvps = overview.bvps
        guard pb > 0, bvps > 0 else { return nil }
        return bvps * overview.medianPB
    }

    private var referencePrice: Double? {
        guard let fv = fairValue else { return nil }
        return fv * (1 - requiredMargin)
    }

    private var currentPrice: Double? { overview.livePriceVnd }

    private var hasWealthData: Bool { allocationRatio != nil }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            headerRow
            Divider()
            priceRow
            marginRow
            cautionPicker
            if !hasWealthData {
                dataConfidenceBadge
            }
            disclaimer
        }
        .padding(Spacing.md)
        .background(AppColors.cardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.medium))
        .sheet(isPresented: $showExplanation) { explanationSheet }
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack {
            Label("Biên An Toàn Tham Khảo", systemImage: "shield.lefthalf.filled")
                .font(AppTypography.headline)
            Spacer()
            Button {
                showExplanation = true
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(AppColors.primary)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Giải thích biên an toàn")
        }
    }

    private var priceRow: some View {
        VStack(spacing: Spacing.xs) {
            if let current = currentPrice {
                labelValueRow(
                    label: "Giá hiện tại",
                    value: CurrencyFormatter.format(current),
                    valueColor: .primary
                )
            }
            if let fv = fairValue {
                labelValueRow(
                    label: "Fair value ước tính (PB trung vị)",
                    value: CurrencyFormatter.format(fv),
                    valueColor: AppColors.primary
                )
            }
            if let ref = referencePrice {
                let retainPct = Int(round((1 - requiredMargin) * 100))
                labelValueRow(
                    label: "Vùng tham khảo (fair value × \(retainPct)%)",
                    value: "≤ \(CurrencyFormatter.format(ref))",
                    valueColor: AppColors.success
                )
            }

            if fairValue == nil {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.secondary)
                    Text("Chưa đủ dữ liệu để tính fair value cho \(overview.symbol)")
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var marginRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let ratio = allocationRatio {
                labelValueRow(
                    label: "Tỉ lệ đầu tư / tổng tài sản",
                    value: ratio.formatted(.percent.precision(.fractionLength(0))),
                    valueColor: .primary
                )
            }
            labelValueRow(
                label: "Biên lý thuyết",
                value: requiredMargin.formatted(.percent.precision(.fractionLength(0))),
                valueColor: .primary
            )
        }
    }

    private var cautionPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Mức thận trọng")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: Spacing.sm) {
                ForEach(MoSCautionLevel.allCases, id: \.self) { level in
                    CautionLevelButton(
                        title: level.rawValue,
                        isSelected: cautionLevel == level
                    ) {
                        cautionLevel = level
                    }
                }
            }
        }
    }

    private var dataConfidenceBadge: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "chart.bar.fill")
                .font(AppTypography.caption)
                .foregroundStyle(.orange)
            Text("Độ chính xác ~60% — cập nhật tài sản để cá nhân hóa")
                .font(AppTypography.caption)
                .foregroundStyle(.orange)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .clipShape(.rect(cornerRadius: CornerRadius.small))
    }

    private var disclaimer: some View {
        Text("⚠ Thông tin tham khảo theo lý thuyết đầu tư giá trị. Không phải khuyến nghị mua/bán.")
            .font(AppTypography.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Explanation Sheet

    private var explanationSheet: some View {
        SheetContainer(title: "Biên An Toàn là gì?", detents: [.medium]) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text(
                        "Biên an toàn (Margin of Safety) là khái niệm trong đầu tư giá trị — mua thấp hơn fair value để có biên bảo vệ khi định giá sai."
                    )
                    .font(AppTypography.body)

                    Text(
                        "Biên cao hơn khi tỉ lệ tài sản đầu tư lớn hơn, vì rủi ro ảnh hưởng đến tài chính cá nhân cao hơn."
                    )
                    .font(AppTypography.body)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Bảng tham chiếu")
                            .font(AppTypography.headline)
                        tierRow(range: "< 20% tổng tài sản", margin: "15%")
                        tierRow(range: "20–50% tổng tài sản", margin: "25%")
                        tierRow(range: "> 50% tổng tài sản", margin: "35%")
                    }
                    .padding(Spacing.md)
                    .background(AppColors.settingsCardBackground)
                    .clipShape(.rect(cornerRadius: CornerRadius.medium))

                    Text("Mức thận trọng do bạn tự chọn — tăng hoặc giảm biên theo đánh giá cá nhân.")
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(Spacing.lg)
            }
        }
    }

    private func tierRow(range: String, margin: String) -> some View {
        HStack {
            Text(range)
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Biên \(margin)")
                .font(AppTypography.caption)
                .fontWeight(.medium)
        }
    }

    // MARK: - Helpers

    private func labelValueRow(label: String, value: String, valueColor: Color) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Text(value)
                .font(AppTypography.caption)
                .fontWeight(.medium)
                .foregroundStyle(valueColor)
        }
    }
}

// MARK: - CautionLevelButton

private struct CautionLevelButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(isSelected ? AppColors.primary : AppColors.settingsCardBackground)
                .foregroundStyle(isSelected ? AppColors.textInverted : .primary)
                .clipShape(.rect(cornerRadius: CornerRadius.small))
        }
        .buttonStyle(.plain)
    }
}
