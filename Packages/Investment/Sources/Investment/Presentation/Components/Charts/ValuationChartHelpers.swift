import FinFlowCore
import SwiftUI

// MARK: - Period dates & range stats

struct ValuationRangeStats {
    let peMedian: Double?
    let peMean: Double?
    let pbMedian: Double?
    let pbMean: Double?
    let psMedian: Double?
    let psMean: Double?
}

func endOfReportingPeriod(
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

func quarterLastMonthDay(_ quarter: Int) -> (month: Int, day: Int) {
    switch quarter {
    case 1: return (3, 31)
    case 2: return (6, 30)
    case 3: return (9, 30)
    default: return (12, 31)
    }
}

func valuationPeriodBounds(
    points: [ValuationDataPoint],
    showQuarterly: Bool,
    calendar: Calendar
) -> (min: Date, max: Date)? {
    guard !points.isEmpty else { return nil }
    let dates = points.map { endOfReportingPeriod(for: $0, showQuarterly: showQuarterly, calendar: calendar) }
    guard let minD = dates.min(), let maxD = dates.max() else { return nil }
    return (calendar.startOfDay(for: minD), calendar.startOfDay(for: maxD))
}

func medianOfFiniteValues(_ values: [Double]) -> Double? {
    let sorted = values.filter(\.isFinite).sorted()
    guard !sorted.isEmpty else { return nil }
    let mid = sorted.count / 2
    if sorted.count % 2 == 0 {
        return (sorted[mid - 1] + sorted[mid]) / 2
    }
    return sorted[mid]
}

func meanOfFiniteValues(_ values: [Double]) -> Double? {
    let finite = values.filter(\.isFinite)
    guard !finite.isEmpty else { return nil }
    return finite.reduce(0, +) / Double(finite.count)
}

func medianInRange(_ points: [ValuationDataPoint], keyPath: KeyPath<ValuationDataPoint, Double>) -> Double? {
    medianOfFiniteValues(points.map { $0[keyPath: keyPath] })
}

func medianInRangeDaily(
    _ points: [DailyValuationDataPoint],
    metric: KeyPath<DailyValuationDataPoint, Double?>
) -> Double? {
    medianOfFiniteValues(points.compactMap { $0[keyPath: metric] })
}

func meanInRange(_ points: [ValuationDataPoint], keyPath: KeyPath<ValuationDataPoint, Double>) -> Double? {
    meanOfFiniteValues(points.map { $0[keyPath: keyPath] })
}

func meanInRangeDaily(
    _ points: [DailyValuationDataPoint],
    metric: KeyPath<DailyValuationDataPoint, Double?>
) -> Double? {
    meanOfFiniteValues(points.compactMap { $0[keyPath: metric] })
}

func valuationRangeStats(_ points: [ValuationDataPoint]) -> ValuationRangeStats {
    ValuationRangeStats(
        peMedian: medianInRange(points, keyPath: \.pe),
        peMean: meanInRange(points, keyPath: \.pe),
        pbMedian: medianInRange(points, keyPath: \.pb),
        pbMean: meanInRange(points, keyPath: \.pb),
        psMedian: medianInRange(points, keyPath: \.ps),
        psMean: meanInRange(points, keyPath: \.ps)
    )
}

func valuationDailyRangeStats(_ points: [DailyValuationDataPoint]) -> ValuationRangeStats {
    ValuationRangeStats(
        peMedian: medianInRangeDaily(points, metric: \.pe),
        peMean: meanInRangeDaily(points, metric: \.pe),
        pbMedian: medianInRangeDaily(points, metric: \.pb),
        pbMean: meanInRangeDaily(points, metric: \.pb),
        psMedian: medianInRangeDaily(points, metric: \.ps),
        psMean: meanInRangeDaily(points, metric: \.ps)
    )
}

// MARK: - Shared date parsing

func parseDailyChartDate(_ isoDay: String) -> Date? {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
    let parts = isoDay.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    return cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
}

// MARK: - Shared chart axis & scroll helpers

/// Compute evenly-spaced x-axis label indices for index-based charts.
func valuationXAxisValues(pointCount: Int, fullScreen: Bool) -> [Int] {
    guard pointCount > 0 else { return [] }
    let targetLabelCount = fullScreen ? 8 : 5
    if pointCount <= targetLabelCount {
        return Array(0..<pointCount)
    }
    let stride = max(1, Int(ceil(Double(pointCount - 1) / Double(max(targetLabelCount - 1, 1)))))
    var values = Array(Swift.stride(from: 0, to: pointCount, by: stride))
    if values.last != pointCount - 1 {
        values.append(pointCount - 1)
    }
    return values
}

/// Compute initial scroll position so the chart shows the latest data.
func valuationInitialScrollPosition(pointCount: Int, visibleLength: Int) -> Int {
    guard pointCount > 0 else { return 0 }
    return max(pointCount - visibleLength, 0)
}

// MARK: - Pinch and axis zoom helpers

enum ValuationChartAxisZoom {
    /// Cho phép zoom **ra** đủ để thấy gần toàn bộ chuỗi dài (10 năm); 0,5 chỉ ~×2 so với mặc định.
    static let minZoom: CGFloat = 0.11
    static let maxZoom: CGFloat = 5.0

    static func clamp(_ z: CGFloat) -> CGFloat {
        CGFloat(min(max(Double(z), Double(minZoom)), Double(maxZoom)))
    }
}

/// Chỉ vẽ RuleMark TB/TV khi giá trị nằm gần dải chuỗi — tránh kéo trục Y (P/E ~8 nhưng TV 40) và đường nằm ngoài vùng nhìn.
func valuationReferenceLineFitsSeries(value: Double?, seriesValues: [Double]) -> Bool {
    guard let v = value, v.isFinite else { return false }
    let finite = seriesValues.filter(\.isFinite)
    guard let dLo = finite.min(), let dHi = finite.max() else { return false }
    let span = max(dHi - dLo, 1e-9)
    let expand = max(span * 2.0, 3.0)
    return v >= dLo - expand && v <= dHi + expand
}

/// Domain trục Y dùng chung cho chart quý/năm và chart theo ngày.
/// Bám chuỗi giống ROE/ROA: chỉ mở rộng cho TB/TV/`current` khi chúng **gần** dải dữ liệu (tránh P/E hàng ngày ~8 bị nén vì số «hiện tại»/TV tính khác mẫu số).
/// `yAxisZoom`: >1 thu hẹp thang (phóng chi tiết), <1 mở rộng; có **clamp** để tránh trục Y phình vô hạn khi zoom ra.
func valuationChartYDomain(
    seriesValues: [Double],
    rangeMedian: Double?,
    rangeMean: Double?,
    current: Double,
    yAxisZoom: CGFloat
) -> ClosedRange<Double> {
    let finite = seriesValues.filter(\.isFinite)
    guard !finite.isEmpty else { return 0...1 }

    let dataLo = finite.min()!
    let dataHi = finite.max()!
    let seriesSpan = max(dataHi - dataLo, 1e-9)

    var lo = dataLo
    var hi = dataHi

    let refExpand = max(seriesSpan * 2.0, 3.0)
    func mergeIfNearSeries(_ v: Double?) {
        guard let v, v.isFinite else { return }
        guard v >= dataLo - refExpand && v <= dataHi + refExpand else { return }
        lo = min(lo, v)
        hi = max(hi, v)
    }
    mergeIfNearSeries(rangeMedian)
    mergeIfNearSeries(rangeMean)

    let currentExpand = max(seriesSpan * 2.8, 5.0)
    if current.isFinite,
        current >= dataLo - currentExpand,
        current <= dataHi + currentExpand {
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

    let span0 = hi - lo
    let mid = (lo + hi) / 2
    let z = max(Double(ValuationChartAxisZoom.clamp(yAxisZoom)), 0.05)
    var half = (span0 / 2) / z
    let minHalf = max((span0 / 2) / 25, 1e-9)
    let maxHalf = (span0 / 2) * 4
    half = min(max(half, minHalf), maxHalf)
    var nLo = mid - half
    var nHi = mid + half
    if !allowNegative {
        nLo = max(0, nLo)
        if nLo >= nHi {
            nHi = nLo + 1e-6
        }
    }
    guard nLo < nHi else { return lo...hi }
    return nLo...nHi
}

/// Chụm hai ngón: cùng hệ số cho **trục X** (cửa sổ thời gian) và **trục Y** (thang giá trị).
/// Gắn `simultaneousGesture` — theo quy ước HIG: một ngón cuộn, hai ngón chụm; không dùng `highPriorityGesture`
/// để tránh lệch hành vi so với scroll nội bộ của Charts.
@MainActor
func valuationPinchGesture(
    pinch: GestureState<CGFloat>,
    xAxisZoom: Binding<CGFloat>,
    yAxisZoom: Binding<CGFloat>,
    onXZoomCommitted: @escaping (_ previousX: CGFloat, _ newX: CGFloat) -> Void
) -> some Gesture {
    MagnifyGesture()
        .updating(pinch) { value, state, _ in
            state = value.magnification
        }
        .onEnded { value in
            let mag = value.magnification
            let prevX = xAxisZoom.wrappedValue
            let prevY = yAxisZoom.wrappedValue
            let nextX = ValuationChartAxisZoom.clamp(prevX * mag)
            let nextY = ValuationChartAxisZoom.clamp(prevY * mag)
            guard nextX != prevX || nextY != prevY else { return }
            xAxisZoom.wrappedValue = nextX
            yAxisZoom.wrappedValue = nextY
            if nextX != prevX {
                onXZoomCommitted(prevX, nextX)
            }
        }
}

extension View {
    /// Tắt animation ngầm khi đổi zoom / gesture (SwiftUI Charts hay implicit animate → giật).
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
