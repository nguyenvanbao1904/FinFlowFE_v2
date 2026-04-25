import Charts
import FinFlowCore
import SwiftUI

// MARK: - Valuation Chart Support Views

private enum ValuationChartFullscreenLayout {
    static let landscapeHeightTrim: CGFloat = 64
}

private struct ValuationChartZoomToolbar: View {
    var isZoomed: Bool
    var onReset: () -> Void
    var onFullscreen: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if isZoomed {
                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(AppTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.primary)
                        .frame(width: UILayout.toolbarButton, height: UILayout.toolbarButton)
                        .background(AppColors.primary.opacity(OpacityLevel.ultraLight))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Đặt lại thu phóng chart")
            }
            Button(action: onFullscreen) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(AppTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.primary)
                    .frame(width: UILayout.toolbarButton, height: UILayout.toolbarButton)
                    .background(AppColors.primary.opacity(OpacityLevel.ultraLight))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Phóng to biểu đồ")
        }
    }
}

private struct ValuationMedianMeanComparisonBadge: View {
    let current: Double
    let rangeMedian: Double?
    let rangeMean: Double?

    private var diff: Double? {
        guard let m = rangeMedian, m != 0 else { return nil }
        return current - m
    }

    private var pct: Double? {
        guard let d = diff, let m = rangeMedian, m != 0 else { return nil }
        return abs(d) / m * 100
    }

    var body: some View {
        if let median = rangeMedian, let pct {
            let isLower = (diff ?? 0) <= 0
            let text =
                pct < 1
                ? "≈ Trung vị (trong khoảng)"
                : "\(isLower ? "thấp hơn" : "cao hơn") \(String(format: "%.1f%%", pct)) so với trung vị \(String(format: "%.2f", median))"
            let color: Color = pct < 1 ? .secondary : (isLower ? AppColors.success : AppColors.expense)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(text)
                    .font(AppTypography.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(color)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, Spacing.xs)
                    .background(color.opacity(OpacityLevel.cardSubtleMedium))
                    .clipShape(Capsule())
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let mean = rangeMean, mean.isFinite, mean > 0 {
                    let dMean = current - mean
                    let pMean = abs(dMean) / mean * 100
                    let lowerMean = dMean <= 0
                    let (textMean, colorMean): (String, Color) = {
                        if pMean < 5 {
                            let t =
                                pMean < 1
                                ? "≈ Trung bình (trong khoảng, đường tím)"
                                : "Gần TB \(String(format: "%.1f%%", pMean)) so với \(String(format: "%.2f", mean))"
                            return (t, AppColors.chartGrowthStable)
                        }
                        let t =
                            "\(lowerMean ? "thấp hơn" : "cao hơn") \(String(format: "%.1f%%", pMean)) so với TB \(String(format: "%.2f", mean))"
                        return (t, lowerMean ? AppColors.success : AppColors.expense)
                    }()
                    Text(textMean)
                        .font(AppTypography.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(colorMean)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xs)
                        .background(colorMean.opacity(0.12))
                        .clipShape(Capsule())
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
        } else {
            Text("Chưa có trung vị trong khoảng (không đủ dữ liệu hoặc giá trị không hợp lệ).")
                .font(AppTypography.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xs)
                .background(Color.secondary.opacity(OpacityLevel.cardSubtle))
                .clipShape(Capsule())
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
    }
}

private struct ValuationFullscreenChartHost<Content: View>: View {
    var xAxisZoom: CGFloat
    var yAxisZoom: CGFloat
    var pinchMagnification: CGFloat
    @ViewBuilder var chart: () -> Content

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            let baseHeight = ChartFullscreenSupport.preferredChartHeight(for: proxy.size)
            let adjustedHeight = isLandscape
                ? max(Layout.chartHeight, baseHeight - ValuationChartFullscreenLayout.landscapeHeightTrim)
                : baseHeight
            VStack(spacing: Spacing.md) {
                chart()
                    .frame(maxWidth: .infinity)
                    .frame(height: adjustedHeight)
                    .valuationChartZoomAnimations(
                        xAxisZoom: xAxisZoom,
                        yAxisZoom: yAxisZoom,
                        pinchMagnification: pinchMagnification
                    )
                    .padding(Spacing.md)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            }
            .padding(.bottom, isLandscape ? Spacing.md : 0)
        }
    }
}

// MARK: - Configuration

/// Unified single-line valuation chart that replaces both
/// `ValuationSingleChart` (quarterly/annual) and `ValuationDailySingleChart` (daily).
struct ValuationLineChart<DataElement: Equatable>: View {

