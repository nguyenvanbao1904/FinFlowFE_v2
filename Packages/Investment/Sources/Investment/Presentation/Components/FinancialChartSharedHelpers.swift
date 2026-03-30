import FinFlowCore
import SwiftUI

/// Công thức chung cho trục Y chart cột: miền dữ liệu thực + 10% headroom.
func unifiedBarDomain(values: [Double], floorAtZero: Bool = true) -> ClosedRange<Double> {
    let finite = values.filter(\.isFinite)
    guard !finite.isEmpty else { return 0...1 }

    var minVal = finite.min() ?? 0
    var maxVal = finite.max() ?? 0
    if floorAtZero {
        minVal = min(0, minVal)
        maxVal = max(0, maxVal)
    }

    let span = max(maxVal - minVal, 1)
    return minVal...(maxVal + span * 0.10)
}

func recentScrollStartLabel(labels: [String], visibleLength: Int) -> String {
    guard !labels.isEmpty else { return "" }
    let startIndex = max(labels.count - visibleLength, 0)
    return labels[startIndex]
}

/// `ratio` là hệ số (vd -0,18); hiển thị **%** (vd -18%) theo locale vi.
func formatRatioVi(_ ratio: Double) -> String {
    let percent = ratio * 100
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: "vi_VN")
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 2
    let num = formatter.string(from: NSNumber(value: percent)) ?? String(format: "%.2f", percent)
    return "\(num)%"
}

func formatVndCompact(_ value: Double) -> String {
    // Backend returns VND (dong). Force one display unit: billion VND.
    let billion = value / 1_000_000_000
    let absBillion = abs(billion)
    let fractionDigits: Int
    if absBillion >= 100 {
        fractionDigits = 0
    } else if absBillion >= 10 {
        fractionDigits = 1
    } else {
        fractionDigits = 2
    }

    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: "vi_VN")
    formatter.minimumFractionDigits = fractionDigits
    formatter.maximumFractionDigits = fractionDigits

    let number = formatter.string(from: NSNumber(value: billion))
        ?? String(format: "%.\(fractionDigits)f", billion)
    return "\(number) tỷ"
}

func chartLegendItem(_ title: String, color: Color) -> some View {
    HStack(spacing: Spacing.xs) {
        RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
        Text(title)
            .font(AppTypography.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }
}

func nativeSelectionDetails(title: String, subtitle: String, metrics: [ChartPopoverMetric]) -> some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
        Text(title)
            .font(AppTypography.caption)
            .fontWeight(.semibold)
        Text(subtitle)
            .font(AppTypography.caption2)
            .foregroundStyle(.secondary)
        ForEach(metrics, id: \.id) { metric in
            nativeSelectionMetricRow(metric)
        }
    }
    .padding(Spacing.sm)
    .background(AppColors.appBackground)
    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
}

func nativeSelectionMetricRow(_ metric: ChartPopoverMetric) -> some View {
    HStack(spacing: Spacing.xs) {
        Circle()
            .fill(metric.color)
            .frame(width: 6, height: 6)
        Text(metric.label)
            .font(AppTypography.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        Spacer(minLength: 0)
        Text(metric.value)
            .font(AppTypography.caption2)
            .fontWeight(.semibold)
            .lineLimit(1)
    }
}
