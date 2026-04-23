import Charts
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

private let _ratioViFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: "vi_VN")
    f.minimumFractionDigits = 0
    f.maximumFractionDigits = 2
    return f
}()

/// `ratio` là hệ số (vd -0,18); hiển thị **%** (vd -18%) theo locale vi.
func formatRatioVi(_ ratio: Double) -> String {
    let percent = ratio * 100
    let num = _ratioViFormatter.string(from: NSNumber(value: percent)) ?? String(format: "%.2f", percent)
    return "\(num)%"
}

private let _vndFormatter0: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: "vi_VN")
    f.minimumFractionDigits = 0
    f.maximumFractionDigits = 0
    return f
}()

private let _vndFormatter1: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: "vi_VN")
    f.minimumFractionDigits = 1
    f.maximumFractionDigits = 1
    return f
}()

private let _vndFormatter2: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: "vi_VN")
    f.minimumFractionDigits = 2
    f.maximumFractionDigits = 2
    return f
}()

func formatVndCompact(_ value: Double) -> String {
    let billion = value / 1_000_000_000
    let absBillion = abs(billion)
    let formatter: NumberFormatter
    if absBillion >= 100 {
        formatter = _vndFormatter0
    } else if absBillion >= 10 {
        formatter = _vndFormatter1
    } else {
        formatter = _vndFormatter2
    }
    let fractionDigits = formatter.maximumFractionDigits
    let number = formatter.string(from: NSNumber(value: billion))
        ?? String(format: "%.\(fractionDigits)f", billion)
    return "\(number) tỷ"
}

func chartLegendItem(_ title: String, color: Color) -> some View {
    HStack(spacing: Spacing.xs) {
        RoundedRectangle(cornerRadius: CornerRadius.hairline).fill(color).frame(width: UILayout.chartLegendDot, height: UILayout.chartLegendDot)
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
            .frame(width: UILayout.chartLegendDotSmall, height: UILayout.chartLegendDotSmall)
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

// MARK: - Interactive Chart Scaffold

/// Encapsulates the common scroll / selection / popover / layout boilerplate
/// shared across all Interactive*Chart views.
///
/// Usage:
/// ```
/// InteractiveChartScaffold(
///     labels: labels,
///     height: height,
///     fullScreen: fullScreen,
///     legendReserved: legendReserved,
///     popoverBuilder: { label in ... },
///     legend: { ... }
/// ) { scrollLabel, selectedLabel, chartHeight in
///     Chart { ... }
///         .chartYAxis { ... }
///         .chartXAxis {
///             AxisMarks(values: .automatic(desiredCount: fullScreen ? 6 : 4)) {
///                 AxisGridLine().foregroundStyle(AppColors.chartGridLine)
///                 AxisValueLabel().font(AppTypography.caption2)
///             }
///         }
///         .interactiveChartModifiers(
///             scrollLabel: scrollLabel,
///             selectedLabel: selectedLabel,
///             visibleLength: visibleLength,
///             fullScreen: fullScreen,
///             chartHeight: chartHeight
///         )
/// }
/// ```
struct InteractiveChartScaffold<ChartContent: View, Legend: View>: View {
    let labels: [String]
    let height: CGFloat
    let fullScreen: Bool
    let legendReserved: CGFloat
    let popoverBuilder: (String, Int) -> [ChartPopoverMetric]?
    let popoverSubtitle: String
    @ViewBuilder let legend: () -> Legend
    @ViewBuilder let chartContent: (
        _ scrollLabel: Binding<String>,
        _ selectedLabel: Binding<String?>,
        _ chartHeight: CGFloat
    ) -> ChartContent

    @State private var selectedLabel: String?
    @State private var displayedLabel: String?
    @State private var hidePopoverTask: Task<Void, Never>?
    @State private var scrollLabel: String = ""

    var visibleLength: Int {
        fullScreen ? min(8, max(1, labels.count)) : min(4, max(1, labels.count))
    }

    private var chartHeight: CGFloat {
        fullScreen ? max(110, height - legendReserved - 20) : max(140, height - legendReserved)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            chartContent($scrollLabel, $selectedLabel, chartHeight)
                .onAppear {
                    if scrollLabel.isEmpty {
                        scrollLabel = recentScrollStartLabel(labels: labels, visibleLength: visibleLength)
                    }
                }
                .onChange(of: selectedLabel) { _, newValue in displayedLabel = newValue }

            legend()
                .frame(height: legendReserved, alignment: .leading)
        }
        .overlay(alignment: .topTrailing) {
            if fullScreen, let label = displayedLabel,
               let idx = labels.firstIndex(of: label),
               let metrics = popoverBuilder(label, idx), !metrics.isEmpty
            {
                nativeSelectionDetails(title: label, subtitle: popoverSubtitle, metrics: metrics)
                    .frame(maxWidth: 280)
                    .padding(.top, Spacing.sm)
                    .padding(.trailing, Spacing.sm)
            }
        }
        .zIndex(displayedLabel == nil ? 0 : 1)
        .frame(height: height, alignment: .top)
        .onDisappear {
            hidePopoverTask?.cancel()
            hidePopoverTask = nil
        }
    }
}

// MARK: - Chart Modifiers Extension

extension View {
    /// Applies the standard interactive chart scroll/selection modifiers.
    func interactiveChartModifiers(
        scrollLabel: Binding<String>,
        selectedLabel: Binding<String?>,
        visibleLength: Int,
        fullScreen: Bool,
        chartHeight: CGFloat
    ) -> some View {
        self
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: visibleLength)
            .chartScrollPosition(x: scrollLabel)
            .chartXSelection(value: selectedLabel)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: fullScreen ? 6 : 4)) {
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                    AxisValueLabel().font(AppTypography.caption2)
                }
            }
            .padding(.top, fullScreen ? -Spacing.sm : 0)
            .frame(height: chartHeight)
    }
}
