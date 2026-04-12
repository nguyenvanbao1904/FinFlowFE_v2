import Charts
import FinFlowCore
import SwiftUI

struct ValuationSingleChart: View {
    private static let lineSeriesLabel = "Lịch sử"

    private struct IndexedPoint: Identifiable {
        let id: Int
        let label: String
        let value: Double
    }

    let title: String
    let current: Double
    let rangeMedian: Double?
    let rangeMean: Double?
    let data: [ValuationDataPoint]
    let valueKeyPath: KeyPath<ValuationDataPoint, Double>
    let lineColor: Color
    let showQuarterly: Bool
    let onRequestFullHistory: (() -> Void)?
    let footerNote: String? = nil

    @State private var scrollPosition: Int = 0
    @State private var points: [IndexedPoint] = []
    @State private var seriesValues: [Double] = []
    @State private var showFullscreen = false

    private var plotPointCount: Int {
        points.count
    }

    private var rebuiltPoints: [IndexedPoint] {
        data.enumerated().map { index, point in
            IndexedPoint(
                id: index,
                label: xAxisPeriodLabel(for: point),
                value: point[keyPath: valueKeyPath]
            )
        }
    }

    private var visibleLength: Int {
        visibleLength(fullScreen: false)
    }

    private func visibleLength(fullScreen: Bool) -> Int {
        if fullScreen {
            return min(max(8, plotPointCount / 2), max(plotPointCount, 1))
        }
        return min(max(4, plotPointCount >= 8 ? 6 : plotPointCount), max(plotPointCount, 1))
    }

    private var yDomain: ClosedRange<Double> {
        valuationChartYDomain(
            seriesValues: seriesValues,
            rangeMedian: rangeMedian,
            rangeMean: rangeMean,
            current: current,
            yAxisZoom: 1
        )
    }

    private var xAxisValues: [Int] {
        xAxisValues(fullScreen: false)
    }

    private func xAxisValues(fullScreen: Bool) -> [Int] {
        guard !points.isEmpty else { return [] }
        let targetLabelCount = fullScreen ? 8 : 5
        if points.count <= targetLabelCount {
            return points.map(\.id)
        }
        let stride = max(1, Int(ceil(Double(points.count - 1) / Double(max(targetLabelCount - 1, 1)))))
        var values = Array(Swift.stride(from: 0, to: points.count, by: stride))
        if values.last != points.count - 1 {
            values.append(points.count - 1)
        }
        return values
    }

    private var showPointMarks: Bool {
        points.count <= 12
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(AppTypography.headline)
                    Text(String(format: "%.2f", current))
                        .font(AppTypography.title)
                        .fontWeight(.bold)
                }
                Spacer()
                ValuationChartZoomToolbar(
                    isZoomed: false,
                    onReset: {},
                    onFullscreen: {
                        onRequestFullHistory?()
                        showFullscreen = true
                    }
                )
            }

            HStack {
                ValuationMedianMeanComparisonBadge(
                    current: current,
                    rangeMedian: rangeMedian,
                    rangeMean: rangeMean
                )
                Spacer(minLength: 0)
            }

            if points.isEmpty {
                Text("Không có điểm dữ liệu trong khoảng thời gian đã chọn.")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.chartHeight)
                    .background(AppColors.cardBackground.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            } else {
                chart
                    .frame(height: Layout.chartHeight)
            }

            Text(
                (footerNote
                    ?? (showQuarterly
                        ? "Biểu đồ tối giản để ưu tiên độ mượt; vuốt ngang để xem thêm."
                        : "Theo năm (ngày cuối năm); vuốt ngang để xem thêm."))
                    + " Muốn \"zoom\" thì dùng bộ chọn khoảng phía trên."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(Spacing.lg)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .onAppear {
            rebuildPoints()
            resetScrollPosition()
        }
        .onChange(of: data) { _, _ in
            rebuildPoints()
            resetScrollPosition()
        }
        .onChange(of: data.count) { _, _ in
            resetScrollPosition()
        }
        .fullScreenCover(isPresented: $showFullscreen) {
            ChartFullscreenContainer(title: title) {
                ValuationFullscreenChartHost(
                    xAxisZoom: 1,
                    yAxisZoom: 1,
                    pinchMagnification: 1
                ) {
                    chart(fullScreen: true)
                }
            }
        }
    }

    private var chart: some View {
        chart(fullScreen: false)
    }

    private func chart(fullScreen: Bool) -> some View {
        Chart {
            if let mean = rangeMean, mean.isFinite,
                valuationReferenceLineFitsSeries(value: mean, seriesValues: seriesValues)
            {
                RuleMark(y: .value("TB", mean))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .foregroundStyle(Color.purple)
            }

            if let median = rangeMedian,
                valuationReferenceLineFitsSeries(value: median, seriesValues: seriesValues)
            {
                RuleMark(y: .value("Trung vị", median))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    .foregroundStyle(.orange)
            }

            ForEach(points) { point in
                LineMark(
                    x: .value("Index", point.id),
                    y: .value("Chỉ số", point.value),
                    series: .value("Chuỗi", Self.lineSeriesLabel)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.linear)

                if showPointMarks {
                    PointMark(
                        x: .value("Index", point.id),
                        y: .value("Chỉ số", point.value)
                    )
                    .foregroundStyle(lineColor)
                    .symbolSize(18)
                }
            }
        }
        .transaction { $0.animation = nil }
        .chartScrollableAxes(.horizontal)
        .chartScrollPosition(x: $scrollPosition)
        .chartXVisibleDomain(length: visibleLength(fullScreen: fullScreen))
        .chartYScale(domain: yDomain)
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: xAxisValues(fullScreen: fullScreen)) { value in
                AxisGridLine().foregroundStyle(.gray.opacity(0.1))
                AxisValueLabel {
                    if let index = value.as(Int.self), points.indices.contains(index) {
                        Text(points[index].label)
                            .font(fullScreen ? .caption : .caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(.gray.opacity(0.1))
                AxisValueLabel()
            }
        }
    }

    private func xAxisPeriodLabel(for point: ValuationDataPoint) -> String {
        if showQuarterly {
            let yy = String(format: "%02d", point.year % 100)
            return "Q\(point.quarter) \(yy)"
        }
        return String(point.year)
    }

    private func rebuildPoints() {
        let rebuilt = rebuiltPoints
        points = rebuilt
        seriesValues = rebuilt.map(\.value)
    }

    private func resetScrollPosition() {
        guard !points.isEmpty else {
            scrollPosition = 0
            return
        }
        scrollPosition = max(points.count - visibleLength, 0)
    }
}
