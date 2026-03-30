import Charts
import FinFlowCore
import SwiftUI

struct ValuationSingleChart: View {
    let title: String
    let current: Double
    /// Trung vị các điểm trong khoảng thời gian user chọn (không dùng median từ API).
    let rangeMedian: Double?
    /// Trung bình cộng các điểm trong cùng khoảng.
    let rangeMean: Double?
    let data: [ValuationDataPoint]
    let valueKeyPath: KeyPath<ValuationDataPoint, Double>
    let lineColor: Color
    let showQuarterly: Bool
    let onRequestFullHistory: (() -> Void)?
    /// Khi non-nil thay cho dòng chú thích mặc định dưới biểu đồ.
    let footerNote: String? = nil

    @State private var scrollLabel: String = ""
    @State private var showFullscreen = false
    @State private var selectedLabel: String?
    @State private var displayedLabel: String?
    @State private var hidePopoverTask: Task<Void, Never>?
    /// Trục X: >1 ít điểm hơn trên màn (thu nhỏ cửa sổ thời gian).
    @State private var xAxisZoom: CGFloat = 1
    @State private var yAxisZoom: CGFloat = 1
    @GestureState private var pinchMagnification: CGFloat = 1

    private var liveXAxisZoom: CGFloat {
        ValuationChartAxisZoom.clamp(xAxisZoom * pinchMagnification)
    }

    private var liveYAxisZoom: CGFloat {
        ValuationChartAxisZoom.clamp(yAxisZoom * pinchMagnification)
    }

    private var labels: [String] {
        data.map(xAxisPeriodLabel)
    }

    private var inlineVisibleLength: Int {
        return max(1, min(4, data.count))
    }

    private func effectiveVisibleLength(fullScreen: Bool) -> Int {
        let n = data.count
        guard n > 0 else { return 1 }
        let baseVL = fullScreen ? min(8, max(1, n)) : inlineVisibleLength
        let z = max(Double(liveXAxisZoom), 0.01)
        let scaled = Int(round(Double(baseVL) / z))
        return max(1, min(n, max(1, scaled)))
    }

    private func recentScrollStartLabel(visibleLength: Int) -> String {
        guard !labels.isEmpty else { return "" }
        let startIndex = max(labels.count - visibleLength, 0)
        return labels[startIndex]
    }

    private var yDomain: ClosedRange<Double> {
        valuationChartYDomain(
            seriesValues: data.map { $0[keyPath: valueKeyPath] },
            rangeMedian: rangeMedian,
            rangeMean: rangeMean,
            current: current,
            liveYZoom: liveYAxisZoom
        )
    }

    /// Giới hạn số nhãn trục X để không chồng chữ (vuốt ngang vẫn thấy đủ điểm).
    private func xAxisPeriodLabel(for point: ValuationDataPoint) -> String {
        if showQuarterly {
            let yy = String(format: "%02d", point.year % 100)
            return "Q\(point.quarter) \(yy)"
        }
        return String(point.year)
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
                    isZoomed: abs(xAxisZoom - 1) > 0.04 || abs(yAxisZoom - 1) > 0.04,
                    onReset: {
                        xAxisZoom = 1
                        yAxisZoom = 1
                        scrollLabel = recentScrollStartLabel(
                            visibleLength: effectiveVisibleLength(fullScreen: false)
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

            if data.isEmpty {
                Text("Không có điểm dữ liệu trong khoảng thời gian đã chọn.")
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
                (footerNote
                    ?? (showQuarterly
                        ? "Các điểm trong khoảng quý đã chọn; vuốt ngang để xem thêm."
                        : "Theo năm (ngày cuối năm); vuốt ngang để xem thêm."))
                    + " Chụm hai ngón: phóng/thu cửa sổ thời gian và thang giá trị; vuốt ngang xem thêm. ↺ đặt lại."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(Spacing.lg)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .onChange(of: data.count) { _, _ in
            xAxisZoom = 1
            yAxisZoom = 1
            scrollLabel = ""
        }
        .onChange(of: selectedLabel) { oldValue, newValue in
            handleSelectionChanged(from: oldValue, to: newValue)
        }
        .onDisappear {
            hidePopoverTask?.cancel(); hidePopoverTask = nil
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
        let visibleLength = effectiveVisibleLength(fullScreen: fullScreen)

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

                ForEach(Array(data.enumerated()), id: \.element.id) { idx, point in
                    let label = labels[idx]
                    let value = point[keyPath: valueKeyPath]

                    LineMark(
                        x: .value("Thời gian", label),
                        y: .value("Chỉ số", value)
                    )
                    .foregroundStyle(lineColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.monotone)

                    PointMark(
                        x: .value("Thời gian", label),
                        y: .value("Chỉ số", value)
                    )
                    .foregroundStyle(lineColor)
                    .symbolSize(24)
                }
            }
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: visibleLength)
            .chartScrollPosition(x: $scrollLabel)
            .onAppear {
                if scrollLabel.isEmpty {
                    scrollLabel = recentScrollStartLabel(visibleLength: visibleLength)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: fullScreen ? 6 : 4)) {
                    AxisGridLine().foregroundStyle(.gray.opacity(0.1))
                    AxisValueLabel().font(.caption2)
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
                baseChart.chartXSelection(value: $selectedLabel)
            } else {
                baseChart
            }

            if fullScreen, let label = displayedLabel {
                selectionPopover(for: label)
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
                    scrollLabel = recentScrollStartLabel(
                        visibleLength: effectiveVisibleLength(fullScreen: showFullscreen)
                    )
                }
            )
        )
    }

    private func selectionPopover(for label: String) -> some View {
        guard let index = labels.firstIndex(of: label), data.indices.contains(index) else {
            return AnyView(EmptyView())
        }
        let point = data[index]
        let value = point[keyPath: valueKeyPath]

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

    private func handleSelectionChanged(from oldValue: String?, to newValue: String?) {
        displayedLabel = newValue
    }
}
