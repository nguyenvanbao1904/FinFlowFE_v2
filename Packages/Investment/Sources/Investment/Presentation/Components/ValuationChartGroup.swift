import Charts
import Foundation
import FinFlowCore
import SwiftUI

public struct ValuationChartGroup: View {
    let valuations: [ValuationDataPoint]
    let overview: StockOverview
    let showQuarterly: Bool
    let onRequestFullHistory: (() -> Void)?
    let onRequestValuationsForRange: ((Date, Date, Bool) -> Void)?

    @State private var rangeStart: Date = .now
    @State private var rangeEnd: Date = .now
    @State private var didInitializeRange = false
    @State private var didLoadDefaultRange = false
    @State private var pendingRangeReloadTask: Task<Void, Never>?
    @State private var lastRequestedRangeKey: String?

    private let calendar = Calendar(identifier: .gregorian)
    private var utcCalendar: Calendar {
        var c = calendar
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    /// Backend parse `yyyy-MM-dd` as `LocalDate` (timezone agnostic), nhưng FE format date in UTC (`GMT+0`).
    /// Nếu dùng Date ở local midnight thì có thể bị lệch ngày 1.
    /// Hàm này giữ nguyên Y/M/D theo local, nhưng tạo Date tại UTC midnight để format ra đúng `yyyy-MM-dd`.
    private func backendUTCMidnightDate(fromLocal date: Date) -> Date {
        let ymd = calendar.dateComponents([.year, .month, .day], from: date)
        var dc = DateComponents()
        dc.year = ymd.year
        dc.month = ymd.month
        dc.day = ymd.day
        return utcCalendar.date(from: dc) ?? date
    }

    public init(
        valuations: [ValuationDataPoint],
        overview: StockOverview,
        showQuarterly: Bool = true,
        onRequestFullHistory: (() -> Void)? = nil,
        onRequestValuationsForRange: ((Date, Date, Bool) -> Void)? = nil
    ) {
        self.valuations = valuations
        self.overview = overview
        self.showQuarterly = showQuarterly
        self.onRequestFullHistory = onRequestFullHistory
        self.onRequestValuationsForRange = onRequestValuationsForRange
    }

    private var displayValuations: [ValuationDataPoint] {
        guard !showQuarterly else { return valuations }

        let grouped = Dictionary(grouping: valuations, by: \.year)
        return grouped.keys.sorted().compactMap { year in
            guard let items = grouped[year], !items.isEmpty else { return nil }
            let peAvg = items.map(\.pe).reduce(0, +) / Double(items.count)
            let pbAvg = items.map(\.pb).reduce(0, +) / Double(items.count)
            let psAvg = items.map(\.ps).reduce(0, +) / Double(items.count)
            return ValuationDataPoint(year: year, quarter: 4, pe: peAvg, pb: pbAvg, ps: psAvg)
        }
    }

    private var dataBounds: (min: Date, max: Date)? {
        valuationPeriodBounds(points: displayValuations, showQuarterly: showQuarterly, calendar: calendar)
    }

    /// Điểm trong khoảng [rangeStart … rangeEnd] (theo ngày cuối kỳ báo cáo).
    private var filteredValuations: [ValuationDataPoint] {
        guard let bounds = dataBounds else { return [] }
        let startDay = calendar.startOfDay(for: min(rangeStart, rangeEnd))
        let endBase = calendar.startOfDay(for: max(rangeStart, rangeEnd))
        let endDay =
            calendar.date(byAdding: DateComponents(day: 1, second: -1), to: endBase) ?? endBase
        let lo = min(startDay, endDay)
        let hi = max(startDay, endDay)
        let clampedLo = max(lo, bounds.min)
        let clampedHi = min(hi, bounds.max)
        guard clampedLo <= clampedHi else { return [] }
        return displayValuations.filter { p in
            let d = endOfReportingPeriod(for: p, showQuarterly: showQuarterly, calendar: calendar)
            return d >= clampedLo && d <= clampedHi
        }
    }

    private let quarterOptions = [1, 2, 3, 4]

    // Range mặc định/cho phép chọn: từ 2010 đến năm hiện tại.
    private var yearOptions: [Int] {
        let nowYear = calendar.component(.year, from: Date())
        let minYear = 2010 // yêu cầu: y > 2009
        let endYear = max(minYear, nowYear)
        return Array(minYear...endYear)
    }

    private func yearAndQuarter(for date: Date) -> (year: Int, quarter: Int) {
        let c = calendar.dateComponents([.year, .month, .day], from: calendar.startOfDay(for: date))
        let y = c.year ?? 0
        let m = c.month ?? 0
        let d = c.day ?? 0
        let q: Int
        switch (m, d) {
        case (3, 31): q = 1
        case (6, 30): q = 2
        case (9, 30): q = 3
        default: q = 4
        }
        return (year: y, quarter: q)
    }

    private func quarterEndDate(year: Int, quarter: Int) -> Date? {
        let (month, day) = quarterLastMonthDay(quarter)
        var dc = DateComponents()
        dc.year = year
        dc.month = month
        dc.day = day
        return calendar.date(from: dc).map { calendar.startOfDay(for: $0) }
    }

    private func quarterFromDate(_ date: Date) -> Int {
        let m = calendar.component(.month, from: date)
        return ((m - 1) / 3) + 1
    }

    // Ví dụ: hiện tại là Q1 2026 -> mặc định: Q1 2025 ... Q1 2026
    private func defaultQuarterRangeForNow() -> (start: Date, end: Date)? {
        let now = Date()
        let nowYear = calendar.component(.year, from: now)
        let nowQuarter = quarterFromDate(now)

        let end = quarterEndDate(year: nowYear, quarter: nowQuarter)

        // clamp startYear nếu hiện tại quá gần mốc 2010
        let startYear = max(2010, nowYear - 1)
        let start = quarterEndDate(year: startYear, quarter: nowQuarter)

        guard let s = start, let e = end else { return nil }
        return (start: s, end: e)
    }

    public var body: some View {
        VStack(spacing: Spacing.md) {
            dateRangeControls

            ValuationSingleChart(
                title: "Định giá P/E",
                current: overview.currentPE,
                rangeMedian: medianInRange(filteredValuations, keyPath: \.pe),
                data: filteredValuations,
                valueKeyPath: \.pe,
                lineColor: .teal,
                showQuarterly: showQuarterly,
                onRequestFullHistory: onRequestFullHistory,
            )

            ValuationSingleChart(
                title: "Định giá P/B",
                current: overview.currentPB,
                rangeMedian: medianInRange(filteredValuations, keyPath: \.pb),
                data: filteredValuations,
                valueKeyPath: \.pb,
                lineColor: .blue,
                showQuarterly: showQuarterly,
                onRequestFullHistory: onRequestFullHistory,
            )

            ValuationSingleChart(
                title: "Định giá P/S",
                current: overview.currentPS,
                rangeMedian: medianInRange(filteredValuations, keyPath: \.ps),
                data: filteredValuations,
                valueKeyPath: \.ps,
                lineColor: .pink,
                showQuarterly: showQuarterly,
                onRequestFullHistory: onRequestFullHistory,
            )
        }
        .onAppear {
            resetRangeToDefaultIfNeeded(force: !didInitializeRange)
            ensureDefaultQuarterRangeLoadedIfNeeded()
        }
        .onChange(of: overview.symbol) { _, _ in
            didInitializeRange = false
            didLoadDefaultRange = false
            resetRangeToDefaultIfNeeded(force: true)
            ensureDefaultQuarterRangeLoadedIfNeeded()
        }
        .onChange(of: showQuarterly) { _, _ in
            didInitializeRange = false
            didLoadDefaultRange = false
            resetRangeToDefaultIfNeeded(force: true)
            ensureDefaultQuarterRangeLoadedIfNeeded()
        }
        .onChange(of: valuations.count) { _, _ in
            // Khi backend load xong, kiểm tra xem đã phủ đủ range mặc định chưa.
            ensureDefaultQuarterRangeLoadedIfNeeded()
        }
    }

    @ViewBuilder
    private var dateRangeControls: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Khoảng quý (trung vị chỉ tính trong khoảng này)")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)

            if dataBounds == nil {
                Text("Đang tải dữ liệu định giá...")
                    .font(AppTypography.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack(alignment: .top, spacing: Spacing.md) {
                quarterYearRangeColumn(
                    title: "Từ quý",
                    selection: $rangeStart
                )
                quarterYearRangeColumn(
                    title: "Đến quý",
                    selection: $rangeEnd
                )
            }
            .onChange(of: rangeStart) { _, newStart in
                clampRangeSelections(anchorStart: newStart)
                scheduleRangeReloadIfNeeded()
            }
            .onChange(of: rangeEnd) { _, newEnd in
                clampRangeSelections(anchorEnd: newEnd)
                scheduleRangeReloadIfNeeded()
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }

    private func scheduleRangeReloadIfNeeded() {
        pendingRangeReloadTask?.cancel()

        let s = rangeStart
        let e = rangeEnd
        let lo = min(s, e)
        let hi = max(s, e)
        let mode = showQuarterly

        pendingRangeReloadTask = Task {
            try? await Task.sleep(nanoseconds: 450_000_000) // 450ms debounce
            guard !Task.isCancelled else { return }

            let shouldRequest = await MainActor.run { () -> Bool in
                let key = rangeKey(s: lo, e: hi)
                if lastRequestedRangeKey == key { return false }
                lastRequestedRangeKey = key
                return true
            }

            guard shouldRequest else { return }
            let backendLo = backendUTCMidnightDate(fromLocal: lo)
            let backendHi = backendUTCMidnightDate(fromLocal: hi)
            onRequestValuationsForRange?(backendLo, backendHi, mode)
        }
    }

    private func rangeKey(s: Date, e: Date) -> String {
        let sC = calendar.dateComponents([.year, .month, .day], from: s)
        let eC = calendar.dateComponents([.year, .month, .day], from: e)
        let sy = sC.year ?? 0, sm = sC.month ?? 0, sd = sC.day ?? 0
        let ey = eC.year ?? 0, em = eC.month ?? 0, ed = eC.day ?? 0
        return "\(showQuarterly ? "Q" : "Y")|\(sy)-\(sm)-\(sd)|\(ey)-\(em)-\(ed)"
    }

    @ViewBuilder
    private func quarterYearRangeColumn(
        title: String,
        selection: Binding<Date>
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(AppTypography.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            let yearBinding = Binding<Int>(
                get: { yearAndQuarter(for: selection.wrappedValue).year },
                set: { newYear in
                    let currentQuarter = yearAndQuarter(for: selection.wrappedValue).quarter
                    if let d = quarterEndDate(year: newYear, quarter: currentQuarter) {
                        selection.wrappedValue = d
                    }
                }
            )

            let quarterBinding = Binding<Int>(
                get: { yearAndQuarter(for: selection.wrappedValue).quarter },
                set: { newQuarter in
                    let currentYear = yearAndQuarter(for: selection.wrappedValue).year
                    if let d = quarterEndDate(year: currentYear, quarter: newQuarter) {
                        selection.wrappedValue = d
                    }
                }
            )

            HStack(spacing: Spacing.xs) {
                VStack(alignment: .leading, spacing: .zero) {
                    Picker("", selection: quarterBinding) {
                        ForEach(quarterOptions, id: \.self) { q in
                            Text("Q\(q)").tag(q)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 52, height: 92)
                    .clipped()
                }

                VStack(alignment: .leading, spacing: .zero) {
                    Picker("", selection: yearBinding) {
                        ForEach(yearOptions, id: \.self) { y in
                            Text("\(y)").tag(y)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 78, height: 92)
                    .clipped()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resetRangeToDefaultIfNeeded(force: Bool) {
        guard let desired = defaultQuarterRangeForNow() else { return }
        if force || !didInitializeRange {
            rangeStart = desired.start
            rangeEnd = desired.end
            didInitializeRange = true
        }
    }

    private func ensureDefaultQuarterRangeLoadedIfNeeded() {
        guard !didLoadDefaultRange else { return }
        guard let desired = defaultQuarterRangeForNow() else { return }
        guard onRequestValuationsForRange != nil else { return }

        let lo = min(desired.start, desired.end)
        let hi = max(desired.start, desired.end)
        let backendLo = backendUTCMidnightDate(fromLocal: lo)
        let backendHi = backendUTCMidnightDate(fromLocal: hi)

        // Mark first to avoid duplicate requests while the UI is still settling.
        didLoadDefaultRange = true
        lastRequestedRangeKey = rangeKey(s: lo, e: hi)
        onRequestValuationsForRange?(backendLo, backendHi, showQuarterly)
    }

    private func clampRangeSelections(anchorStart: Date? = nil, anchorEnd: Date? = nil) {
        var s = calendar.startOfDay(for: rangeStart)
        var e = calendar.startOfDay(for: rangeEnd)
        if s > e {
            if anchorStart != nil {
                e = s
            } else if anchorEnd != nil {
                s = e
            } else {
                swap(&s, &e)
            }
        }
        rangeStart = s
        rangeEnd = e
    }
}

// MARK: - Period dates & median (khoảng thời gian định giá)

private func endOfReportingPeriod(
    for point: ValuationDataPoint,
    showQuarterly: Bool,
    calendar: Calendar
) -> Date {
    if showQuarterly {
        let (month, day) = quarterLastMonthDay(point.quarter)
        var dc = DateComponents()
        dc.year = point.year
        dc.month = month
        dc.day = day
        return calendar.date(from: dc) ?? .distantPast
    }
    var dc = DateComponents()
    dc.year = point.year
    dc.month = 12
    dc.day = 31
    return calendar.date(from: dc) ?? .distantPast
}

private func quarterLastMonthDay(_ quarter: Int) -> (month: Int, day: Int) {
    switch quarter {
    case 1: return (3, 31)
    case 2: return (6, 30)
    case 3: return (9, 30)
    default: return (12, 31)
    }
}

private func valuationPeriodBounds(
    points: [ValuationDataPoint],
    showQuarterly: Bool,
    calendar: Calendar
) -> (min: Date, max: Date)? {
    guard !points.isEmpty else { return nil }
    let dates = points.map { endOfReportingPeriod(for: $0, showQuarterly: showQuarterly, calendar: calendar) }
    guard let minD = dates.min(), let maxD = dates.max() else { return nil }
    return (calendar.startOfDay(for: minD), calendar.startOfDay(for: maxD))
}

private func medianInRange(_ points: [ValuationDataPoint], keyPath: KeyPath<ValuationDataPoint, Double>)
    -> Double?
{
    let values = points.map { $0[keyPath: keyPath] }.filter(\.isFinite).sorted()
    guard !values.isEmpty else { return nil }
    let mid = values.count / 2
    if values.count % 2 == 0 {
        return (values[mid - 1] + values[mid]) / 2
    }
    return values[mid]
}

// MARK: - Single Valuation Chart

private struct ValuationSingleChart: View {
    let title: String
    let current: Double
    /// Trung vị các điểm trong khoảng thời gian user chọn (không dùng median từ API).
    let rangeMedian: Double?
    let data: [ValuationDataPoint]
    let valueKeyPath: KeyPath<ValuationDataPoint, Double>
    let lineColor: Color
    let showQuarterly: Bool
    let onRequestFullHistory: (() -> Void)?

    @State private var scrollLabel: String = ""
    @State private var showFullscreen = false
    @State private var selectedLabel: String?
    @State private var displayedLabel: String?
    @State private var hidePopoverTask: Task<Void, Never>?

    private var diff: Double? {
        guard let m = rangeMedian, m != 0 else { return nil }
        return current - m
    }

    private var pct: Double? {
        guard let d = diff, let m = rangeMedian, m != 0 else { return nil }
        return abs(d) / m * 100
    }

    private var labels: [String] {
        data.map(xAxisPeriodLabel)
    }

    private var inlineVisibleLength: Int {
        return max(1, min(4, data.count))
    }

    private func recentScrollStartLabel(visibleLength: Int) -> String {
        guard !labels.isEmpty else { return "" }
        let startIndex = max(labels.count - visibleLength, 0)
        return labels[startIndex]
    }

    /// Bao phủ **mọi** điểm trên series + trung vị + current + đệm — tránh cắt đỉnh/đáy do IQR.
    private var yDomain: ClosedRange<Double> {
        let values = data
            .map { $0[keyPath: valueKeyPath] }
            .filter { $0.isFinite }
        guard !values.isEmpty else { return 0...1 }

        var lo = values.min()!
        var hi = values.max()!
        if let m = rangeMedian, m.isFinite {
            lo = min(lo, m)
            hi = max(hi, m)
        }
        if current.isFinite {
            lo = min(lo, current)
            hi = max(hi, current)
        }

        var span = hi - lo
        if span < 1e-9 {
            let c = hi
            return (c - 0.5)...(c + 0.5)
        }

        // Đệm ~10% khoảng + tối thiểu nhỏ để trục không dính sát điểm
        let pad = max(span * 0.1, max(abs(hi), abs(lo)) * 0.02 + 0.05)
        lo -= pad
        hi += pad

        let allowNegative =
            values.contains { $0 < 0 } || (rangeMedian.map { $0 < 0 } ?? false) || current < 0
        if !allowNegative {
            lo = max(0, lo)
        }

        guard lo < hi else { return (hi - 0.5)...(hi + 0.5) }
        return lo...hi
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

                Button {
                    onRequestFullHistory?()
                    showFullscreen = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.primary)
                        .frame(width: 28, height: 28)
                        .background(AppColors.primary.opacity(0.1))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Phóng to biểu đồ")
            }

            HStack {
                comparisonBadge
                Spacer(minLength: 0)
            }

            if data.isEmpty {
                Text("Không có điểm dữ liệu trong khoảng thời gian đã chọn.")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .background(AppColors.cardBackground.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            } else {
                chart(fullScreen: false)
                    .frame(height: 220)
            }

            Text(
                showQuarterly
                    ? "Chỉ các điểm trong khoảng quý đã chọn; vuốt ngang để xem thêm."
                    : "Theo năm: ngày cuối năm dùng để lọc khoảng; vuốt ngang để xem thêm."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(Spacing.lg)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .onChange(of: selectedLabel) { oldValue, newValue in
            handleSelectionChanged(from: oldValue, to: newValue)
        }
        .onDisappear {
            hidePopoverTask?.cancel(); hidePopoverTask = nil
        }
        .fullScreenCover(isPresented: $showFullscreen) {
            ChartFullscreenContainer(title: title) {
                GeometryReader { proxy in
                    let isLandscape = proxy.size.width > proxy.size.height
                    let baseHeight = ChartFullscreenSupport.preferredChartHeight(for: proxy.size)
                    // Reserve more space for X-axis labels on landscape fullscreen.
                    let adjustedHeight = isLandscape ? max(220, baseHeight - 64) : baseHeight
                    VStack(spacing: Spacing.md) {
                        chart(fullScreen: true)
                            .frame(maxWidth: .infinity)
                            .frame(height: adjustedHeight)
                            .padding(Spacing.md)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                    }
                    .padding(.bottom, isLandscape ? Spacing.md : 0)
                }
            }
        }
    }

    @ViewBuilder
    private var comparisonBadge: some View {
        if let median = rangeMedian, let pct {
            let isLower = (diff ?? 0) <= 0
            let text =
                pct < 1
                ? "≈ Trung vị (trong khoảng)"
                : "\(isLower ? "thấp hơn" : "cao hơn") \(String(format: "%.1f%%", pct)) so với trung vị \(String(format: "%.2f", median))"
            let color: Color = pct < 1 ? .secondary : (isLower ? .green : .red)

            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(color)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xs)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        } else {
            Text("Chưa có trung vị trong khoảng (không đủ dữ liệu hoặc giá trị không hợp lệ).")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xs)
                .background(Color.secondary.opacity(0.08))
                .clipShape(Capsule())
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
    }

    private func chart(fullScreen: Bool) -> some View {
        let visibleLength = fullScreen ? min(8, max(1, data.count)) : inlineVisibleLength

        return ZStack(alignment: .top) {
            let baseChart = Chart {
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
                AxisMarks(values: .automatic(desiredCount: fullScreen ? 6 : 4)) { value in
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
    }

    private func selectionPopover(for label: String) -> some View {
        guard let index = labels.firstIndex(of: label), data.indices.contains(index) else {
            return AnyView(EmptyView())
        }
        let point = data[index]
        let value = point[keyPath: valueKeyPath]
        let ratio = Double(index) / Double(max(data.count - 1, 1))

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
