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

private func parseDailyChartDate(_ isoDay: String) -> Date? {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
    let parts = isoDay.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    return cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
}