    struct Config {
        /// How many points fit the normal (non-fullscreen) viewport.
        var normalVisibleRange: ClosedRange<Int> = 4...6
        /// How many points fit fullscreen.
        var fullscreenVisibleRange: ClosedRange<Int> = 8...Int.max
        /// Below this count, individual point marks are drawn.
        var pointMarkThreshold: Int = 12
        /// Size of point mark symbols.
        var symbolSize: CGFloat = 18
        /// Max rendered points (stride-sample when exceeded). `nil` = no sampling.
        var maxRenderedPoints: Int?
        /// Footer text shown below the chart.
        var footerNote: String?
        /// Message when chart data is empty.
        var emptyMessage: String = "Không có điểm dữ liệu trong khoảng thời gian đã chọn."

        static var quarterly: Config {
            Config(
                normalVisibleRange: 4...6,
                fullscreenVisibleRange: 8...Int.max,
                pointMarkThreshold: 12,
                symbolSize: 18,
                footerNote: nil
            )
        }

        static var daily: Config {
            Config(
                normalVisibleRange: 45...45,
                fullscreenVisibleRange: 90...Int.max,
                pointMarkThreshold: 45,
                symbolSize: 14,
                maxRenderedPoints: 220,
                footerNote: "Bản rút gọn để ưu tiên độ mượt: chỉ giữ kéo ngang và line chart. Muốn \"zoom\" thì đổi khoảng ở bộ chọn phía trên."
            )
        }
    }

    // MARK: - Rendered point

    private struct RenderedPoint: Identifiable {
        let id: Int
        let label: String
        let value: Double
    }

    // MARK: - Properties

    private static var lineSeriesLabel: String { "Lịch sử" }

    let title: String
    let current: Double
    let rangeMedian: Double?
    let rangeMean: Double?
    let data: [DataElement]
    let lineColor: Color
    let onRequestFullHistory: (() -> Void)?
    let headlineNote: String?
    let config: Config

    /// Converts `(offset, element)` → `(label, value)?`. Return `nil` to skip.
    let pointBuilder: (Int, DataElement) -> (label: String, value: Double)?

    @State private var scrollPosition: Int = 0
    @State private var points: [RenderedPoint] = []
    @State private var seriesValues: [Double] = []
    @State private var showFullscreen = false

    // MARK: - Derived

    private var plotPointCount: Int { points.count }

    private var displayPoints: [RenderedPoint] {
        guard let max = config.maxRenderedPoints else { return points }
        return strideSample(points, maxPoints: max)
    }

    private var visibleLength: Int { visibleLength(fullScreen: false) }

    private func visibleLength(fullScreen: Bool) -> Int {
        let range = fullScreen ? config.fullscreenVisibleRange : config.normalVisibleRange
        let preferred = fullScreen
            ? max(range.lowerBound, plotPointCount / (config.maxRenderedPoints != nil ? 3 : 2))
            : (plotPointCount >= 8 ? range.upperBound : plotPointCount)
        return min(max(range.lowerBound, preferred), max(plotPointCount, 1))
    }

    private var yDomain: ClosedRange<Double> {
        valuationChartYDomain(seriesValues: seriesValues, rangeMedian: rangeMedian, rangeMean: rangeMean, current: current, yAxisZoom: 1)
    }

    private func xAxisValues(fullScreen: Bool) -> [Int] {
        valuationXAxisValues(pointCount: points.count, fullScreen: fullScreen)
    }

    private var showPointMarks: Bool { displayPoints.count <= config.pointMarkThreshold }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header
            medianMeanBadge

            if displayPoints.isEmpty {
                emptyState
            } else {
                chart.frame(height: Layout.chartHeight)
            }

