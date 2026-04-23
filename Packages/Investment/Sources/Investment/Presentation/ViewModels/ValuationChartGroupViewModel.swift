import FinFlowCore
import Observation
import SwiftUI

@MainActor
@Observable
final class ValuationChartGroupViewModel {
    // MARK: - State

    var rangeStart: Date = .now
    var rangeEnd: Date = .now
    var didInitializeRange = false
    var didLoadDefaultRange = false
    private var pendingRangeReloadTask: Task<Void, Never>?
    var lastRequestedRangeKey: String?

    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
        return c
    }()

    var utcCalendar: Calendar {
        var c = calendar
        c.timeZone = .gmt
        return c
    }

    let quarterOptions = [1, 2, 3, 4]

    var yearOptions: [Int] {
        let nowYear = calendar.component(.year, from: Date())
        let minYear = 2010
        let endYear = max(minYear, nowYear)
        return Array(minYear...endYear)
    }

    // MARK: - Date Helpers

    func backendUTCMidnightDate(fromLocal date: Date) -> Date {
        let ymd = calendar.dateComponents([.year, .month, .day], from: date)
        var dc = DateComponents()
        dc.year = ymd.year
        dc.month = ymd.month
        dc.day = ymd.day
        return utcCalendar.date(from: dc) ?? date
    }

    func yearAndQuarter(for date: Date) -> (year: Int, quarter: Int) {
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

    func quarterEndDate(year: Int, quarter: Int) -> Date? {
        let (month, day) = quarterLastMonthDay(quarter)
        var dc = DateComponents()
        dc.year = year
        dc.month = month
        dc.day = day
        return calendar.date(from: dc).map { calendar.startOfDay(for: $0) }
    }

    func quarterFromDate(_ date: Date) -> Int {
        let m = calendar.component(.month, from: date)
        return ((m - 1) / 3) + 1
    }

    func defaultQuarterRangeForNow() -> (start: Date, end: Date)? {
        let now = Date()
        let nowYear = calendar.component(.year, from: now)
        let nowQuarter = quarterFromDate(now)

        let end = quarterEndDate(year: nowYear, quarter: nowQuarter)
        let startYear = max(2010, nowYear - 1)
        let start = quarterEndDate(year: startYear, quarter: nowQuarter)

        guard let s = start, let e = end else { return nil }
        return (start: s, end: e)
    }

    // MARK: - Actions

    func resetRangeToDefaultIfNeeded(force: Bool) {
        guard let desired = defaultQuarterRangeForNow() else { return }
        if force || !didInitializeRange {
            rangeStart = desired.start
            rangeEnd = desired.end
            didInitializeRange = true
        }
    }

    func handleSymbolOrModeChange() {
        didInitializeRange = false
        didLoadDefaultRange = false
        resetRangeToDefaultIfNeeded(force: true)
    }

    func ensureDefaultQuarterRangeLoadedIfNeeded(
        granularity: ValuationSeriesGranularity,
        showQuarterly: Bool,
        onRequestValuationsForRange: ((Date, Date, Bool) -> Void)?,
        onRequestDailyValuations: ((Date, Date) -> Void)?
    ) {
        guard !didLoadDefaultRange else { return }
        guard let desired = defaultQuarterRangeForNow() else { return }
        let hasQuarterly = onRequestValuationsForRange != nil
        let hasDaily = onRequestDailyValuations != nil
        guard (granularity == .daily && hasDaily) || (granularity == .quarterly && hasQuarterly) else { return }

        let lo = min(desired.start, desired.end)
        let hi = max(desired.start, desired.end)
        let backendLo = backendUTCMidnightDate(fromLocal: lo)
        let backendHi = backendUTCMidnightDate(fromLocal: hi)

        didLoadDefaultRange = true
        lastRequestedRangeKey = rangeKey(s: lo, e: hi, granularity: granularity, showQuarterly: showQuarterly)
        if granularity == .daily {
            onRequestDailyValuations?(backendLo, backendHi)
        } else {
            onRequestValuationsForRange?(backendLo, backendHi, showQuarterly)
        }
    }

    func scheduleRangeReloadIfNeeded(
        granularity: ValuationSeriesGranularity,
        showQuarterly: Bool,
        onRequestValuationsForRange: ((Date, Date, Bool) -> Void)?,
        onRequestDailyValuations: ((Date, Date) -> Void)?
    ) {
        pendingRangeReloadTask?.cancel()

        let s = rangeStart
        let e = rangeEnd
        let lo = min(s, e)
        let hi = max(s, e)
        let mode = showQuarterly
        let modeGranularity = granularity

        pendingRangeReloadTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }

            let key = self.rangeKey(s: lo, e: hi, granularity: modeGranularity, showQuarterly: mode)
            if self.lastRequestedRangeKey == key { return }
            self.lastRequestedRangeKey = key

            let backendLo = self.backendUTCMidnightDate(fromLocal: lo)
            let backendHi = self.backendUTCMidnightDate(fromLocal: hi)
            if modeGranularity == .daily {
                onRequestDailyValuations?(backendLo, backendHi)
            } else {
                onRequestValuationsForRange?(backendLo, backendHi, mode)
            }
        }
    }

    func clampRangeSelections(anchorStart: Date? = nil, anchorEnd: Date? = nil) {
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

    func onGranularityChanged(
        granularity: ValuationSeriesGranularity,
        showQuarterly: Bool,
        onRequestValuationsForRange: ((Date, Date, Bool) -> Void)?,
        onRequestDailyValuations: ((Date, Date) -> Void)?
    ) {
        lastRequestedRangeKey = nil
        scheduleRangeReloadIfNeeded(
            granularity: granularity,
            showQuarterly: showQuarterly,
            onRequestValuationsForRange: onRequestValuationsForRange,
            onRequestDailyValuations: onRequestDailyValuations
        )
    }

    // MARK: - Private

    private func rangeKey(s: Date, e: Date, granularity: ValuationSeriesGranularity, showQuarterly: Bool) -> String {
        let sC = calendar.dateComponents([.year, .month, .day], from: s)
        let eC = calendar.dateComponents([.year, .month, .day], from: e)
        let sy = sC.year ?? 0, sm = sC.month ?? 0, sd = sC.day ?? 0
        let ey = eC.year ?? 0, em = eC.month ?? 0, ed = eC.day ?? 0
        let kind = granularity == .daily ? "D" : (showQuarterly ? "Q" : "Y")
        return "\(kind)|\(sy)-\(sm)-\(sd)|\(ey)-\(em)-\(ed)"
    }
}
