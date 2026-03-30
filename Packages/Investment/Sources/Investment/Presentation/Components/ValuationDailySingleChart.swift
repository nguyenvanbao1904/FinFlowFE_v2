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

struct ValuationDailySingleChart: View {
    let title: String
    let current: Double
    let rangeMedian: Double?
    let rangeMean: Double?
    let data: [DailyValuationDataPoint]
    let metric: KeyPath<DailyValuationDataPoint, Double?>
    let lineColor: Color
    let onRequestFullHistory: (() -> Void)?
    /// Gợi ý dưới tiêu đề (ví dụ giải thích P/S ngân hàng).
    let headlineNote: String?
    /// Thay thế copy mặc định khi không có điểm trên chart.
    let emptyChartMessage: String?

    @State private var scrollPositionDate: Date = .distantPast
    @State private var showFullscreen = false
    @State private var selectedChartDate: Date?
    @State private var displayedChartDate: Date?
    @State private var xAxisZoom: CGFloat = 1
    @State private var yAxisZoom: CGFloat = 1
    @GestureState private var pinchMagnification: CGFloat = 1

    private var liveXAxisZoom: CGFloat {
        ValuationChartAxisZoom.clamp(xAxisZoom * pinchMagnification)
    }

    private var liveYAxisZoom: CGFloat {
        ValuationChartAxisZoom.clamp(yAxisZoom * pinchMagnification)
    }

