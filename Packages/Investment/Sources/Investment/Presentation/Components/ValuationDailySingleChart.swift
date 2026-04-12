import Charts
import FinFlowCore
import SwiftUI

private func parseDailyChartDate(_ isoDay: String) -> Date? {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
    let parts = isoDay.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    return cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
}

private struct ValuationDailyRenderedPoint: Identifiable {
    let id: Int
    let label: String
    let value: Double
}

struct ValuationDailySingleChart: View {
    private static let lineSeriesLabel = "Lịch sử"

    private static let dayLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
        formatter.dateFormat = "dd/MM/yy"
        return formatter
    }()

    let title: String
    let current: Double
    let rangeMedian: Double?
    let rangeMean: Double?
    let data: [DailyValuationDataPoint]
    let metric: KeyPath<DailyValuationDataPoint, Double?>
    let lineColor: Color
    let onRequestFullHistory: (() -> Void)?
    let headlineNote: String?
    let emptyChartMessage: String?

    @State private var scrollPosition: Int = 0
    @State private var points: [ValuationDailyRenderedPoint] = []
    @State private var seriesValues: [Double] = []
    @State private var showFullscreen = false

    private var plotPointCount: Int {
        points.count
    }

    private var renderedPoints: [ValuationDailyRenderedPoint] {
        strideSample(points, maxPoints: 220)
    }

    private var visibleLength: Int {
        visibleLength(fullScreen: false)
    }

    private func visibleLength(fullScreen: Bool) -> Int {
        if fullScreen {
            return min(max(90, plotPointCount / 3), max(plotPointCount, 1))
        }
        return min(max(45, plotPointCount / 4), max(plotPointCount, 1))
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

    private var yDomain: ClosedRange<Double> {
        valuationChartYDomain(
            seriesValues: seriesValues,
            rangeMedian: rangeMedian,
            rangeMean: rangeMean,
            current: current,
            yAxisZoom: 1
        )
    }

    private var showPointMarks: Bool {
        renderedPoints.count <= 45
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
                    if let headlineNote {
                        Text(headlineNote)
                            .font(AppTypography.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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

            if renderedPoints.isEmpty {
                Text(emptyChartMessage ?? "Không có điểm dữ liệu trong khoảng thời gian đã chọn.")
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
                "Bản rút gọn để ưu tiên độ mượt: chỉ giữ kéo ngang và line chart. Muốn \"zoom\" thì đổi khoảng ở bộ chọn phía trên."
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

            ForEach(renderedPoints) { point in
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
                    .symbolSize(14)
                }
            }
        }
        .transaction { $0.animation = nil }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: visibleLength(fullScreen: fullScreen))
        .chartScrollPosition(x: $scrollPosition)
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

    private func rebuildPoints() {
        let rebuilt = data.enumerated().compactMap { offset, point -> ValuationDailyRenderedPoint? in
            guard let value = point[keyPath: metric], value.isFinite, let date = parseDailyChartDate(point.date) else {
                return nil
            }
            return ValuationDailyRenderedPoint(
                id: offset,
                label: Self.dayLabelFormatter.string(from: date),
                value: value
            )
        }
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

    private func strideSample<T>(_ values: [T], maxPoints: Int) -> [T] {
        guard values.count > maxPoints, maxPoints > 1 else { return values }
        let stride = max(1, Int(ceil(Double(values.count) / Double(maxPoints))))
        var sampled: [T] = []
        sampled.reserveCapacity((values.count / stride) + 2)
        var lastAppendedIndex: Int?
        for index in Swift.stride(from: 0, to: values.count, by: stride) {
            sampled.append(values[index])
            lastAppendedIndex = index
        }
        if let last = values.last, lastAppendedIndex != values.count - 1 {
            sampled.append(last)
        }
        return sampled
    }
}
