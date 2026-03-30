import Foundation
import FinFlowCore
import SwiftUI

// MARK: - Period dates & range stats

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

// MARK: - Pinch and axis zoom helpers

enum ValuationChartAxisZoom {
    static let minZoom: CGFloat = 0.5
    static let maxZoom: CGFloat = 5.0

    static func clamp(_ z: CGFloat) -> CGFloat {
        CGFloat(min(max(Double(z), Double(minZoom)), Double(maxZoom)))
    }
}

/// Domain trục Y dùng chung cho chart quý/năm và chart theo ngày.
func valuationChartYDomain(
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

    // Keep Y zoom anchored around the true data center.
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

/// Chụm: zoom cửa sổ thời gian (X) và thang giá trị (Y) cùng hệ số.
@MainActor
func valuationPinchGesture(
    pinch: GestureState<CGFloat>,
    xAxisZoom: Binding<CGFloat>,
    yAxisZoom: Binding<CGFloat>,
    onXZoomCommitted: @escaping () -> Void
) -> some Gesture {
    MagnifyGesture()
        .updating(pinch) { value, state, _ in
            state = value.magnification
        }
        .onEnded { value in
            xAxisZoom.wrappedValue = ValuationChartAxisZoom.clamp(
                xAxisZoom.wrappedValue * value.magnification
            )
            yAxisZoom.wrappedValue = ValuationChartAxisZoom.clamp(
                yAxisZoom.wrappedValue * value.magnification
            )
            onXZoomCommitted()
        }
}

extension View {
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