    private static let dayLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
        f.calendar = cal
        f.timeZone = cal.timeZone
        f.dateFormat = "dd/MM/yy"
        return f
    }()

    private static var vnCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
        return c
    }

    private static let secondsPerDay: TimeInterval = 86_400

    /// Điểm vẽ: trục X dùng `Date` để Swift Charts gom nhãn thời gian (tránh hàng trăm nhãn chuỗi).
    private var plotPoints: [(date: Date, value: Double)] {
        data.compactMap { p -> (Date, Double)? in
            guard let v = p[keyPath: metric], v.isFinite,
                let d = parseDailyChartDate(p.date)
            else { return nil }
            return (d, v)
        }
        .sorted { $0.0 < $1.0 }
        .map { (date: $0.0, value: $0.1) }
    }

    private var plotSpanDays: Int {
        guard let f = plotPoints.first?.date, let l = plotPoints.last?.date else { return 1 }
        return max(1, Int(ceil(l.timeIntervalSince(f) / Self.secondsPerDay)) + 1)
    }

    /// Số ngày hiển thị cùng lúc (cửa sổ cuộn ngang).
    private func visibleDaySpan(fullScreen: Bool) -> Int {
        let n = plotPoints.count
        guard n > 0 else { return 30 }
        if fullScreen {
            return min(n, max(60, min(240, n * 2 / 5)))
        }
        return min(n, max(30, min(120, n / 4)))
    }

    private func effectiveVisibleDays(fullScreen: Bool) -> Int {
        let n = plotPoints.count
        guard n > 0 else { return 1 }
        let base = visibleDaySpan(fullScreen: fullScreen)
        let z = max(Double(liveXAxisZoom), 0.01)
        let scaled = Int(round(Double(base) / z))
        return max(1, min(plotSpanDays, max(1, scaled)))
    }

    private func scrollLeadingDate(visibleDays: Int) -> Date {
        guard let first = plotPoints.first?.date, let last = plotPoints.last?.date else {
            return Date()
        }
        let window = TimeInterval(visibleDays) * Self.secondsPerDay
        let start = last.addingTimeInterval(-window)
        return start < first ? first : start
    }

    private var yDomain: ClosedRange<Double> {
        valuationChartYDomain(
            seriesValues: plotPoints.map(\.value),
            rangeMedian: rangeMedian,
            rangeMean: rangeMean,
            current: current,
            liveYZoom: liveYAxisZoom
        )
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
                    isZoomed: abs(xAxisZoom - 1) > 0.04 || abs(yAxisZoom - 1) > 0.04,
                    onReset: {
                        xAxisZoom = 1
                        yAxisZoom = 1
                        scrollPositionDate = scrollLeadingDate(
                            visibleDays: effectiveVisibleDays(fullScreen: false)
                        )
                    },
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

            if plotPoints.isEmpty {
                Text(emptyChartMessage ?? "Không có điểm dữ liệu trong khoảng thời gian đã chọn.")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.chartHeight)
                    .background(AppColors.cardBackground.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            } else {
                chart(fullScreen: false)
                    .frame(height: Layout.chartHeight)
                    .valuationChartZoomAnimations(
                        xAxisZoom: xAxisZoom,
                        yAxisZoom: yAxisZoom,
                        pinchMagnification: pinchMagnification
                    )
            }

            Text(
                "Theo ngày giao dịch; ngày thiếu chỉ số bỏ qua; vuốt ngang để xem thêm. Chụm hai ngón: phóng/thu thời gian và giá trị. ↺ đặt lại."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(Spacing.lg)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .onChange(of: selectedChartDate) { _, newValue in
            displayedChartDate = newValue
        }
        .onChange(of: data.count) { _, _ in
            xAxisZoom = 1
            yAxisZoom = 1
            scrollPositionDate = .distantPast
        }
        .fullScreenCover(isPresented: $showFullscreen) {
            ChartFullscreenContainer(title: title) {
                ValuationFullscreenChartHost(
                    xAxisZoom: xAxisZoom,
                    yAxisZoom: yAxisZoom,
                    pinchMagnification: pinchMagnification
                ) {
                    chart(fullScreen: true)
                }
            }
        }
    }

    private func chart(fullScreen: Bool) -> some View {
        let visibleDays = effectiveVisibleDays(fullScreen: fullScreen)
        let domainLength = TimeInterval(visibleDays) * Self.secondsPerDay
        let densePoints = plotPoints.count > 100
        let pointSize: CGFloat = densePoints ? 6 : 18
        // Nhiều nhãn hơn một chút nhưng vẫn an toàn (trục Date + stride).
        let autoLabelCount = fullScreen ? 14 : 10

        return ZStack(alignment: .top) {
            let baseChart = Chart {
                if let mean = rangeMean, mean.isFinite {
                    RuleMark(y: .value("TB", mean))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .foregroundStyle(Color.purple)
                        .annotation(position: .leading, alignment: .trailing) {
                            Text("TB")
                                .font(.caption2)
                                .foregroundStyle(Color.purple)
                        }
                }
                if let median = rangeMedian {
                    RuleMark(y: .value("Trung vị", median))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        .foregroundStyle(.orange)
                        .annotation(position: .trailing, alignment: .leading) {
                            Text("Trung vị")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                }

                ForEach(Array(plotPoints.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value("Ngày", point.date),
                        y: .value("Chỉ số", point.value)
                    )
                    .foregroundStyle(lineColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.monotone)

                    PointMark(
                        x: .value("Ngày", point.date),
                        y: .value("Chỉ số", point.value)
                    )
                    .foregroundStyle(lineColor)
                    .symbolSize(pointSize)
                }
            }
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: domainLength)
            .chartScrollPosition(x: $scrollPositionDate)
            .onAppear {
                if scrollPositionDate == .distantPast {
                    scrollPositionDate = scrollLeadingDate(visibleDays: visibleDays)
                }
            }
            .chartXAxis {
                if plotSpanDays <= 126 {
                    // ~≤4 tháng: để Charts tự chia, nhiều mốc hơn (có chỗ dưới chart).
                    AxisMarks(
                        values: .automatic(
                            desiredCount: autoLabelCount,
                            roundLowerBound: true,
                            roundUpperBound: true
                        )
                    ) { value in
                        AxisGridLine().foregroundStyle(.gray.opacity(0.1))
                        AxisValueLabel(centered: false) {
                            if let d = value.as(Date.self) {
                                Text(Self.dayLabelFormatter.string(from: d))
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                    }
                } else if plotSpanDays <= 400 {
                    AxisMarks(values: .stride(by: .month, count: 1, calendar: Self.vnCalendar)) { value in
                        AxisGridLine().foregroundStyle(.gray.opacity(0.1))
                        AxisValueLabel(centered: false) {
                            if let d = value.as(Date.self) {
                                Text(d, format: .dateTime.day().month(.abbreviated))
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                    }
                } else if plotSpanDays <= 720 {
                    AxisMarks(values: .stride(by: .month, count: 2, calendar: Self.vnCalendar)) { value in
                        AxisGridLine().foregroundStyle(.gray.opacity(0.1))
                        AxisValueLabel(centered: false) {
                            if let d = value.as(Date.self) {
                                Text(d, format: .dateTime.month(.abbreviated).year(.twoDigits))
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                        }
                    }
                } else if plotSpanDays <= 1080 {
                    AxisMarks(values: .stride(by: .month, count: 3, calendar: Self.vnCalendar)) { value in
                        AxisGridLine().foregroundStyle(.gray.opacity(0.1))
                        AxisValueLabel(centered: false) {
                            if let d = value.as(Date.self) {
                                Text(d, format: .dateTime.month(.abbreviated).year(.twoDigits))
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                        }
                    }
                } else if plotSpanDays <= 1500 {
                    AxisMarks(values: .stride(by: .month, count: 6, calendar: Self.vnCalendar)) { value in
                        AxisGridLine().foregroundStyle(.gray.opacity(0.1))
                        AxisValueLabel(centered: false) {
                            if let d = value.as(Date.self) {
                                Text(d, format: .dateTime.month(.abbreviated).year(.twoDigits))
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                        }
                    }
                } else {
                    AxisMarks(values: .stride(by: .month, count: 12, calendar: Self.vnCalendar)) { value in
                        AxisGridLine().foregroundStyle(.gray.opacity(0.1))
                        AxisValueLabel(centered: false) {
                            if let d = value.as(Date.self) {
                                Text(d, format: .dateTime.month(.abbreviated).year(.twoDigits))
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
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
            .chartYScale(domain: yDomain)
            .chartLegend(position: .top) {
                HStack(spacing: Spacing.sm) {
                    HStack(spacing: Spacing.xs) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(lineColor)
                            .frame(width: 12, height: 3)
                        Text(title.replacingOccurrences(of: "Định giá ", with: ""))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if rangeMedian != nil {
                        HStack(spacing: Spacing.xs) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(.orange)
                                .frame(width: 12, height: 1)
                            Text("Trung vị (khoảng)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if rangeMean != nil {
                        HStack(spacing: Spacing.xs) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.purple)
                                .frame(width: 12, height: 1)
                            Text("TB (khoảng)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if fullScreen {
                baseChart.chartXSelection(value: $selectedChartDate)
            } else {
                baseChart
            }

            if fullScreen, let picked = displayedChartDate {
                dailySelectionPopover(for: picked)
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.xs)
            }
        }
        .simultaneousGesture(
            valuationPinchGesture(
                pinch: $pinchMagnification,
                xAxisZoom: $xAxisZoom,
                yAxisZoom: $yAxisZoom,
                onXZoomCommitted: {
                    scrollPositionDate = scrollLeadingDate(
                        visibleDays: effectiveVisibleDays(fullScreen: showFullscreen)
                    )
                }
            )
        )
    }

    private func dailySelectionPopover(for date: Date) -> some View {
        guard let match = nearestPlotPoint(to: date) else {
            return AnyView(EmptyView())
        }
        let value = match.value
        let label = Self.dayLabelFormatter.string(from: match.date)

        var metrics: [ChartPopoverMetric] = [
            ChartPopoverMetric(
                id: "current",
                label: "Giá trị",
                value: String(format: "%.2f", value),
                color: lineColor
            ),
        ]
        if let m = rangeMedian {
            metrics.append(
                ChartPopoverMetric(
                    id: "median",
                    label: "Trung vị (trong khoảng)",
                    value: String(format: "%.2f", m),
                    color: .orange
                ))
        }
        if let a = rangeMean, a.isFinite {
            metrics.append(
                ChartPopoverMetric(
                    id: "mean",
                    label: "Trung bình (trong khoảng)",
                    value: String(format: "%.2f", a),
                    color: .purple
                ))
        }

        return AnyView(
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(metrics, id: \.id) { metric in
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(metric.color)
                            .frame(width: 6, height: 6)
                        Text(metric.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Text(metric.value)
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                }
            }
            .padding(Spacing.sm)
            .background(AppColors.appBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        )
    }

    private func nearestPlotPoint(to date: Date) -> (date: Date, value: Double)? {
        guard !plotPoints.isEmpty else { return nil }
        let cal = Self.vnCalendar
        if let sameDay = plotPoints.first(where: { cal.isDate($0.date, inSameDayAs: date) }) {
            return (sameDay.date, sameDay.value)
        }
        return plotPoints.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }
}
