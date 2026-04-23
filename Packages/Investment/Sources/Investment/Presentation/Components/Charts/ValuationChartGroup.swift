import Charts
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

    @State private var vm = ValuationChartGroupViewModel()

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
        valuationPeriodBounds(points: displayValuations, showQuarterly: showQuarterly, calendar: vm.calendar)
    }

    private var filteredValuations: [ValuationDataPoint] {
        guard let bounds = dataBounds else { return [] }
        let startDay = vm.calendar.startOfDay(for: min(vm.rangeStart, vm.rangeEnd))
        let endBase = vm.calendar.startOfDay(for: max(vm.rangeStart, vm.rangeEnd))
        let endDay =
            vm.calendar.date(byAdding: DateComponents(day: 1, second: -1), to: endBase) ?? endBase
        let lo = min(startDay, endDay)
        let hi = max(startDay, endDay)
        let clampedLo = max(lo, bounds.min)
        let clampedHi = min(hi, bounds.max)
        guard clampedLo <= clampedHi else { return [] }
        return displayValuations.filter { p in
            let d = endOfReportingPeriod(for: p, showQuarterly: showQuarterly, calendar: vm.calendar)
            return d >= clampedLo && d <= clampedHi
        }
    }

    private var filteredDailyValuations: [DailyValuationDataPoint] {
        let startDay = vm.calendar.startOfDay(for: min(vm.rangeStart, vm.rangeEnd))
        let endBase = vm.calendar.startOfDay(for: max(vm.rangeStart, vm.rangeEnd))
        let lo = min(startDay, endBase)
        let hi = max(startDay, endBase)
        return dailyValuations.filter { p in
            guard let d = parseDailyChartDate(p.date) else { return false }
            let day = vm.calendar.startOfDay(for: d)
            return day >= lo && day <= hi
        }
    }

    private var rangeStats: ValuationRangeStats {
        valuationRangeStats(filteredValuations)
    }

    private var dailyRangeStats: ValuationRangeStats {
        valuationDailyRangeStats(filteredDailyValuations)
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
                ValuationLineChart(
                    title: "Định giá P/E",
                    current: overview.displayPE,
                    rangeMedian: rangeStats.peMedian,
                    rangeMean: rangeStats.peMean,
                    data: filteredValuations,
                    valueKeyPath: \.pe,
                    lineColor: .teal,
                    showQuarterly: showQuarterly,
                    onRequestFullHistory: onRequestFullHistory
                )

                ValuationLineChart(
                    title: "Định giá P/B",
                    current: overview.displayPB,
                    rangeMedian: rangeStats.pbMedian,
                    rangeMean: rangeStats.pbMean,
                    data: filteredValuations,
                    valueKeyPath: \.pb,
                    lineColor: AppColors.chartAssetShortTermInvestments,
                    showQuarterly: showQuarterly,
                    onRequestFullHistory: onRequestFullHistory
                )

                ValuationLineChart(
                    title: "Định giá P/S",
                    current: overview.displayPS,
                    rangeMedian: rangeStats.psMedian,
                    rangeMean: rangeStats.psMean,
                    data: filteredValuations,
                    valueKeyPath: \.ps,
                    lineColor: AppColors.chartAssetTrading,
                    showQuarterly: showQuarterly,
                    onRequestFullHistory: onRequestFullHistory
                )
            } else {
                ValuationLineChart(
                    title: "Định giá P/E",
                    current: overview.displayPE,
                    rangeMedian: dailyRangeStats.peMedian,
                    rangeMean: dailyRangeStats.peMean,
                    data: filteredDailyValuations,
                    metric: \.pe,
                    lineColor: .teal,
                    onRequestFullHistory: onRequestFullHistory,
                    headlineNote: nil,
                    emptyChartMessage: nil
                )

                ValuationLineChart(
                    title: "Định giá P/B",
                    current: overview.displayPB,
                    rangeMedian: dailyRangeStats.pbMedian,
                    rangeMean: dailyRangeStats.pbMean,
                    data: filteredDailyValuations,
                    metric: \.pb,
                    lineColor: AppColors.chartAssetShortTermInvestments,
                    onRequestFullHistory: onRequestFullHistory,
                    headlineNote: nil,
                    emptyChartMessage: nil
                )

                ValuationLineChart(
                    title: "Định giá P/S",
                    current: overview.displayPS,
                    rangeMedian: dailyRangeStats.psMedian,
                    rangeMean: dailyRangeStats.psMean,
                    data: filteredDailyValuations,
                    metric: \.ps,
                    lineColor: AppColors.chartAssetTrading,
                    onRequestFullHistory: onRequestFullHistory,
                    headlineNote: nil,
                    emptyChartMessage: nil
                )
            }
        }
        .onAppear {
            vm.resetRangeToDefaultIfNeeded(force: !vm.didInitializeRange)
            vm.ensureDefaultQuarterRangeLoadedIfNeeded(
                granularity: granularity, showQuarterly: showQuarterly,
                onRequestValuationsForRange: onRequestValuationsForRange,
                onRequestDailyValuations: onRequestDailyValuations
            )
        }
        .onChange(of: overview.symbol) { _, _ in
            vm.handleSymbolOrModeChange()
            vm.ensureDefaultQuarterRangeLoadedIfNeeded(
                granularity: granularity, showQuarterly: showQuarterly,
                onRequestValuationsForRange: onRequestValuationsForRange,
                onRequestDailyValuations: onRequestDailyValuations
            )
        }
        .onChange(of: showQuarterly) { _, _ in
            vm.handleSymbolOrModeChange()
            vm.ensureDefaultQuarterRangeLoadedIfNeeded(
                granularity: granularity, showQuarterly: showQuarterly,
                onRequestValuationsForRange: onRequestValuationsForRange,
                onRequestDailyValuations: onRequestDailyValuations
            )
        }
        .onChange(of: valuations.count) { _, _ in
            vm.ensureDefaultQuarterRangeLoadedIfNeeded(
                granularity: granularity, showQuarterly: showQuarterly,
                onRequestValuationsForRange: onRequestValuationsForRange,
                onRequestDailyValuations: onRequestDailyValuations
            )
        }
        .onChange(of: granularity) { _, _ in
            vm.onGranularityChanged(
                granularity: granularity, showQuarterly: showQuarterly,
                onRequestValuationsForRange: onRequestValuationsForRange,
                onRequestDailyValuations: onRequestDailyValuations
            )
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
                    selection: Binding(
                        get: { vm.rangeStart },
                        set: { vm.rangeStart = $0 }
                    )
                )
                quarterYearRangeColumn(
                    title: "Đến quý",
                    selection: Binding(
                        get: { vm.rangeEnd },
                        set: { vm.rangeEnd = $0 }
                    )
                )
            }
            .onChange(of: vm.rangeStart) { _, newStart in
                vm.clampRangeSelections(anchorStart: newStart)
                vm.scheduleRangeReloadIfNeeded(
                    granularity: granularity, showQuarterly: showQuarterly,
                    onRequestValuationsForRange: onRequestValuationsForRange,
                    onRequestDailyValuations: onRequestDailyValuations
                )
            }
            .onChange(of: vm.rangeEnd) { _, newEnd in
                vm.clampRangeSelections(anchorEnd: newEnd)
                vm.scheduleRangeReloadIfNeeded(
                    granularity: granularity, showQuarterly: showQuarterly,
                    onRequestValuationsForRange: onRequestValuationsForRange,
                    onRequestDailyValuations: onRequestDailyValuations
                )
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
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
                get: { vm.yearAndQuarter(for: selection.wrappedValue).year },
                set: { newYear in
                    let currentQuarter = vm.yearAndQuarter(for: selection.wrappedValue).quarter
                    if let d = vm.quarterEndDate(year: newYear, quarter: currentQuarter) {
                        selection.wrappedValue = d
                    }
                }
            )

            let quarterBinding = Binding<Int>(
                get: { vm.yearAndQuarter(for: selection.wrappedValue).quarter },
                set: { newQuarter in
                    let currentYear = vm.yearAndQuarter(for: selection.wrappedValue).year
                    if let d = vm.quarterEndDate(year: currentYear, quarter: newQuarter) {
                        selection.wrappedValue = d
                    }
                }
            )

            HStack(spacing: Spacing.xs) {
                VStack(alignment: .leading, spacing: .zero) {
                    Picker("", selection: quarterBinding) {
                        ForEach(vm.quarterOptions, id: \.self) { q in
                            Text("Q\(q)").tag(q)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: UILayout.wheelPickerNarrow, height: UILayout.wheelPickerHeight)
                    .clipped()
                }

                VStack(alignment: .leading, spacing: .zero) {
                    Picker("", selection: yearBinding) {
                        ForEach(vm.yearOptions, id: \.self) { y in
                            Text("\(y)").tag(y)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: UILayout.wheelPickerWide, height: UILayout.wheelPickerHeight)
                    .clipped()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// parseDailyChartDate is defined in ValuationChartHelpers.swift
