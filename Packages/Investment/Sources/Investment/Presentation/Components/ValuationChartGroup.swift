import Charts
import Foundation
import FinFlowCore
import SwiftUI

public struct ValuationChartGroup: View {
    let valuations: [ValuationDataPoint]
    let dailyValuations: [DailyValuationDataPoint]
    @Binding var granularity: ValuationSeriesGranularity
    let overview: StockOverview
    let showQuarterly: Bool
    let onRequestFullHistory: (() -> Void)?
    let onRequestValuationsForRange: ((Date, Date, Bool) -> Void)?
    let onRequestDailyValuations: ((Date, Date) -> Void)?

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
        dailyValuations: [DailyValuationDataPoint] = [],
        granularity: Binding<ValuationSeriesGranularity> = .constant(.quarterly),
        overview: StockOverview,
        showQuarterly: Bool = true,
        onRequestFullHistory: (() -> Void)? = nil,
        onRequestValuationsForRange: ((Date, Date, Bool) -> Void)? = nil,
        onRequestDailyValuations: ((Date, Date) -> Void)? = nil
    ) {
        self.valuations = valuations
        self.dailyValuations = dailyValuations
        self._granularity = granularity
        self.overview = overview
        self.showQuarterly = showQuarterly
        self.onRequestFullHistory = onRequestFullHistory
        self.onRequestValuationsForRange = onRequestValuationsForRange
        self.onRequestDailyValuations = onRequestDailyValuations
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

    private var filteredDailyValuations: [DailyValuationDataPoint] {
        let startDay = calendar.startOfDay(for: min(rangeStart, rangeEnd))
        let endBase = calendar.startOfDay(for: max(rangeStart, rangeEnd))
        let lo = min(startDay, endBase)
        let hi = max(startDay, endBase)
        return dailyValuations.filter { p in
            guard let d = parseDailyChartDate(p.date) else { return false }
            let day = calendar.startOfDay(for: d)
            return day >= lo && day <= hi
        }
    }

    private var liveValuationFootnote: String {
        let sourceLabel: String = {
            switch overview.livePriceSource {
            case "CLOSE": return "đóng cửa gần nhất"
            case let s?: return s
            case nil: return "VPS"
            }
        }()
        let priceText = overview.livePriceVnd.map { CurrencyFormatter.format($0) } ?? "—"
        return "Số hiện tại trong các ô: theo giá VPS (\(sourceLabel), \(priceText)) và BCTC (EPS TTM, BVPS, DTT 4 quý). Đường lịch sử vẫn là chỉ số trong DB."
    }

    private var valuationChartFootnote: String {
        if granularity == .daily {
            return "Số hiện tại: giá VPS + BCTC. Chuỗi ngày: giá Finfo; P/E–P/B như trước; P/S = giá / (mẫu TTM trên CP): doanh thu thuần (non-bank); NH: thu nhập lãi thuần + dịch vụ + khác (TTM)."
        }
        return liveValuationFootnote
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

            if overview.livePriceVnd != nil || granularity == .daily {
                Text(valuationChartFootnote)
                    .font(AppTypography.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.sm)
            }

            if granularity == .quarterly {
                ValuationSingleChart(
                    title: "Định giá P/E",
                    current: overview.displayPE,
                    rangeMedian: medianInRange(filteredValuations, keyPath: \.pe),
                    rangeMean: meanInRange(filteredValuations, keyPath: \.pe),
                    data: filteredValuations,
                    valueKeyPath: \.pe,
                    lineColor: .teal,
                    showQuarterly: showQuarterly,
                    onRequestFullHistory: onRequestFullHistory,
                )

                ValuationSingleChart(
                    title: "Định giá P/B",
                    current: overview.displayPB,
                    rangeMedian: medianInRange(filteredValuations, keyPath: \.pb),
                    rangeMean: meanInRange(filteredValuations, keyPath: \.pb),
                    data: filteredValuations,
                    valueKeyPath: \.pb,
                    lineColor: .blue,
                    showQuarterly: showQuarterly,
                    onRequestFullHistory: onRequestFullHistory,
                )

                ValuationSingleChart(
                    title: "Định giá P/S",
                    current: overview.displayPS,
                    rangeMedian: medianInRange(filteredValuations, keyPath: \.ps),
                    rangeMean: meanInRange(filteredValuations, keyPath: \.ps),
                    data: filteredValuations,
                    valueKeyPath: \.ps,
                    lineColor: .pink,
                    showQuarterly: showQuarterly,
                    onRequestFullHistory: onRequestFullHistory,
                )
            } else {
                ValuationDailySingleChart(
                    title: "Định giá P/E",
                    current: overview.displayPE,
                    rangeMedian: medianInRangeDaily(filteredDailyValuations, metric: \.pe),
                    rangeMean: meanInRangeDaily(filteredDailyValuations, metric: \.pe),
                    data: filteredDailyValuations,
                    metric: \.pe,
                    lineColor: .teal,
                    onRequestFullHistory: onRequestFullHistory,
                    headlineNote: nil,
                    emptyChartMessage: nil
                )

                ValuationDailySingleChart(
                    title: "Định giá P/B",
                    current: overview.displayPB,
                    rangeMedian: medianInRangeDaily(filteredDailyValuations, metric: \.pb),
                    rangeMean: meanInRangeDaily(filteredDailyValuations, metric: \.pb),
                    data: filteredDailyValuations,
                    metric: \.pb,
                    lineColor: .blue,
                    onRequestFullHistory: onRequestFullHistory,
                    headlineNote: nil,
                    emptyChartMessage: nil
                )

                ValuationDailySingleChart(
                    title: "Định giá P/S",
                    current: overview.displayPS,
                    rangeMedian: medianInRangeDaily(filteredDailyValuations, metric: \.ps),
                    rangeMean: meanInRangeDaily(filteredDailyValuations, metric: \.ps),
                    data: filteredDailyValuations,
                    metric: \.ps,
                    lineColor: .pink,
                    onRequestFullHistory: onRequestFullHistory,
                    headlineNote: nil,
                    emptyChartMessage: nil
                )
            }
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
        .onChange(of: granularity) { _, _ in
            lastRequestedRangeKey = nil
            scheduleRangeReloadIfNeeded()
        }
    }

    @ViewBuilder
    private var dateRangeControls: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Picker("Chuỗi định giá", selection: $granularity) {
                ForEach(ValuationSeriesGranularity.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Kiểu biểu đồ định giá")
            .accessibilityHint("Ngày: chuỗi theo phiên giao dịch. Quý: điểm cuối kỳ báo cáo.")

            Text(
                granularity == .daily
                    ? "Chọn khoảng theo cuối quý; dữ liệu ngày được lọc trong khoảng calendar tương ứng."
                    : "Khoảng quý (trung vị chỉ tính trong khoảng này)"
            )
            .font(AppTypography.caption)
            .foregroundStyle(.secondary)

            if granularity == .quarterly, dataBounds == nil {
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
        let modeGranularity = granularity

        pendingRangeReloadTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000) // 450ms debounce
            guard !Task.isCancelled else { return }

            let key = rangeKey(s: lo, e: hi, granularity: modeGranularity)
            if lastRequestedRangeKey == key { return }
            lastRequestedRangeKey = key

            let backendLo = backendUTCMidnightDate(fromLocal: lo)
            let backendHi = backendUTCMidnightDate(fromLocal: hi)
            if modeGranularity == .daily {
                onRequestDailyValuations?(backendLo, backendHi)
            } else {
                onRequestValuationsForRange?(backendLo, backendHi, mode)
            }
        }
    }

    private func rangeKey(s: Date, e: Date, granularity: ValuationSeriesGranularity) -> String {
        let sC = calendar.dateComponents([.year, .month, .day], from: s)
        let eC = calendar.dateComponents([.year, .month, .day], from: e)
        let sy = sC.year ?? 0, sm = sC.month ?? 0, sd = sC.day ?? 0
        let ey = eC.year ?? 0, em = eC.month ?? 0, ed = eC.day ?? 0
        let kind = granularity == .daily ? "D" : (showQuarterly ? "Q" : "Y")
        return "\(kind)|\(sy)-\(sm)-\(sd)|\(ey)-\(em)-\(ed)"
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
        let hasQuarterly = onRequestValuationsForRange != nil
        let hasDaily = onRequestDailyValuations != nil
        guard (granularity == .daily && hasDaily) || (granularity == .quarterly && hasQuarterly) else { return }

        let lo = min(desired.start, desired.end)
        let hi = max(desired.start, desired.end)
        let backendLo = backendUTCMidnightDate(fromLocal: lo)
        let backendHi = backendUTCMidnightDate(fromLocal: hi)

        // Mark first to avoid duplicate requests while the UI is still settling.
        didLoadDefaultRange = true
        lastRequestedRangeKey = rangeKey(s: lo, e: hi, granularity: granularity)
        if granularity == .daily {
            onRequestDailyValuations?(backendLo, backendHi)
        } else {
            onRequestValuationsForRange?(backendLo, backendHi, showQuarterly)
        }
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

private func medianOfFiniteValues(_ values: [Double]) -> Double? {
    let sorted = values.filter(\.isFinite).sorted()
    guard !sorted.isEmpty else { return nil }
    let mid = sorted.count / 2
    if sorted.count % 2 == 0 {
        return (sorted[mid - 1] + sorted[mid]) / 2
    }
    return sorted[mid]
}

private func meanOfFiniteValues(_ values: [Double]) -> Double? {
    let finite = values.filter(\.isFinite)
    guard !finite.isEmpty else { return nil }
    return finite.reduce(0, +) / Double(finite.count)
}

private func medianInRange(_ points: [ValuationDataPoint], keyPath: KeyPath<ValuationDataPoint, Double>)
    -> Double?
{
    medianOfFiniteValues(points.map { $0[keyPath: keyPath] })
}

private func medianInRangeDaily(
    _ points: [DailyValuationDataPoint],
    metric: KeyPath<DailyValuationDataPoint, Double?>
) -> Double? {
    medianOfFiniteValues(points.compactMap { $0[keyPath: metric] })
}

private func meanInRange(_ points: [ValuationDataPoint], keyPath: KeyPath<ValuationDataPoint, Double>) -> Double? {
    meanOfFiniteValues(points.map { $0[keyPath: keyPath] })
}

private func meanInRangeDaily(
    _ points: [DailyValuationDataPoint],
    metric: KeyPath<DailyValuationDataPoint, Double?>
) -> Double? {
    meanOfFiniteValues(points.compactMap { $0[keyPath: metric] })
}

// MARK: - Thu phóng trục X / Y (chụm 2 ngón trên biểu đồ)

private enum ValuationChartAxisZoom {
    static let minZoom: CGFloat = 0.5
    static let maxZoom: CGFloat = 5.0

    static func clamp(_ z: CGFloat) -> CGFloat {
        CGFloat(min(max(Double(z), Double(minZoom)), Double(maxZoom)))
    }
}

/// Domain trục Y dùng chung cho chart quý/năm và chart theo ngày.
private func valuationChartYDomain(
    seriesValues: [Double],
    rangeMedian: Double?,
    rangeMean: Double?,
    current: Double,
    liveYZoom: CGFloat
) -> ClosedRange<Double> {
    let finite = seriesValues.filter(\.isFinite)
    guard !finite.isEmpty else { return 0...1 }

    let dataLo = finite.min()!
    let dataHi = finite.max()!
    let dataMid = (dataLo + dataHi) / 2

    var lo = dataLo
    var hi = dataHi
    if let m = rangeMedian, m.isFinite {
        lo = min(lo, m)
        hi = max(hi, m)
    }
    if let a = rangeMean, a.isFinite {
        lo = min(lo, a)
        hi = max(hi, a)
    }
    if current.isFinite {
        lo = min(lo, current)
        hi = max(hi, current)
    }

    let span = hi - lo
    if span < 1e-9 {
        let c = hi
        return (c - 0.5)...(c + 0.5)
    }

    let pad = max(span * 0.1, max(abs(hi), abs(lo)) * 0.02 + 0.05)
    lo -= pad
    hi += pad

    let allowNegative =
        finite.contains { $0 < 0 }
        || (rangeMedian.map { $0 < 0 } ?? false)
        || (rangeMean.map { $0 < 0 } ?? false)
        || current < 0
    if !allowNegative {
        lo = max(0, lo)
    }

    guard lo < hi else { return (hi - 0.5)...(hi + 0.5) }
    let z = Double(liveYZoom)
    var half = (hi - lo) / 2
    half = max(half / z, 1e-9)
    // Neo zoom Y quanh **chuỗi dữ liệu** (không tâm của cả khối median/TB đã kéo giãn) — tránh “mất đường”.
    var nLo = dataMid - half
    var nHi = dataMid + half
    if nHi < dataLo || nLo > dataHi {
        let minHalf = max((dataHi - dataLo) / 2 * 1.05, 1e-6)
        half = max(half, minHalf)
        nLo = dataMid - half
        nHi = dataMid + half
    }
    if !allowNegative {
        nLo = max(0, nLo)
        if nLo >= nHi {
            nHi = nLo + 1e-6
        }
    }
    guard nLo < nHi else { return (dataMid - 0.25)...(dataMid + 0.25) }
    return nLo...nHi
}

/// Chụm: zoom **cửa sổ thời gian (X)** và **thang giá trị (Y)** cùng hệ số; sau đó đồng bộ cuộn trục X.
@MainActor
private func valuationPinchGesture(
    pinch: GestureState<CGFloat>,
    xAxisZoom: Binding<CGFloat>,
    yAxisZoom: Binding<CGFloat>,
    onXZoomCommitted: @escaping () -> Void
) -> some Gesture {
    MagnificationGesture()
        .updating(pinch) { value, state, _ in
            state = value
        }
        .onEnded { value in
            xAxisZoom.wrappedValue = ValuationChartAxisZoom.clamp(xAxisZoom.wrappedValue * value)
            yAxisZoom.wrappedValue = ValuationChartAxisZoom.clamp(yAxisZoom.wrappedValue * value)
            onXZoomCommitted()
        }
}

private extension View {
    /// Tắt animation ngầm khi đổi zoom (giảm giật).
    func valuationChartZoomAnimations(
        xAxisZoom: CGFloat,
        yAxisZoom: CGFloat,
        pinchMagnification: CGFloat
    ) -> some View {
        self
            .animation(nil, value: xAxisZoom)
            .animation(nil, value: yAxisZoom)
            .animation(nil, value: pinchMagnification)
    }
}

private enum ValuationChartFullscreenLayout {
    /// Dành thêm chỗ cho nhãn trục X khi fullscreen ngang.
    static let landscapeHeightTrim: CGFloat = 64
}

/// Nút ↺ thu phóng + phóng to — dùng chung cho chart định giá.
private struct ValuationChartZoomToolbar: View {
    var isZoomed: Bool
    var onReset: () -> Void
    var onFullscreen: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if isZoomed {
                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.primary)
                        .frame(width: 28, height: 28)
                        .background(AppColors.primary.opacity(0.1))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Đặt lại thu phóng chart")
            }
            Button(action: onFullscreen) {
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
    }
}

/// Badge so sánh với trung vị / TB trong khoảng.
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
            let color: Color = pct < 1 ? .secondary : (isLower ? .green : .red)

            VStack(alignment: .leading, spacing: Spacing.xs) {
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
                            return (t, .orange)
                        }
                        let t =
                            "\(lowerMean ? "thấp hơn" : "cao hơn") \(String(format: "%.1f%%", pMean)) so với TB \(String(format: "%.2f", mean))"
                        return (t, lowerMean ? .green : .red)
                    }()
                    Text(textMean)
                        .font(.caption2)
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

private func parseDailyChartDate(_ isoDay: String) -> Date? {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
    let parts = isoDay.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    return cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
}

// MARK: - Single Valuation Chart

private struct ValuationSingleChart: View {
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

// MARK: - Daily valuation chart (Finfo close + indicators by day)

private struct ValuationDailySingleChart: View {
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