            footer
        }
        .padding(Spacing.lg)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .onAppear { rebuildPoints(); resetScrollPosition() }
        .onChange(of: data) { _, _ in rebuildPoints(); resetScrollPosition() }
        .onChange(of: data.count) { _, _ in resetScrollPosition() }
        .fullScreenCover(isPresented: $showFullscreen) {
            ChartFullscreenContainer(title: title) {
                ValuationFullscreenChartHost(xAxisZoom: 1, yAxisZoom: 1, pinchMagnification: 1) {
                    chart(fullScreen: true)
                }
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title).font(AppTypography.headline)
                Text(String(format: "%.2f", current)).font(AppTypography.title).fontWeight(.bold)
                if let headlineNote {
                    Text(headlineNote).font(AppTypography.caption2).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            ValuationChartZoomToolbar(isZoomed: false, onReset: {}, onFullscreen: {
                onRequestFullHistory?()
                showFullscreen = true
            })
        }
    }

    private var medianMeanBadge: some View {
        HStack {
            ValuationMedianMeanComparisonBadge(current: current, rangeMedian: rangeMedian, rangeMean: rangeMean)
            Spacer(minLength: 0)
        }
    }

    private var emptyState: some View {
        Text(config.emptyMessage)
            .font(AppTypography.caption).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity).frame(height: Layout.chartHeight)
            .background(AppColors.cardBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    private var footer: some View {
        Text(config.footerNote ?? "Theo năm (ngày cuối năm); vuốt ngang để xem thêm. Muốn \"zoom\" thì dùng bộ chọn khoảng phía trên.")
            .font(AppTypography.caption2).foregroundStyle(.secondary)
    }

    // MARK: - Chart

    private var chart: some View { chart(fullScreen: false) }

    private func chart(fullScreen: Bool) -> some View {
        Chart {
            if let mean = rangeMean, mean.isFinite,
               valuationReferenceLineFitsSeries(value: mean, seriesValues: seriesValues) {
                RuleMark(y: .value("TB", mean))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .foregroundStyle(AppColors.chartMeanLine)
            }
            if let median = rangeMedian,
               valuationReferenceLineFitsSeries(value: median, seriesValues: seriesValues) {
                RuleMark(y: .value("Trung vị", median))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    .foregroundStyle(AppColors.chartMedianLine)
            }
            ForEach(displayPoints) { point in
                LineMark(
                    x: .value("Index", point.id),
                    y: .value("Chỉ số", point.value),
                    series: .value("Chuỗi", Self.lineSeriesLabel)
                )
                .foregroundStyle(lineColor).lineStyle(StrokeStyle(lineWidth: 2)).interpolationMethod(.linear)
                if showPointMarks {
                    PointMark(x: .value("Index", point.id), y: .value("Chỉ số", point.value))
                        .foregroundStyle(lineColor).symbolSize(config.symbolSize)
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
                AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                AxisValueLabel {
                    if let index = value.as(Int.self), points.indices.contains(index) {
                        Text(points[index].label).font(fullScreen ? .caption : .caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(AppColors.chartGridLine)
                AxisValueLabel()
            }
        }
    }

    // MARK: - Helpers

    private func rebuildPoints() {
        let rebuilt: [RenderedPoint] = data.enumerated().compactMap { offset, element in
            guard let pair = pointBuilder(offset, element) else { return nil }
            return RenderedPoint(id: offset, label: pair.label, value: pair.value)
        }
        points = rebuilt
        seriesValues = rebuilt.map(\.value)
    }

    private func resetScrollPosition() {
        scrollPosition = valuationInitialScrollPosition(pointCount: points.count, visibleLength: visibleLength)
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

// MARK: - Convenience Initializers

extension ValuationLineChart where DataElement == ValuationDataPoint {
    /// Quarterly / Annual valuation chart (replaces `ValuationSingleChart`).
    init(
        title: String,
        current: Double,
        rangeMedian: Double?,
        rangeMean: Double?,
        data: [ValuationDataPoint],
        valueKeyPath: KeyPath<ValuationDataPoint, Double>,
        lineColor: Color,
        showQuarterly: Bool,
        onRequestFullHistory: (() -> Void)?
    ) {
        self.title = title
        self.current = current
        self.rangeMedian = rangeMedian
        self.rangeMean = rangeMean
        self.data = data
        self.lineColor = lineColor
        self.onRequestFullHistory = onRequestFullHistory
        self.headlineNote = nil
        var cfg = Config.quarterly
        cfg.footerNote = showQuarterly
            ? "Biểu đồ tối giản để ưu tiên độ mượt; vuốt ngang để xem thêm. Muốn \"zoom\" thì dùng bộ chọn khoảng phía trên."
            : nil // uses default "Theo năm..."
        self.config = cfg
        self.pointBuilder = { _, point in
            let label: String
            if showQuarterly {
                let yy = String(format: "%02d", point.year % 100)
                label = "Q\(point.quarter) \(yy)"
            } else {
                label = String(point.year)
            }
            return (label, point[keyPath: valueKeyPath])
        }
    }
}

extension ValuationLineChart where DataElement == DailyValuationDataPoint {

    private static var dayLabelFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
        formatter.dateFormat = "dd/MM/yy"
        return formatter
    }

    /// Daily valuation chart (replaces `ValuationDailySingleChart`).
    init(
        title: String,
        current: Double,
        rangeMedian: Double?,
        rangeMean: Double?,
        data: [DailyValuationDataPoint],
        metric: KeyPath<DailyValuationDataPoint, Double?>,
        lineColor: Color,
        onRequestFullHistory: (() -> Void)?,
        headlineNote: String?,
        emptyChartMessage: String?
    ) {
        self.title = title
        self.current = current
        self.rangeMedian = rangeMedian
        self.rangeMean = rangeMean
        self.data = data
        self.lineColor = lineColor
        self.onRequestFullHistory = onRequestFullHistory
        self.headlineNote = headlineNote
        var cfg = Config.daily
        if let msg = emptyChartMessage { cfg.emptyMessage = msg }
        self.config = cfg
        let fmt = Self.dayLabelFormatter
        self.pointBuilder = { _, point in
            guard let value = point[keyPath: metric], value.isFinite,
                  let date = parseDailyChartDate(point.date)
            else { return nil }
            return (fmt.string(from: date), value)
        }
    }
}
