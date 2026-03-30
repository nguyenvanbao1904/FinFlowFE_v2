import Charts
import FinFlowCore
import SwiftUI

struct InteractiveRoeRoaChart: View {
    let data: [RoeRoaPoint]
    let showQuarterly: Bool
    let height: CGFloat
    let fullScreen: Bool
    @State private var selectedLabel: String?
    @State private var displayedLabel: String?
    @State private var hidePopoverTask: Task<Void, Never>?
    @State private var scrollLabel: String = ""

    private var labels: [String] {
        data.map { d in
            if showQuarterly && d.quarter != 0 {
                return "Q\(d.quarter) \(d.year % 100)"
            }
            return "\(d.year)"
        }
    }
    private var visibleLength: Int { fullScreen ? min(8, max(1, data.count)) : min(4, max(1, data.count)) }
    private let legendReserved: CGFloat = 26
    private var chartHeight: CGFloat {
        if fullScreen {
            return max(110, height - legendReserved - 20)
        }
        return max(140, height - legendReserved)
    }

    private enum RoeRoaYAxisScale {
        static let topRatio: Double = 0.12
        private static let niceStep: Double = 10

        static func domain(values: [Double]) -> ClosedRange<Double> {
            guard !values.isEmpty else { return 0 ... 1 }
            let maxV = values.max()!
            let padded = maxV * (1.0 + topRatio)
            let upperRounded = ceil(padded / niceStep) * niceStep
            let upper = max(upperRounded, maxV + 1)
            return 0 ... upper
        }
    }

    private var roeRoaYScaleDomain: ClosedRange<Double> {
        let values = data.flatMap { [$0.roe, $0.roa].compactMap { $0 } }
        return RoeRoaYAxisScale.domain(values: values)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { idx, d in
                    let label = labels[idx]
                    if let roe = d.roe {
                        LineMark(x: .value("Kỳ", label), y: .value("ROE", roe))
                            .foregroundStyle(by: .value("Chỉ số", "ROE"))
                        PointMark(x: .value("Kỳ", label), y: .value("ROE", roe))
                            .foregroundStyle(by: .value("Chỉ số", "ROE"))
                    }
                    if let roa = d.roa {
                        LineMark(x: .value("Kỳ", label), y: .value("ROA", roa))
                            .foregroundStyle(by: .value("Chỉ số", "ROA"))
                        PointMark(x: .value("Kỳ", label), y: .value("ROA", roa))
                            .foregroundStyle(by: .value("Chỉ số", "ROA"))
                    }
                }
            }
            .chartForegroundStyleScale(["ROE": AppColors.chartGrowthStrong, "ROA": AppColors.chartCapitalDeposits])
            .chartYScale(domain: roeRoaYScaleDomain)
            .id("roeRoaY-\(roeRoaYScaleDomain.lowerBound)-\(roeRoaYScaleDomain.upperBound)")
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: fullScreen ? 6 : 4)) {
                    AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                    AxisValueLabel().font(AppTypography.caption2)
                }
            }
            .chartLegend(.hidden)
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: visibleLength)
            .chartScrollPosition(x: $scrollLabel)
            .onAppear {
                if scrollLabel.isEmpty {
                    scrollLabel = recentScrollStartLabel(labels: labels, visibleLength: visibleLength)
                }
            }
            .chartXSelection(value: $selectedLabel)
            .onChange(of: selectedLabel) { _, newValue in
                displayedLabel = newValue
            }
            .padding(.top, fullScreen ? -Spacing.sm : 0)
            .frame(height: chartHeight)

            HStack(spacing: Spacing.md) {
                chartLegendItem("ROE", color: AppColors.chartGrowthStrong)
                chartLegendItem("ROA", color: AppColors.chartCapitalDeposits)
            }
            .frame(height: legendReserved, alignment: .leading)
        }
        .overlay(alignment: .topTrailing) {
            if fullScreen, let label = displayedLabel, let idx = labels.firstIndex(of: label), data.indices.contains(idx) {
                let item = data[idx]
                let metrics = [
                    item.roe.map { roe in
                        ChartPopoverMetric(
                            id: "roe",
                            label: "ROE",
                            value: String(format: "%.2f%%", roe),
                            color: AppColors.chartGrowthStrong
                        )
                    },
                    item.roa.map { roa in
                        ChartPopoverMetric(
                            id: "roa",
                            label: "ROA",
                            value: String(format: "%.2f%%", roa),
                            color: AppColors.chartCapitalDeposits
                        )
                    },
                ].compactMap { $0 }
                nativeSelectionDetails(title: label, subtitle: "ROE & ROA", metrics: metrics)
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
